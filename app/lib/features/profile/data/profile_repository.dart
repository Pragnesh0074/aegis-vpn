import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/user_profile.dart';

part 'profile_repository.g.dart';

/// Talks to `backend/src/users/users.controller.ts`.
class ProfileRepository {
  const ProfileRepository(this._api);

  final ApiClient _api;

  /// `GET /users/me`. Authenticated — the user id comes from the access token, so
  /// there is no id to pass.
  Future<UserProfile> fetch() async {
    return UserProfile.fromJson(await _api.getJson(ApiEndpoints.me));
  }

  /// `PATCH /users/me/settings`. Returns the whole profile back, so the caller
  /// renders what the server stored rather than what it optimistically assumed —
  /// which matters once a plan can refuse the change.
  Future<UserProfile> setAdBlockEnabled(bool enabled) async {
    final json = await _api.patchJson(
      ApiEndpoints.meSettings,
      body: {'adBlockEnabled': enabled},
    );
    return UserProfile.fromJson(json);
  }

  /// `POST /users/me/ad-block/grant`. Credits one watched rewarded ad and returns
  /// the refreshed profile, whose `adBlockRemaining` is what the UI counts down.
  ///
  /// Called only after the SDK reports the reward was earned. The server takes
  /// that on trust for now — AdMob's server-side verification callback is what
  /// would make it real.
  Future<UserProfile> grantAdBlockReward() async {
    return UserProfile.fromJson(await _api.postJson(ApiEndpoints.meAdBlockGrant));
  }
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
}
