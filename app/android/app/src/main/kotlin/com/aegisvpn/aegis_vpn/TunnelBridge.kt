package com.aegisvpn.aegis_vpn

import android.Manifest
import android.app.Activity
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.provider.Settings
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.wireguard.android.backend.Backend
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import com.wireguard.config.Interface
import com.wireguard.config.Peer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Android half of the VPN platform channel.
 *
 * Delegates the protocol to WireGuard's own [GoBackend], which owns the
 * VpnService and the tun file descriptor. This class only translates between
 * Dart's method calls and that backend, and publishes state changes the app did
 * not ask for — the OS revoking the interface, or another VPN taking over.
 */
class TunnelBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private companion object {
        const val METHOD_CHANNEL = "vpn.aegis/tunnel"
        const val EVENT_CHANNEL = "vpn.aegis/tunnel/status"
        const val VPN_PERMISSION_REQUEST = 0x9E70
        const val WIFI_PERMISSION_REQUEST = 0x9E71

        /**
         * What Android returns for an SSID it will not tell us, which is every
         * Wi-Fi network unless this app holds a location permission.
         */
        const val UNKNOWN_SSID = "<unknown ssid>"

        /** Matches WireGuard's own rehandshake cadence closely enough to look live. */
        const val STATS_POLL_MS = 1_000L

