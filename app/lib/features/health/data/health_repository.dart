import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/health_status.dart';

part 'health_repository.g.dart';

/// Talks to `backend/src/health/health.controller.ts`.
class HealthRepository {
  const HealthRepository(this._api);

  final ApiClient _api;

  /// `GET /health`. Unauthenticated and exempt from throttling on the server, so
  /// it uses the public client and is safe to poll.
  Future<HealthStatus> check() async {
    return HealthStatus.fromJson(await _api.getJson(ApiEndpoints.health));
  }
}

@Riverpod(keepAlive: true)
HealthRepository healthRepository(Ref ref) {
  return HealthRepository(ref.watch(publicApiClientProvider));
}
