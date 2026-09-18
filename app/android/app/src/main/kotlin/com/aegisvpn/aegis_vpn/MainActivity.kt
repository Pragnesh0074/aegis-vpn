package com.aegisvpn.aegis_vpn

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var tunnel: TunnelBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tunnel = TunnelBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        // A cold start from the notification arrives here, before Dart is
        // listening — the bridge holds it until it is.
        consumeTrustIntent(intent)
    }

    // A warm start: the app was already running and the notification brought it
    // forward, so `configureFlutterEngine` will not run again.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeTrustIntent(intent)
    }

    /**
     * Picks up "Trust this network" from the notification.
     *
     * The notification cannot write the trusted list itself — that list lives in
     * Flutter's secure storage — so the SSID rides in on the intent and the
     * bridge hands it to Dart, which owns the decision.
     */
    private fun consumeTrustIntent(intent: Intent?) {
        val ssid = intent?.getStringExtra(UntrustedWifiNotice.EXTRA_TRUST_SSID) ?: return
        intent.removeExtra(UntrustedWifiNotice.EXTRA_TRUST_SSID)
        UntrustedWifiNotice.dismiss(this)
        tunnel?.trustFromNotification(ssid)
    }

    // The system VPN consent dialog reports back here; the bridge is holding the
    // half-finished connect that depends on the answer.
    @Deprecated("Matches the FlutterActivity override this must hook into.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (tunnel?.onActivityResult(requestCode, resultCode) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    // The location permission behind auto-connect's SSID check reports back here.
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (tunnel?.onRequestPermissionsResult(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        tunnel?.dispose()
        tunnel = null
        super.onDestroy()
    }
}
