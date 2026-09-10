/// Mirrors the body of `GET /health` in `backend/src/health/health.controller.ts`.
class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.database,
    required this.uptimeSeconds,
    required this.timestamp,
  });

  /// `ok` when the database answered, `degraded` when it did not.
  final String status;

  /// `up` or `down`.
  final String database;

  final int uptimeSeconds;
  final DateTime timestamp;

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String,
      database: json['database'] as String,
      uptimeSeconds: (json['uptimeSeconds'] as num).toInt(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  bool get isHealthy => status == 'ok';
}
