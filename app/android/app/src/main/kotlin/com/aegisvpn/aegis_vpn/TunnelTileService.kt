package com.aegisvpn.aegis_vpn

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.wireguard.android.backend.Tunnel

/**
 * The tunnel, from the pull-down shade.
 *
 * A Quick Settings tile is the shortest path there is between wanting a VPN and
 * having one: two swipes, no app launch. It runs in this process but has no
 * activity and no Flutter engine, which is what [TunnelHost] exists for.
 *
 * What it can do alone, and what it cannot, falls out of that:
 *
 * - **Turning the tunnel off** always works. It needs nothing but the backend.
 * - **Turning it on** works when this process still holds the config it last
 *   brought up and Android has already granted VPN consent — the ordinary case
 *   for a phone that has been used today.
 * - **Otherwise it opens the app**, because building a tunnel from nothing means
 *   reading a private key out of the keystore and possibly registering a peer
 *   with the API, and neither is reachable from here. The app is launched with a
 *   request already recorded, so it connects on arrival rather than sitting on
 *   the connect screen waiting to be tapped again.
 */
class TunnelTileService : TileService() {

    private val main = Handler(Looper.getMainLooper())

    /** True between a tap and the backend answering, so the tile can say so. */
    @Volatile
    private var busy = false

    private val listener: (Tunnel.State) -> Unit = { main.post { render() } }

    override fun onStartListening() {
        super.onStartListening()
        // Subscribed only while the shade is open. A tile that is not being
        // looked at does not need to be redrawn, and a listener left registered
        // would outlive every panel the user ever opened.
        TunnelHost.addListener(listener)
        render()
    }

    override fun onStopListening() {
        TunnelHost.removeListener(listener)
        super.onStopListening()
    }

    override fun onClick() {
        if (busy) return

        if (TunnelHost.state == Tunnel.State.UP) {
            toggle(up = false)
            return
        }

        val config = TunnelHost.lastConfig
        if (config != null && TunnelHost.hasConsent(this)) {
            toggle(up = true)
            return
        }

        openApp()
    }

    private fun toggle(up: Boolean) {
        busy = true
        render()

        val config = if (up) TunnelHost.lastConfig else null
        if (up && config == null) {
            busy = false
            openApp()
            return
        }

        // Both directions are a deliberate choice by a person, so the kill
        // switch must not treat a teardown from the shade as a drop to undo —
        // and must not stay stood down after a connect from the shade either.
        TunnelHost.userRequestedDown = !up
        TunnelHost.cancelReconnect()

        TunnelHost.worker.execute {
            try {
                TunnelHost.backend(this).setState(
                    TunnelHost.tunnel,
                    if (up) Tunnel.State.UP else Tunnel.State.DOWN,
                    config,
                )
            } catch (e: Exception) {
                // The interface refused to come up — a revoked peer, a node that
                // is gone, consent withdrawn between the check and the call. The
                // app can explain it; a tile cannot.
                TunnelHost.state = Tunnel.State.DOWN
                if (up) main.post { openApp() }
            } finally {
                busy = false
                main.post { render() }
            }
        }
    }

    /**
     * Opens the app with a connect already queued.
     *
     * [TunnelHost.requestConnect] before launching rather than after: the request
     * survives until Dart acknowledges it, so it does not matter that no Flutter
     * engine exists yet to hear it.
     */
    private fun openApp() {
        TunnelHost.requestConnect()

        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        val launch = {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // From Android 14 the Intent overload throws. A tile may only
                // send the user somewhere through a PendingIntent.
                startActivityAndCollapse(
                    PendingIntent.getActivity(
                        this,
                        0,
                        intent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    ),
                )
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
        }

        // Launching over the lock screen shows nothing and loses the tap.
        if (isLocked) unlockAndRun(launch) else launch()
    }

    private fun render() {
        val tile = qsTile ?: return

        val state = TunnelHost.state
        val up = state == Tunnel.State.UP

        tile.state = if (up) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = getString(R.string.tile_label)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = when {
                busy || state == Tunnel.State.TOGGLE -> getString(R.string.tile_working)
                up -> getString(R.string.tile_on)
                else -> getString(R.string.tile_off)
            }
        }

        tile.updateTile()
    }
}
