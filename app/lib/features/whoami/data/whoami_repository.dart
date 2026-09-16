import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/exit_check.dart';

part 'whoami_repository.g.dart';

/// Talks to `backend/src/whoami/whoami.controller.ts`.
class WhoamiRepository {
  const WhoamiRepository(this._api);

  final ApiClient _api;

  Future<ExitCheck> check() async {
    return ExitCheck.fromJson(await _api.getJson(ApiEndpoints.whoami));
  }
}

/// Built on the **unauthenticated** client on purpose.
///
/// The check has to work at the two moments an access token is least reliable:
/// right after the interface comes up, and while a refresh is in flight over a
/// route that has just changed underneath it. Turning "am I protected?" into a
/// 401 would be the least useful possible answer, and the endpoint reveals
/// nothing a caller does not already know — its own address.
@Riverpod(keepAlive: true)
WhoamiRepository whoamiRepository(Ref ref) =>
    WhoamiRepository(ref.watch(publicApiClientProvider));
