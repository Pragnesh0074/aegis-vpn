import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure_log.dart';
import '../data/tunnel_channel.dart';
import 'vpn_session.dart';

part 'platform_connect_watcher.g.dart';

/// Serves the platform's requests for a tunnel it cannot build itself.
///
/// Two things make such a request: auto-connect arriving at an untrusted network
/// with no config held, and the Quick Settings tile tapped on a cold start.
/// Neither can do the work — building a tunnel from nothing means reading a
/// private key out of the keystore and, on a fresh install, registering a peer
/// with the API. Both are Dart's.
///
/// The request is a standing flag rather than an event, and acknowledging it is
/// this notifier's other half. That is what makes a tile tap work: the tap
/// happens seconds before a Flutter engine exists, so anything the app had to
/// hear at that moment would be missed. Instead the request waits, and the first
/// thing to look serves it.
///
/// Watched by the signed-in shell, so it is alive exactly when there is an
/// account to provision against and never when there is not.
@Riverpod(keepAlive: true)
class PlatformConnectWatcher extends _$PlatformConnectWatcher {
  /// True while a request is being served, so the snapshots that arrive in the
  /// meantime do not start a second connect.
  bool _serving = false;

  /// The request already served.
  ///
  /// Belt as well as braces: acknowledging clears the request at the platform,
  /// but an acknowledgement that fails to land would otherwise have the app
  /// connecting on every snapshot for as long as it stayed open. One request,
  /// one attempt.
  DateTime? _served;

  @override
  void build() {
    ref.listen(tunnelStatusStreamProvider, (_, next) {
      final requestedAt = next.value?.connectRequestedAt;
      if (requestedAt == null || _serving || requestedAt == _served) return;

      _serving = true;
      _served = requestedAt;
      unawaited(_serve());
    });
  }

  Future<void> _serve() async {
    try {
      await ref.read(vpnSessionProvider.notifier).connect();
    } catch (error, stack) {
      // Nobody asked for this connect in the app, so nobody is watching for it
      // to fail. The connect screen shows the error if they are looking; this is
      // for when they are not.
      logFailure('serving a connect request from the platform', error, stack);
    } finally {
      await ref.read(tunnelChannelProvider).ackConnectRequest();
      _serving = false;
    }
  }
}
