import 'dart:io';

/// AdMob identifiers.
///
/// These are GOOGLE'S PUBLIC TEST IDS. They serve test creatives, always fill, and
/// earn nothing — which is what makes them safe to develop against.
///
/// Before release, replace both these and the `APPLICATION_ID` meta-data in
/// AndroidManifest.xml. Mixing a real app id with test unit ids, or the reverse,
/// is the combination that gets an AdMob account flagged for invalid traffic, so
/// they have to move together.
abstract final class AdIds {
  /// https://developers.google.com/admob/android/test-ads
  static const _androidRewarded = 'ca-app-pub-3940256099942544/5224354917';

  /// https://developers.google.com/admob/ios/test-ads
  static const _iosRewarded = 'ca-app-pub-3940256099942544/1712485313';

  static String get rewarded => Platform.isIOS ? _iosRewarded : _androidRewarded;

  /// True while the test ids are in use, so the UI can say so rather than let a
  /// tester wonder why every ad is the same placeholder.
  static const usingTestIds = true;
}
