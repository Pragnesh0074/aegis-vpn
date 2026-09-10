import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../error/app_exception.dart';
import 'dio_provider.dart';

part 'api_client.g.dart';

/// The boundary between Dio and the rest of the app.
///
/// Nothing above this layer imports Dio or sees a `DioException`; every failure
/// arrives as an [AppException]. That is what lets the data layer be tested
/// against a fake and the UI switch on a sealed error type.
class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _guard(() => _dio.get<Map<String, dynamic>>(path));
    return response.data ?? const {};
  }

  Future<List<Map<String, dynamic>>> getList(String path) async {
    final response = await _guard(() => _dio.get<List<dynamic>>(path));
    return (response.data ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    final response = await _guard(() => _dio.post<Map<String, dynamic>>(path, data: body));
    return response.data ?? const {};
  }

  /// For the endpoints that answer `204 No Content` — `/auth/logout` and
  /// `DELETE /devices/:id`.
  Future<void> postEmpty(String path, {Object? body}) {
    return _guard(() => _dio.post<void>(path, data: body));
  }

  Future<void> delete(String path) {
    return _guard(() => _dio.delete<void>(path));
  }

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() send) async {
    try {
      return await send();
    } on DioException catch (error) {
      throw _toAppException(error);
    }
  }

  AppException _toAppException(DioException error) {
    // The interceptor rejects with an already-typed error (no session, expired
    // session). Pass it through rather than flattening it to a network failure.
    final inner = error.error;
    if (inner is AppException) return inner;

    final status = error.response?.statusCode;
    if (status != null) {
      return ApiException.fromResponse(status, error.response?.data);
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const NetworkException('The server took too long to respond.'),
      DioExceptionType.connectionError ||
      DioExceptionType.unknown =>
        const NetworkException(),
      DioExceptionType.cancel => const NetworkException('Request cancelled.'),
      DioExceptionType.badCertificate =>
        const NetworkException('The server certificate could not be verified.'),
      // Includes badResponse with no status, and any type a future Dio adds.
      _ => const NetworkException('Unexpected response from the server.'),
    };
  }
}

/// Authenticated client — attaches the bearer token and refreshes it.
@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) => ApiClient(ref.watch(authedDioProvider));

/// Unauthenticated client, for `/auth/*` and `/health`.
@Riverpod(keepAlive: true)
ApiClient publicApiClient(Ref ref) => ApiClient(ref.watch(rawDioProvider));
