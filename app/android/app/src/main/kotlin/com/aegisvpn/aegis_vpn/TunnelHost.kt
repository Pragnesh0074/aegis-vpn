package com.aegisvpn.aegis_vpn

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.wireguard.android.backend.Backend
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The tunnel, and everything about it that outlives an activity.
 *
 * [TunnelBridge] used to own all of this. That was fine while the Flutter
 * activity was the only thing that could touch a tunnel, and stopped being fine
 * the moment a Quick Settings tile could: a tile runs in this process but has no
 * activity, can be tapped with the app nowhere on screen, and must be able to
 * see whether the tunnel is up and take it down.
 *
 * It also fixes something that was already wrong. The interface outlives the
 * activity — `VpnService` keeps running when the app is backgrounded — so state
 * scoped to an activity was state that could disappear while the thing it
 * described was still carrying traffic.
 *
 * What is NOT here is policy: the kill switch, auto-connect, the consent dance
 * and the stats loop all stay in [TunnelBridge], because all of them need either
 * an activity or a Flutter channel to be worth anything.
 */
object TunnelHost {

    /**
     * How many times the kill switch rebuilds a tunnel that went down on its own
     * before giving up.
     *
     * Bounded on purpose. A tunnel that cannot come up — a revoked peer, a
     * withdrawn VPN consent, a node that is gone — would otherwise retry for as
     * long as the phone is on, and a VPN app that flattens the battery is worse
     * than one that admits defeat.
     */
    const val RECONNECT_ATTEMPTS = 5
    const val RECONNECT_BASE_DELAY_MS = 1_000L

    private val main = Handler(Looper.getMainLooper())

    /**
     * An application context, kept so the reconnect loop can check VPN consent
     * without an activity.
     *
     * Set the first time anything asks for a backend, which is before anything
     * could possibly need to reconnect.
     */
    @Volatile
    private var appContext: Context? = null

    /**
     * The backend that owns the tun device.
     *
     * Built from the application context, never an activity's. A `GoBackend`
     * holding an activity would keep the whole activity alive for as long as the
     * tunnel — and the tile has no activity to give it in the first place.
     */
    @Volatile
    private var backend: Backend? = null

    fun backend(context: Context): Backend {
        appContext = context.applicationContext
        return backend ?: synchronized(this) {
            backend ?: GoBackend(context.applicationContext).also {
                backend = it
                // Fires when Android starts the service as an always-on VPN.
                // Without answering it the tunnel would never be established, and
                // a user who had also ticked "Block connections without VPN"
                // would be left with no network at all — the worst possible
                // outcome of switching on a kill switch.
                GoBackend.setAlwaysOnCallback { main.post { maybeReconnect() } }
            }
        }
    }

    /**
     * Whether a backend exists yet.
     *
     * The tile uses this to avoid *creating* one just to answer "is the tunnel
     * up": a process that has never had a backend has never had a tunnel, and
     * building one to discover that would load the Go library for nothing.
     */
    val isStarted: Boolean get() = backend != null

    /**
     * Where `setState` runs.
     *
     * It blocks while the Go backend brings an interface up or down, so it must
     * never touch the platform thread. Shared rather than per-bridge because the
     * tile issues the same calls, and two executors could have a teardown and a
     * setup running against the same interface at once.
     */
    val worker: ExecutorService = Executors.newSingleThreadExecutor()

    @Volatile
    var state: Tunnel.State = Tunnel.State.DOWN

    /**
     * The last config brought up, kept so the kill switch and the tile have
     * something to re-establish.
     *
     * Memory only, and deliberately so: persisting it would mean writing a
     * WireGuard private key to a second place on disk, and the Dart keystore is
     * meant to be its only durable home. The cost is that nothing can reconnect
     * after the process dies — which is also when the tunnel itself dies, since
     * the VpnService runs in this process.
     */
    @Volatile
    var lastConfig: Config? = null

    /**
     * When something in this process last asked the app to connect on its behalf,
     * in epoch millis, or 0 for no outstanding request.
     *
     * Set by anything that wants a tunnel but cannot build one itself — the tile
     * on a cold start, auto-connect holding no config. It stays set until Dart
     * acknowledges it, which is what makes it survive a cold start: the request
     * is made long before a Flutter engine exists, and a signal Dart had to be
     * listening for at the right moment would simply be missed.
     */
    @Volatile
    var connectRequestedAt = 0L
        private set

