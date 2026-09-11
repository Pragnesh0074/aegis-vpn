package com.aegisvpn.aegis_vpn

import android.app.Activity
import android.content.Intent
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
    }

    private val methods = MethodChannel(messenger, METHOD_CHANNEL).apply {
        setMethodCallHandler(this@TunnelBridge)
    }
    private val events = EventChannel(messenger, EVENT_CHANNEL).apply {
        setStreamHandler(this@TunnelBridge)
    }

    private val backend: Backend by lazy { GoBackend(activity.applicationContext) }
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

    private val tunnel = object : Tunnel {
        override fun getName() = "aegis"

        override fun onStateChange(newState: Tunnel.State) {
            // Fires for changes the app did not initiate, which is the whole reason
            // status is pushed rather than polled.
            state = newState
            main.post { pollStats() }
        }
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
