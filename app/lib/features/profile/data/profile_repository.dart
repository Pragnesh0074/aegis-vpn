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

  /// `POST /users/me/subscription` — the DUMMY checkout.
  ///
  /// Takes no money and the server verifies nothing. It exists so the paywall
  /// can be walked end to end before a payment provider is chosen; a real one
  /// would grant access from a signed webhook, never from this call.
  Future<UserProfile> subscribe(String plan) async {
    return UserProfile.fromJson(
      await _api.postJson(ApiEndpoints.meSubscription, body: {'plan': plan}),
    );
  }

  /// Clears the dummy subscription, so the paywall can be tested again.
  Future<UserProfile> cancelSubscription() async {
    await _api.delete(ApiEndpoints.meSubscription);
    return fetch();
  }
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
}
