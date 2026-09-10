import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/health_repository.dart';
import '../domain/health_status.dart';

part 'health_providers.g.dart';

/// API reachability, shown on the account screen.
///
/// Not `keepAlive`: this is only meaningful while someone is looking at it, and
/// the value goes stale immediately.
@riverpod
Future<HealthStatus> healthStatus(Ref ref) => ref.watch(healthRepositoryProvider).check();
