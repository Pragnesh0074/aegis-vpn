import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure_log.dart';
import '../../tunnel/data/tunnel_channel.dart';
import 'auto_connect_controller.dart';

part 'wifi_notice_watcher.g.dart';

/// Turns the platform's Wi-Fi signals into stored state.
///
/// Three things arrive on the status stream and none of them can be handled by
/// the platform itself, because all three end in the trusted list — which lives
/// in Flutter's secure storage:
///
///  * a network was joined, so remember it for the "recently joined" list;
///  * a network was joined that is NOT trusted, so the UI should offer to trust
///    it — acknowledged here so the platform stops repeating it;
///  * the notification's "Trust this network" was tapped, possibly before the
///    app existed, so write it now and tell the platform it landed.
///
/// Watched from the shell for as long as there is a session, like the other
/// always-on listeners: the join this exists to catch happens with no screen
/// open, so anything mounted on a page would miss it.
@Riverpod(keepAlive: true)
class WifiNoticeWatcher extends _$WifiNoticeWatcher {
  /// The last SSID the user answered for, so a status emit that still carries it
  /// — the acknowledgement is a round trip, and the platform keeps publishing
  /// until it lands — does not put the prompt straight back on screen.
  String? _answered;

  /// The SSID the UI should currently be offering to trust, or null.
  @override
  String? build() {
    // Not `state`: on the first build there is none, and reading it is an
    // uninitialised-provider error rather than a null.
    final status = ref.watch(tunnelStatusStreamProvider).value;
    if (status == null) return null;

    final joined = status.joinedSsid;
    if (joined != null) unawaited(_remember(joined));

    // The notification's action wins over the prompt: the user has already
    // answered the question the prompt would ask.
    final requested = status.trustRequestedSsid;
    if (requested != null) {
      unawaited(_trustFromNotification(requested));
      return null;
    }

    final untrusted = status.untrustedSsid;
    if (untrusted == null) {
      _answered = null;
      return null;
    }
    return untrusted == _answered ? null : untrusted;
  }

  Future<void> _remember(String ssid) async {
    try {
      await ref.read(autoConnectProvider.notifier).remember(ssid);
    } catch (error, stack) {
      logFailure('remembering a joined network', error, stack);
    }
  }

  Future<void> _trustFromNotification(String ssid) async {
    try {
      await ref.read(autoConnectProvider.notifier).trust(ssid);
      await ref.read(tunnelChannelProvider).ackTrustRequest();
    } catch (error, stack) {
      logFailure('trusting a network from the notification', error, stack);
    }
  }

  /// The user answered the prompt. Clears it here and on the platform, so it is
  /// not re-offered on the next status emit.
  Future<void> dismiss({String? trust}) async {
    _answered = state;
    state = null;
    try {
      if (trust != null) await ref.read(autoConnectProvider.notifier).trust(trust);
      await ref.read(tunnelChannelProvider).ackUntrustedWifi();
    } catch (error, stack) {
      logFailure('answering the untrusted-network prompt', error, stack);
    }
  }
}
