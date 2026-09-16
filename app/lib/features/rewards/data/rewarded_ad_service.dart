import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure_log.dart';
import 'ad_ids.dart';

part 'rewarded_ad_service.g.dart';

/// Why a rewarded ad did not end in a reward. The UI says different things for
/// each: "no ad available" is worth retrying, a dismissal is not an error at all.
enum AdOutcome {
  /// Watched to the end. The only outcome that earns anything.
  earned,

  /// Closed early. The user's choice, not a failure — say nothing alarming.
  dismissed,

  /// Nothing to show. Common with a fresh app, a cold ad cache, or no network.
  unavailable,

  /// Loaded but failed to present.
  failed,
}

/// Loads and shows AdMob rewarded ads.
///
/// Deliberately knows nothing about ad blocking or grants — it reports whether a
/// reward was earned and stops there. That keeps the reward *policy* testable
/// without AdMob, which cannot run in a widget test at all.
class RewardedAdService {
  RewardedAdService();

  static bool _initialised = false;

  /// One-time SDK start-up. Safe to call repeatedly; only the first does work.
  Future<void> ensureInitialised() async {
    if (_initialised) return;
    await MobileAds.instance.initialize();
    _initialised = true;
  }

  /// Loads an ad and shows it, resolving once the user is done with it.
  ///
  /// The whole lifecycle is collapsed into one awaited call because callers only
  /// ever care about the outcome, and the callback-plus-field version of this is
  /// where the double-reward bugs live.
  Future<AdOutcome> showRewarded() async {
    try {
      await ensureInitialised();
    } catch (error, stack) {
      logFailure('initialising the ads SDK', error, stack);
      return AdOutcome.unavailable;
    }

    final loaded = Completer<RewardedAd?>();
    try {
      await RewardedAd.load(
        adUnitId: AdIds.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: loaded.complete,
          onAdFailedToLoad: (error) {
            logFailure('loading a rewarded ad', error, StackTrace.current);
            loaded.complete(null);
          },
        ),
      );
    } catch (error, stack) {
      logFailure('requesting a rewarded ad', error, stack);
      return AdOutcome.unavailable;
    }

    final ad = await loaded.future;
    if (ad == null) return AdOutcome.unavailable;

    // Set before showing: the reward callback can fire before the dismiss one,
    // and reading it after both have run is the only ordering that is stable.
    var earned = false;
    final closed = Completer<AdOutcome>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!closed.isCompleted) {
          closed.complete(earned ? AdOutcome.earned : AdOutcome.dismissed);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        logFailure('showing a rewarded ad', error, StackTrace.current);
        if (!closed.isCompleted) closed.complete(AdOutcome.failed);
      },
    );

    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return closed.future;
  }
}

@Riverpod(keepAlive: true)
RewardedAdService rewardedAdService(Ref ref) => RewardedAdService();
