import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../tunnel/data/tunnel_channel.dart';
import '../../data/whoami_repository.dart';
import '../../domain/exit_check.dart';

part 'exit_check_providers.g.dart';

/// Whether the tunnel is not merely up but demonstrably carrying traffic.
///
/// A bool rather than the status itself, because [exitCheck] depends on it and
/// the status stream emits every second with new counters. Watching the status
/// would re-run the check once a second; watching a bool re-runs it only when
/// the answer changes.
///
/// The handshake is part of the condition on purpose. An interface that is up
/// has routes installed but may have exchanged nothing, and asking the server
/// where we are at that instant would report the old address and read as a leak.
@Riverpod(keepAlive: true)
bool tunnelCarrying(Ref ref) {
  final status = ref.watch(tunnelStatusStreamProvider).value;
  return status != null && status.state.isUp && status.stats.isPeerResponding;
}

/// Where the internet currently thinks this device is.
///
/// Re-checked whenever [tunnelCarrying] flips, which is both transitions worth
/// spending a request on: the tunnel came up and the address should now be the
/// node's, or it went away and the address should be the real one again.
@Riverpod(keepAlive: true)
Future<ExitCheck> exitCheck(Ref ref) {
  ref.watch(tunnelCarryingProvider);
  return ref.watch(whoamiRepositoryProvider).check();
}
