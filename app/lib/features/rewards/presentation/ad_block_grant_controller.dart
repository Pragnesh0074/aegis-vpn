import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure_log.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../tunnel/presentation/vpn_session.dart';
import '../data/rewarded_ad_service.dart';

part 'ad_block_grant_controller.g.dart';

/// How much filtering one ad buys. Mirrors `AD_BLOCK_GRANT_MS` on the server,
/// which is the authority — this copy only exists so the UI can say "5 minutes"
/// before the first grant has ever been fetched.
const adBlockGrantWindow = Duration(minutes: 5);

/// The live state of the rewarded-ad grant.
class AdBlockGrant {
  const AdBlockGrant({required this.remaining, required this.watching});

  /// Time left on the grant. Zero means filtering is off and an ad is the way back.
  final Duration remaining;

  /// True while an ad is loading or on screen, so the button cannot be tapped twice.
  final bool watching;

  bool get isActive => remaining > Duration.zero;

  AdBlockGrant copyWith({Duration? remaining, bool? watching}) => AdBlockGrant(
        remaining: remaining ?? this.remaining,
        watching: watching ?? this.watching,
      );
}

/// Owns the countdown and the watch-an-ad flow.
///
/// The countdown is driven locally from a single server-supplied duration rather
/// than by polling: the server is the authority on when a grant ends, but asking
/// it every second to render a clock would be absurd. Local drift does not
/// matter, because the client cannot grant itself anything — when the timer hits
/// zero the client re-reads its config and the server hands back the unfiltered
/// resolver, or does not, entirely on its own reckoning.
@Riverpod(keepAlive: true)
class AdBlockGrantController extends _$AdBlockGrantController {
  Timer? _ticker;

  @override
  Future<AdBlockGrant> build() async {
    ref.onDispose(() => _ticker?.cancel());

    final profile = await ref.watch(userProfileProvider.future);
    final grant = AdBlockGrant(remaining: profile.adBlockRemaining, watching: false);
    if (grant.isActive) _startTicking();
    return grant;
  }

  void _startTicking() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state.value;
      if (current == null) return;

      final next = current.remaining - const Duration(seconds: 1);
      if (next > Duration.zero) {
        state = AsyncData(current.copyWith(remaining: next));
        return;
      }

      _ticker?.cancel();
      state = AsyncData(current.copyWith(remaining: Duration.zero));
      unawaited(_onExpired());
    });
  }

  /// The grant ran out. Re-read the config so the tunnel moves to the unfiltered
  /// resolver, and refresh the profile so anything else reading it agrees.
  ///
  /// Failing here is not fatal and is not surfaced: the server has already
  /// stopped handing out the filtering resolver, so the worst case is that this
  /// device keeps filtering until its next reconnect — a user getting slightly
  /// more than they paid for, which is not worth an error dialog.
  Future<void> _onExpired() async {
    try {
      ref.invalidate(userProfileProvider);
      await ref.read(vpnSessionProvider.notifier).refreshResolver();
    } catch (error, stack) {
      logFailure('applying ad-block expiry', error, stack);
    }
  }

  /// Shows a rewarded ad and, if it is watched to the end, credits the grant.
  ///
  /// Returns the outcome so the caller can word its own message — this notifier
  /// has no business deciding what a dismissal should say.
  Future<AdOutcome> watchAdForTime() async {
    final current = state.value;
    if (current == null || current.watching) return AdOutcome.failed;

    state = AsyncData(current.copyWith(watching: true));
    try {
      final outcome = await ref.read(rewardedAdServiceProvider).showRewarded();
      if (outcome != AdOutcome.earned) {
        state = AsyncData(current.copyWith(watching: false));
        return outcome;
      }

      // Take the server's number, not ours. It caps how much can be banked, so
      // adding five minutes locally would eventually show time that is not there.
      final profile = await ref.read(profileRepositoryProvider).grantAdBlockReward();
      ref.invalidate(userProfileProvider);

      state = AsyncData(AdBlockGrant(remaining: profile.adBlockRemaining, watching: false));
      _startTicking();

      // The grant only reaches the tunnel once the device re-reads its config.
      await ref.read(vpnSessionProvider.notifier).refreshResolver();
      return AdOutcome.earned;
    } catch (error, stack) {
      logFailure('crediting a watched ad', error, stack);
      state = AsyncData(current.copyWith(watching: false));
      return AdOutcome.failed;
    }
  }
}