    /**
     * Kill switch: rebuild the tunnel whenever it goes down without the user
     * asking.
     *
     * Here rather than in the bridge, and that placement is the whole point. The
     * drops worth surviving are the ones where nothing is watching — the app
     * backgrounded, the activity destroyed, the OS reclaiming the interface — and
     * a reconnect loop owned by an activity stops the moment that activity does,
     * which is precisely when it was needed.
     *
     * Note what this is NOT: it cannot block traffic while the tunnel is down.
     * Only Android can do that, through "Block connections without VPN" in system
     * VPN settings, which no app may enable for itself.
     */
    @Volatile
    var killSwitch = false
        private set

    /** True while the current teardown was asked for, so it is not undone. */
    @Volatile
    var userRequestedDown = false

    private var reconnectAttempt = 0

    private val reconnect = Runnable { attemptReconnect() }

    private val listeners = CopyOnWriteArrayList<(Tunnel.State) -> Unit>()

    /**
     * The one tunnel this app has.
     *
     * Its name is what WireGuard's backend keys the interface on, so it has to be
     * the same object for the life of the process — two `Tunnel` instances with
     * the same name would have the backend reporting state for one while the
     * other believed it owned the interface.
     */
    val tunnel = object : Tunnel {
        override fun getName() = "aegis"

        override fun onStateChange(newState: Tunnel.State) {
            state = newState

            main.post {
                // The retry budget is refilled only by a tunnel that actually came
                // up; anything else would let a failing config retry forever.
                if (newState == Tunnel.State.UP) reconnectAttempt = 0
                if (newState == Tunnel.State.DOWN) maybeReconnect()
            }

            // Copy-on-write, so a listener removing itself mid-notify — which the
            // bridge does on dispose — cannot break the iteration.
            for (listener in listeners) listener(newState)
        }
    }

    fun addListener(listener: (Tunnel.State) -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: (Tunnel.State) -> Unit) {
        listeners.remove(listener)
    }

    /** Arms or disarms the kill switch, cancelling any retry in flight. */
    fun setKillSwitch(enabled: Boolean) {
        killSwitch = enabled
        if (!enabled) cancelReconnect()
    }

    /** Forgets any pending retry — a new connect or a deliberate teardown. */
    fun cancelReconnect() {
        main.removeCallbacks(reconnect)
        reconnectAttempt = 0
    }

    /**
     * Rebuilds a tunnel that dropped on its own, if the kill switch is on.
     *
     * Deliberately silent about the cases it cannot help with: a teardown the
     * user asked for, a config it never saw, and consent that has been withdrawn
     * — reconnecting the last of those needs an activity to show the system
     * dialog, which is not available from a background state change.
     */
    fun maybeReconnect() {
        val context = appContext ?: return
        if (!killSwitch || userRequestedDown) return
        if (lastConfig == null) return
        if (reconnectAttempt >= RECONNECT_ATTEMPTS) return
        if (!hasConsent(context)) {
            // Retrying would fail identically every time, and the UI already
            // reports the tunnel as down.
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
        val context = appContext ?: return
        val config = lastConfig ?: return
        if (!killSwitch || userRequestedDown || state == Tunnel.State.UP) return

        worker.execute {
            try {
                backend(context).setState(tunnel, Tunnel.State.UP, config)
            } catch (e: Exception) {
                state = Tunnel.State.DOWN
                // Scheduled from here as well: a throwing setState may never
                // reach onStateChange, so the chain would otherwise stop.
                main.post {
                    for (listener in listeners) listener(Tunnel.State.DOWN)
                    maybeReconnect()
                }
            }
        }
    }

    /** True when Android has already granted this app permission to build a VPN. */
    fun hasConsent(context: Context): Boolean {
        return GoBackend.VpnService.prepare(context.applicationContext) == null
    }

    /**
     * Records that something wants a tunnel it cannot build itself, and tells the
     * listeners so the bridge can publish it to Dart.
     *
     * The timestamp is the whole payload. Whatever asked has, by definition, no
     * way to act on the answer, so there is nothing else worth carrying.
     */
    fun requestConnect() {
        connectRequestedAt = System.currentTimeMillis()
        for (listener in listeners) listener(state)
    }

    /**
     * Clears an outstanding request, once Dart has acted on it.
     *
     * Cleared on the attempt, not on success. A request that keeps failing would
     * otherwise be retried for as long as the app was open; whatever made it —
     * a tile tap, a network arrival — will happen again if it still matters.
     */
    fun clearConnectRequest() {
        connectRequestedAt = 0L
    }
}
