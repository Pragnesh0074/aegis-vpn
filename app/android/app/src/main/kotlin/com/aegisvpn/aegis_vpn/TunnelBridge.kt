package com.aegisvpn.aegis_vpn

import android.app.Activity
import android.content.Intent
import android.provider.Settings
import android.os.Handler
import android.os.Looper
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
import java.util.concurrent.Executors

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

        /** Matches WireGuard's own rehandshake cadence closely enough to look live. */
        const val STATS_POLL_MS = 1_000L

        /**
         * How many times the kill switch rebuilds a tunnel that went down on its
         * own before giving up.
         *
         * Bounded on purpose. A tunnel that cannot come up — a revoked peer, a
         * withdrawn VPN consent, a node that is gone — would otherwise retry for
         * as long as the phone is on, and a VPN app that flattens the battery is
         * worse than one that admits defeat.
         */
        const val RECONNECT_ATTEMPTS = 5
        const val RECONNECT_BASE_DELAY_MS = 1_000L
    }

    private val methods = MethodChannel(messenger, METHOD_CHANNEL).apply {
        setMethodCallHandler(this@TunnelBridge)
    }
    private val events = EventChannel(messenger, EVENT_CHANNEL).apply {
        setStreamHandler(this@TunnelBridge)
    }

    private val backend: Backend by lazy {
        GoBackend(activity.applicationContext).also {
            // Fires when Android starts the service as an always-on VPN. Without
            // this the tunnel would never be established, and a user who had also
            // ticked "Block connections without VPN" would be left with no
            // network at all — the worst possible outcome of enabling a kill
            // switch. Only helps while this process holds a config; see
            // [lastConfig].
            GoBackend.setAlwaysOnCallback { main.post { maybeReconnect() } }
        }
    }
    private val main = Handler(Looper.getMainLooper())

    // setState blocks while the Go backend brings the interface up, so it must
    // never run on the platform thread.
    private val worker = Executors.newSingleThreadExecutor()

    private var sink: EventChannel.EventSink? = null
    private var deviceId: String? = null

    // Written from the worker thread (a failed setState) and from whichever
    // thread the backend reports a state change on, then read by the poll loop
    // on main. Without @Volatile the loop can read a stale DOWN and stop
    // polling a tunnel that is actually up.
    @Volatile
    private var state = Tunnel.State.DOWN

    /** Held while the system consent dialog is up, so the connect can resume after. */
    private var pendingConnect: (() -> Unit)? = null
    private var pendingResult: MethodChannel.Result? = null

    /**
     * Kill switch: rebuild the tunnel whenever it goes down without the user
     * asking.
     *
     * Lives here rather than in Dart because the cases worth surviving are the
     * ones where Dart is not running — the app backgrounded, the engine
     * suspended, the OS reclaiming the interface. A reconnect loop in the UI
     * layer would only work while someone was looking at it.
     *
     * Note what this is NOT: it cannot block traffic while the tunnel is down.
     * Only Android can do that, through "Block connections without VPN" in
     * system VPN settings, which no app is allowed to enable for itself. See
     * [openVpnSettings].
     */
    @Volatile
    private var killSwitch = false

    /**
     * The last config that was brought up, kept so the kill switch has something
     * to re-establish.
     *
     * Memory only. Persisting it would mean writing a WireGuard private key to a
     * second place on disk, and the keystore on the Dart side is deliberately the
     * only durable home for it. The cost is that a reconnect cannot survive the
     * process being killed.
     */
    private var lastConfig: Config? = null

    /** True while the current teardown was asked for, so it is not undone. */
    @Volatile
    private var userRequestedDown = false

    private var reconnectAttempt = 0

    private val tunnel = object : Tunnel {
        override fun getName() = "aegis"

        override fun onStateChange(newState: Tunnel.State) {
            // Fires for changes the app did not initiate, which is the whole reason
            // status is pushed rather than polled.
            state = newState
            main.post {
                pollStats()
                if (newState == Tunnel.State.UP) {
                    // A tunnel that came up is the only proof the retry budget
                    // should be refilled.
                    reconnectAttempt = 0
                } else if (newState == Tunnel.State.DOWN) {
                    maybeReconnect()
                }
            }
        }
    }

    private val reconnect = Runnable { attemptReconnect() }

    /**
     * Rebuilds a tunnel that dropped on its own, if the kill switch is on.
     *
     * Deliberately silent about the cases it cannot help with: a teardown the
     * user asked for, a config it never saw, and consent that has been withdrawn
     * — reconnecting the last of those needs an activity to show the system
     * dialog, which is not available from a background state change.
     */
    private fun maybeReconnect() {
        if (!killSwitch || userRequestedDown) return
        if (lastConfig == null) return
        if (reconnectAttempt >= RECONNECT_ATTEMPTS) return
        if (GoBackend.VpnService.prepare(activity) != null) {
            // Consent is gone. Retrying would fail identically every time, and
            // the UI already reports the tunnel as down.
            return
        }

        // Backs off 1s, 2s, 4s, 8s, 16s. A node that is briefly unreachable
        // recovers on the first try; one that is gone stops being hammered.
        val delay = RECONNECT_BASE_DELAY_MS shl reconnectAttempt
        reconnectAttempt++
        main.removeCallbacks(reconnect)
        main.postDelayed(reconnect, delay)
    }

    private fun attemptReconnect() {
        val config = lastConfig ?: return
        if (!killSwitch || userRequestedDown || state == Tunnel.State.UP) return

        worker.execute {
            try {
                backend.setState(tunnel, Tunnel.State.UP, config)
            } catch (e: Exception) {
                state = Tunnel.State.DOWN
                main.post {
                    pollStats()
                    // Schedule the next attempt from here: a throwing setState
                    // may never reach onStateChange, so the chain would stop.
                    maybeReconnect()
                }
            }
        }
    }

    private fun cancelReconnect() {
        main.removeCallbacks(reconnect)
        reconnectAttempt = 0
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
                killSwitch = call.argument<Boolean>("enabled") == true
                if (!killSwitch) cancelReconnect()
                emit()
                result.success(null)
            }
            // Android's real kill switch. An app cannot turn this on for itself,
            // by design, so the most it can do is take the user to the screen.
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
        userRequestedDown = false
        cancelReconnect()

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
        } else {
            state = Tunnel.State.TOGGLE
            emit()
            pendingConnect = start
            pendingResult = result
            activity.startActivityForResult(consent, VPN_PERMISSION_REQUEST)
        }
    }

    private fun disconnect(result: MethodChannel.Result) {
        // Set before the call, not after: onStateChange can land while setState
        // is still running, and the kill switch would otherwise race in and
        // rebuild the tunnel the user just asked to drop.
        userRequestedDown = true
        cancelReconnect()

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
        } else {
            state = Tunnel.State.DOWN
            pollStats()
            result?.error(
                "permission_denied",
                "Permission to create a VPN connection was declined.",
                null,
            )
        }
        return true
    }

    private fun buildConfig(call: MethodCall): Config {
        val iface = Interface.Builder()
            .parsePrivateKey(call.argument<String>("privateKey")!!)
            .parseAddresses(call.argument<String>("address")!!)
            .parseDnsServers(call.argument<String>("dns")!!)
            .setMtu(call.argument<Int>("mtu")!!)
            .build()

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
        worker.shutdown()
    }
}
