import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_config.dart';
import '../session/session_controller.dart';
import '../session/session_store.dart';
import 'auth_interceptor.dart';

part 'dio_provider.g.dart';

@Riverpod(keepAlive: true)
AppConfig appConfig(Ref ref) => AppConfig.fromEnvironment();

BaseOptions _baseOptions(AppConfig config) => BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      contentType: Headers.jsonContentType,
      // Let every status through to the error mapper instead of Dio deciding what
      // counts as a failure — the backend's error envelope is identical for all of
      // them and is parsed in one place.
      validateStatus: (status) => status != null && status < 400,
    );

/// A Dio with no auth interceptor.
///
/// Used for `/auth/*` and `/health`, and — importantly — as the client the
/// interceptor itself uses to refresh and to replay a retried request. Sharing the
/// authenticated client for that would recurse.
@Riverpod(keepAlive: true)
Dio rawDio(Ref ref) {
  final dio = Dio(_baseOptions(ref.watch(appConfigProvider)));
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
  }
  ref.onDispose(dio.close);
  return dio;
}

/// The client every authenticated repository uses.
@Riverpod(keepAlive: true)
Dio authedDio(Ref ref) {
  final dio = Dio(_baseOptions(ref.watch(appConfigProvider)));

  dio.interceptors.add(
    AuthInterceptor(
      store: ref.watch(sessionStoreProvider),
      refreshClient: ref.watch(rawDioProvider),
      onSessionExpired: () => ref.read(sessionProvider.notifier).signedOut(),
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
  }

  ref.onDispose(dio.close);
  return dio;
}
