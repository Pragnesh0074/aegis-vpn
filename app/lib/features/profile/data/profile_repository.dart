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
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
}