        /**
         * Below this, a cancelled consent result cannot have been a human
         * decision — nobody reads a dialog and dismisses it in a quarter of a
         * second. Android returns `RESULT_CANCELED` with no dialog at all when
         * it refuses the request outright, which is indistinguishable from a
         * decline except by how fast it comes back.
         */
        const val CONSENT_MIN_VISIBLE_MS = 400L
    }

    private val methods = MethodChannel(messenger, METHOD_CHANNEL).apply {
        setMethodCallHandler(this@TunnelBridge)
    }
    private val events = EventChannel(messenger, EVENT_CHANNEL).apply {
        setStreamHandler(this@TunnelBridge)
    }

    // The tunnel itself lives in [TunnelHost], which outlives this activity —
    // and outlives this class, since the Quick Settings tile drives the same
    // interface with no activity at all. These accessors keep the call sites
    // below reading as if the state were local, which it no longer is.
    private val backend: Backend get() = TunnelHost.backend(activity)
    private val tunnel: Tunnel get() = TunnelHost.tunnel
    private val worker get() = TunnelHost.worker

    private val main = Handler(Looper.getMainLooper())

    private var sink: EventChannel.EventSink? = null
    private var deviceId: String? = null

    // Written from the worker thread (a failed setState) and from whichever
    // thread the backend reports a state change on, then read by the poll loop
    // on main. Volatile in the host, so the loop cannot read a stale DOWN and
    // stop polling a tunnel that is actually up.
    private var state: Tunnel.State
        get() = TunnelHost.state
        set(value) { TunnelHost.state = value }

    /** Held while the system consent dialog is up, so the connect can resume after. */
    private var pendingConnect: (() -> Unit)? = null
    private var pendingResult: MethodChannel.Result? = null

    /**
     * When the consent activity was launched, on the monotonic clock.
     *
     * Read once in [onActivityResult] to tell a refusal that never rendered from
     * one a person actually made. `elapsedRealtime` rather than wall time so a
     * clock correction mid-dialog cannot make a real decision look instant.
     */
    private var consentStartedAt = 0L

    /** Armed state, owned by [TunnelHost] so it outlives this activity. */
    private val killSwitch: Boolean get() = TunnelHost.killSwitch

    /** The last config brought up. Held by [TunnelHost]; see the note there. */
    private var lastConfig: Config?
        get() = TunnelHost.lastConfig
        set(value) { TunnelHost.lastConfig = value }

    /**
     * Auto-connect: bring the tunnel up on joining a Wi-Fi network the user has
     * not marked trusted.
     *
     * Registered here rather than in Dart because the network change worth
     * reacting to usually arrives while the UI is not on screen. What it cannot
     * do is survive the process being killed — Android will not let an app start
     * a VPN from a cold start, and this class holds no callback that would wake
     * it. The screen says so; Android's own always-on VPN is the only thing that
     * covers that case.
     */
    @Volatile
    private var autoConnect = false

    /** Lower-cased, because an SSID differing only in case is the same network. */
    private var trustedSsids: Set<String> = emptySet()

    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    /**
     * The network auto-connect last acted on.
     *
     * Auto-connect fires on *arriving* at an untrusted network, not on the tunnel
     * being down. Without this the user could never disconnect while sitting on
     * one — every teardown would be undone by the next capability change on the
     * same Wi-Fi, which is a fight the app would always win and the user would
     * always lose.
     */
    private var lastAutoNetwork: Network? = null

    /** Held while the location permission dialog is up. */
    private var pendingPermissionResult: MethodChannel.Result? = null

    /**
     * Republishes whatever the tunnel is doing.
     *
     * Presentation only now. Rebuilding a dropped tunnel is [TunnelHost]'s job,
     * because it has to keep happening when this class is gone — an activity can
     * be destroyed while the interface it created is still carrying traffic, and
     * a kill switch that stopped at that moment would be a kill switch that
     * stopped exactly when it mattered.
     *
     * Also fires when something asks for a connect it cannot perform itself, so
     * the request reaches Dart in the next snapshot.
     */
    private val stateListener: (Tunnel.State) -> Unit = { main.post { pollStats() } }

    init {
        TunnelHost.addListener(stateListener)
        // Builds the backend if this is the first thing to need one, which is
        // also what gives the host a context for its reconnect loop.
        TunnelHost.backend(activity)
    }

    private val statsPoll = Runnable { pollStats() }

    /**
     * Emits a snapshot and, while the interface is up, schedules the next one.
     *
     * Idempotent — it clears any pending run first — so calling it on every
     * state change cannot leave two loops racing each other.
     *
     * It has to be re-entered on each state change rather than started once on
     * subscribe. The app subscribes at launch, when the tunnel is down, so a
     * loop that only began in [onListen] emitted once, declined to reschedule,
     * and died. The tunnel would then come up and report a single snapshot taken
     * before the first handshake had completed, leaving the UI on "up but the
     * peer has not replied" for the whole session with its transfer counters
     * frozen at zero.
     */
    private fun pollStats() {
        main.removeCallbacks(statsPoll)
        if (sink == null) return
        emit()
        if (state == Tunnel.State.UP) main.postDelayed(statsPoll, STATS_POLL_MS)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(snapshot())
            "connect" -> connect(call, result)
            "disconnect" -> disconnect(result)
            "setKillSwitch" -> {
                TunnelHost.setKillSwitch(call.argument<Boolean>("enabled") == true)
                emit()
                result.success(null)
            }
            // Android's real kill switch. An app cannot turn this on for itself,
            // by design, so the most it can do is take the user to the screen.
            // Split tunnelling: the apps a person can choose to keep off the
            // tunnel. Launcher-visible apps only — see [listApps].
            "listApps" -> result.success(listApps())
            "setAutoConnect" -> {
                setAutoConnect(
                    enabled = call.argument<Boolean>("enabled") == true,
                    trusted = call.argument<List<String>>("trusted").orEmpty(),
                )
                emit()
                result.success(null)
            }
            "currentWifi" -> result.success(currentWifi())
            // Dart has acted on the platform's connect request — a tile tap on a
            // cold start, or auto-connect with no config to re-establish — so the
            // request is spent.
            "ackConnectRequest" -> {
                TunnelHost.clearConnectRequest()
                emit()
                result.success(null)
            }
            "requestAddTile" -> requestAddTile(result)
            "requestWifiPermission" -> requestWifiPermission(result)
            "openVpnSettings" -> {
                try {
                    activity.startActivity(
                        Intent(Settings.ACTION_VPN_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(true)
                } catch (e: Exception) {
                    // Some OEM builds ship no VPN settings activity at all.
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        val config = try {
            buildConfig(call)
        } catch (e: Exception) {
            result.error("invalid_config", e.message ?: "The peer config is not valid.", null)
            return
        }
        deviceId = call.argument<String>("deviceId")
        lastConfig = config
        TunnelHost.userRequestedDown = false
        TunnelHost.cancelReconnect()

        val start = {
            worker.execute {
                try {
                    backend.setState(tunnel, Tunnel.State.UP, config)
                    main.post { result.success(null) }
                } catch (e: Exception) {
                    state = Tunnel.State.DOWN
                    main.post {
                        pollStats()
                        result.error("connect_failed", e.message ?: "The tunnel failed to start.", null)
                    }
                }
            }
        }

        // Returns an Intent the first time, or after the user revokes VPN access
        // for this app in system settings.
        val consent = GoBackend.VpnService.prepare(activity)
        if (consent == null) {
            start()
            return
        }

        // Consent needs a visible activity to render into. Asking from a
        // finished one, or from the background, is refused by the OS without
        // anything being drawn — which would surface as a decline the user never
        // made.
        if (activity.isFinishing || activity.isDestroyed) {
            result.error(
                "permission_unavailable",
                "The app has to be open to ask Android for VPN permission. " +
                    "Reopen it and try again.",
                null,
            )
            return
        }

        // A second consent request while one is in flight would overwrite
        // pendingResult, leaving the first call's Dart future to hang forever.
        if (pendingResult != null) {
            result.error(
                "permission_pending",
                "Android is already asking for VPN permission.",
                null,
            )
            return
        }

        // Another app's tunnel — usually one set as the always-on VPN — makes the
        // system cancel our request without drawing anything. Naming that is the
        // difference between an actionable message and "you declined", which the
        // user did not do.
        if (isForeignVpnActive()) {
            result.error(
                "permission_unavailable",
                "Another VPN app is active on this device. Disconnect it, turn " +
                    "off any always-on VPN under Settings, then try again.",
                null,
            )
            return
        }

        state = Tunnel.State.TOGGLE
        emit()
        pendingConnect = start
        pendingResult = result
        consentStartedAt = SystemClock.elapsedRealtime()

        try {
            activity.startActivityForResult(consent, VPN_PERMISSION_REQUEST)
        } catch (e: Exception) {
            // Some OEM builds ship no resolvable consent activity. Nothing will
            // call back, so the pending connect has to be unwound here.
            pendingConnect = null
            pendingResult = null
            state = Tunnel.State.DOWN
            pollStats()
            result.error(
                "permission_unavailable",
                "This device would not show the VPN permission dialog. " +
                    "Grant VPN access to this app under Settings, then try again.",
                null,
            )
        }
    }

    /**
     * True when a VPN that is not ours is carrying traffic right now.
     *
     * There is no API to ask which app holds the always-on slot, so this asks the
     * narrower question that has the same practical answer: is a VPN transport up
     * while our own interface is down.
     */
    private fun isForeignVpnActive(): Boolean {
        if (state == Tunnel.State.UP) return false
        return try {
            val cm = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            cm.allNetworks.any { network ->
                cm.getNetworkCapabilities(network)
                    ?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
            }
        } catch (e: Exception) {
            // Purely advisory — a failure here must not block a connect that
            // would otherwise have worked.
            false
        }
    }

    private fun disconnect(result: MethodChannel.Result) {
        // Set before the call, not after: onStateChange can land while setState
        // is still running, and the kill switch would otherwise race in and
        // rebuild the tunnel the user just asked to drop.
        TunnelHost.userRequestedDown = true
        TunnelHost.cancelReconnect()

        worker.execute {
            try {
                backend.setState(tunnel, Tunnel.State.DOWN, null)
                main.post { result.success(null) }
            } catch (e: Exception) {
                main.post {
                    result.error("disconnect_failed", e.message ?: "The tunnel failed to stop.", null)
                }
            }
        }
    }

    /** Forwarded from the activity; returns true when it consumed the result. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != VPN_PERMISSION_REQUEST) return false

        val resume = pendingConnect
        val result = pendingResult
        pendingConnect = null
        pendingResult = null

        if (resultCode == Activity.RESULT_OK && resume != null) {
            resume()
            return true
        }

        state = Tunnel.State.DOWN
        pollStats()

        // A cancel that comes back faster than anyone could read the dialog means
        // the dialog was never drawn: the OS refused the request. Telling that
        // person to "tap connect again and allow it" sends them to look for a
        // prompt that will not appear.
        val visibleFor = SystemClock.elapsedRealtime() - consentStartedAt
        if (visibleFor < CONSENT_MIN_VISIBLE_MS) {
            result?.error(
                "permission_unavailable",
                "Android did not show the VPN permission dialog. Another VPN may " +
                    "be active, or VPN access for this app may be blocked in " +
                    "Settings.",
                null,
            )
        } else {
            result?.error(
                "permission_denied",
                "Permission to create a VPN connection was declined.",
                null,
            )
        }
        return true
    }

    /**
     * Every app a person would recognise, for the split-tunnel picker.
     *
     * Launcher-visible apps only, resolved through a `<queries>` intent filter in
     * the manifest rather than `QUERY_ALL_PACKAGES`. That permission needs a Play
     * Store declaration and is more than this needs: an app with no launcher icon
     * is not one anybody is going to hunt down in a list. The cost is that a
     * headless app cannot be excluded, which is the right side to err on — the
     * list stays the set of things the user actually recognises.
     */
    private fun listApps(): List<Map<String, Any?>> {
        val pm = activity.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)

        return try {
            pm.queryIntentActivities(intent, 0)
                .asSequence()
                .map { it.activityInfo.applicationInfo }
                // An app with several launcher activities resolves more than once.
                .distinctBy { it.packageName }
                // Excluding ourselves would be meaningless: this app's own traffic
                // is the control plane, and it has to reach the API either way.
                .filter { it.packageName != activity.packageName }
                .map { info ->
                    mapOf(
                        "package" to info.packageName,
                        "label" to pm.getApplicationLabel(info).toString(),
                        "system" to ((info.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                    )
                }
                .sortedBy { (it["label"] as String).lowercase() }
                .toList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * Drops excluded packages that are no longer installed.
     *
     * `VpnService.Builder.addDisallowedApplication` throws when handed a package
     * that is not there, and the throw comes out of `setState` as a failed
     * connect. Without this filter, excluding an app and later uninstalling it
     * would leave the user unable to connect at all, with an error naming a
     * package they had forgotten about.
     */
    private fun installedOnly(packages: List<String>): List<String> {
        if (packages.isEmpty()) return emptyList()
        val pm = activity.packageManager
        return packages.filter { name ->
            try {
                pm.getApplicationInfo(name, 0)
                true
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }
        }
    }

    /**
     * Arms or disarms auto-connect, and replaces the trusted list.
     *
     * The trusted list is updated even when the enabled flag has not changed, so
     * trusting the network you are on takes effect without a round trip through
     * disabling the feature.
     */
    private fun setAutoConnect(enabled: Boolean, trusted: List<String>) {
        trustedSsids = trusted.map { it.trim().lowercase() }.filter { it.isNotEmpty() }.toSet()
        if (enabled == autoConnect) return

        autoConnect = enabled
        if (enabled) registerNetworkCallback() else unregisterNetworkCallback()
    }

    private fun registerNetworkCallback() {
        if (networkCallback != null) return

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                main.post { onWifiAvailable(network) }
            }

            override fun onLost(network: Network) {
                // Forgetting the network here is what lets rejoining it later
                // count as a fresh arrival.
                main.post { if (network == lastAutoNetwork) lastAutoNetwork = null }
            }
        }

        try {
            connectivity().registerNetworkCallback(
                NetworkRequest.Builder()
                    // Wi-Fi only. A VPN transport would match a request with no
                    // filter, so our own tunnel coming up would look like a new
                    // network to auto-connect to.
                    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .build(),
                callback,
            )
            networkCallback = callback
        } catch (e: Exception) {
            // Registration is capped per app. Failing here leaves the feature
            // off rather than taking the bridge down with it.
            networkCallback = null
        }
    }

    private fun unregisterNetworkCallback() {
        val callback = networkCallback ?: return
        networkCallback = null
        lastAutoNetwork = null
        try {
            connectivity().unregisterNetworkCallback(callback)
        } catch (e: Exception) {
            // Already gone; nothing to undo.
        }
    }

    /**
     * Decides whether joining [network] should bring the tunnel up.
     *
     * A network whose SSID cannot be read counts as untrusted. That is the safe
     * direction for a protection feature — connecting on a network the user
     * trusts is a wasted tunnel, while not connecting on one they do not is the
     * exposure this exists to prevent — and it is what happens whenever the
     * location permission is missing, which Android requires before it will name
     * a Wi-Fi network at all.
     */
    private fun onWifiAvailable(network: Network) {
        if (!autoConnect) return
        if (network == lastAutoNetwork) return
        lastAutoNetwork = network

        val ssid = ssidOf(network)
        if (ssid != null && trustedSsids.contains(ssid.lowercase())) return
        if (state == Tunnel.State.UP) return

        // Arriving somewhere new is a fresh intent to be protected, so an earlier
        // manual teardown no longer stands in the way.
        TunnelHost.userRequestedDown = false
        TunnelHost.cancelReconnect()

        val config = lastConfig
        if (config == null) {
            requestAutoConnectFromDart()
            return
        }

        worker.execute {
            try {
                backend.setState(tunnel, Tunnel.State.UP, config)
            } catch (e: Exception) {
                state = Tunnel.State.DOWN
                // Consent may have lapsed, which needs an activity this class
                // cannot summon. Dart can at least surface it.
                main.post {
                    pollStats()
                    requestAutoConnectFromDart()
                }
            }
        }
    }

    /**
     * Asks Dart to connect, for the cases the platform cannot.
     *
     * Published in the status snapshot rather than as its own event: the status
     * stream is already the one channel the app is guaranteed to be listening to.
     */
    private fun requestAutoConnectFromDart() = TunnelHost.requestConnect()

    /** The current Wi-Fi network's name, for the "trust this network" button. */
    private fun currentWifi(): Map<String, Any?> {
        val network = try {
            connectivity().activeNetwork
        } catch (e: Exception) {
            null
        }
        return mapOf(
            "ssid" to (network?.let { ssidOf(it) }),
            "hasPermission" to hasWifiPermission(),
        )
    }

    /**
     * The SSID of [network], or null when Android will not say.
     *
     * Two paths, because the API moved: from Android 10 the name rides on the
     * network's own capabilities, and before that it came from whatever Wi-Fi the
     * device happened to be on. Both are gated on a location permission — the
     * name of a nearby network is treated as location data, which is exactly what
     * it is.
     */
    private fun ssidOf(network: Network): String? {
        if (!hasWifiPermission()) return null

        return try {
            val cm = connectivity()
            val capabilities = cm.getNetworkCapabilities(network) ?: return null
            if (!capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return null

            val raw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                (capabilities.transportInfo as? WifiInfo)?.ssid
            } else {
                @Suppress("DEPRECATION")
                (activity.applicationContext.getSystemService(Context.WIFI_SERVICE)
                    as? WifiManager)?.connectionInfo?.ssid
            }
            normaliseSsid(raw)
        } catch (e: Exception) {
            null
        }
    }

    /** Android returns the SSID quoted, and a placeholder when it is withholding it. */
    private fun normaliseSsid(raw: String?): String? {
        val value = raw?.trim()?.removeSurrounding("\"") ?: return null
        if (value.isEmpty() || value == UNKNOWN_SSID) return null
        return value
    }

    private fun hasWifiPermission(): Boolean {
        return activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    }

    /**
     * Asks for the location permission Android requires before naming a network.
     *
     * Worth being blunt about in the UI above this: a VPN asking for location
     * looks alarming, and the reason is entirely Android's — an SSID is treated
     * as location data because knowing which Wi-Fi you can see places you.
     */
    private fun requestWifiPermission(result: MethodChannel.Result) {
        if (hasWifiPermission()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_pending", "A permission request is already open.", null)
            return
        }
        if (activity.isFinishing || activity.isDestroyed) {
            result.error(
                "permission_unavailable",
                "The app has to be open to ask for this permission.",
                null,
            )
            return
        }

        pendingPermissionResult = result
        try {
            activity.requestPermissions(
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                WIFI_PERMISSION_REQUEST,
            )
        } catch (e: Exception) {
            pendingPermissionResult = null
            result.error("permission_unavailable", "This device refused the request.", null)
        }
    }

    /** Forwarded from the activity; returns true when it consumed the result. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != WIFI_PERMISSION_REQUEST) return false

        val result = pendingPermissionResult
        pendingPermissionResult = null
        // Re-read rather than trusting the grant array, which is empty when the
        // request is cancelled by the system rather than answered.
        result?.success(hasWifiPermission())
        emit()
        return true
    }

    /**
     * Asks Android to offer the user the Quick Settings tile.
     *
     * Without this a tile exists but is invisible until someone thinks to edit
     * their shade, which nobody does. The system draws its own prompt — an app
     * cannot add a tile for itself — and the user can decline.
     *
     * Android 13 and up only. Below that the answer is an honest "no", and the
     * screen says where to add it by hand.
     */
    private fun requestAddTile(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(false)
            return
        }

        // The callback is the system's to invoke, so this guards against a reply
        // arriving twice; a MethodChannel result may only be used once.
        val answered = AtomicBoolean(false)
        fun answer(added: Boolean) {
            if (answered.compareAndSet(false, true)) main.post { result.success(added) }
        }

        try {
            activity.getSystemService(StatusBarManager::class.java).requestAddTileService(
                ComponentName(activity, TunnelTileService::class.java),
                activity.getString(R.string.tile_label),
                Icon.createWithResource(activity, R.drawable.ic_tile_shield),
                { command -> command.run() },
                { code ->
                    answer(
                        code == StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED ||
                            code == StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED,
                    )
                },
            )
        } catch (e: Exception) {
            answer(false)
        }
    }

    private fun connectivity(): ConnectivityManager {
        return activity.applicationContext
            .getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    private fun buildConfig(call: MethodCall): Config {
        val builder = Interface.Builder()
            .parsePrivateKey(call.argument<String>("privateKey")!!)
            .parseAddresses(call.argument<String>("address")!!)
            .parseDnsServers(call.argument<String>("dns")!!)
            .setMtu(call.argument<Int>("mtu")!!)

        // Split tunnelling. These packages are handed to
        // `VpnService.Builder.addDisallowedApplication`, so their traffic never
        // enters the tun interface at all — it is not routed around the tunnel
        // by a rule that could be got wrong, it simply never arrives.
        //
        // Excluded rather than included: an allow-list would silently drop every
        // app installed after it was written off the tunnel, which is the failure
        // a VPN must not have. Excluding names only what the user chose.
        val excluded = installedOnly(call.argument<List<String>>("excludedApps").orEmpty())
        if (excluded.isNotEmpty()) builder.excludeApplications(excluded)

        val iface = builder.build()

        val peer = Peer.Builder()
            .parsePublicKey(call.argument<String>("peerPublicKey")!!)
            .parseEndpoint(call.argument<String>("endpoint")!!)
            .parseAllowedIPs(call.argument<String>("allowedIps")!!)
            .setPersistentKeepalive(call.argument<Int>("persistentKeepalive")!!)
            .build()

        return Config.Builder().setInterface(iface).addPeer(peer).build()
    }

    private fun snapshot(): Map<String, Any?> {
        var rx = 0L
        var tx = 0L
        var handshake = 0L

        if (state == Tunnel.State.UP) {
            try {
                val stats = backend.getStatistics(tunnel)
                rx = stats.totalRx()
                tx = stats.totalTx()
                // Newest handshake across peers; there is only ever one here.
                handshake = stats.peers()
                    .mapNotNull { stats.peer(it)?.latestHandshakeEpochMillis }
                    .maxOrNull() ?: 0L
            } catch (_: Exception) {
                // Statistics are best-effort: a tunnel torn down mid-read must not
                // take the status stream with it.
            }
        }

        return mapOf(
            "state" to when (state) {
                Tunnel.State.UP -> "connected"
                Tunnel.State.TOGGLE -> "connecting"
                Tunnel.State.DOWN -> "disconnected"
            },
            "deviceId" to deviceId,
            "rxBytes" to rx,
            "txBytes" to tx,
            "lastHandshakeEpochSeconds" to handshake / 1000,
            "killSwitch" to killSwitch,
            "autoConnect" to autoConnect,
            "connectRequestedAt" to TunnelHost.connectRequestedAt,
            "wifiPermission" to hasWifiPermission(),
        )
    }

    private fun emit() {
        sink?.success(snapshot())
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        this.sink = sink
        // Seeds the stream so a fresh listener does not have to call status()
        // first, and starts the poll loop if the tunnel is already up — which it
        // can be, since the interface outlives the app.
        pollStats()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        main.removeCallbacks(statsPoll)
    }

    fun dispose() {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        main.removeCallbacks(statsPoll)
        TunnelHost.removeListener(stateListener)
        // The callback outlives this activity otherwise, and a leaked one keeps
        // firing against a dead bridge until the process goes.
        unregisterNetworkCallback()
        // The worker is NOT shut down: it belongs to the process, and the tile
        // still needs it to take a tunnel down after this activity is gone.
    }
}
