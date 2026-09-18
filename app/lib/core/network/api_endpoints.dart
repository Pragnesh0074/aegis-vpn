/// Every route the backend exposes, in one place.
///
/// Mirrors the NestJS controllers exactly — there is no global prefix in
/// `main.ts`, so these are root-relative.
abstract final class ApiEndpoints {
  // auth.controller.ts
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';

  // users.controller.ts
  static const me = '/users/me';
  static const meSettings = '/users/me/settings';
  static const meSubscription = '/users/me/subscription';

  // nodes.controller.ts
  static const nodes = '/nodes';

  // devices.controller.ts
  static const devices = '/devices';
  static String device(String id) => '/devices/$id';
  static String deviceConfig(String id) => '/devices/$id/config';

  // health.controller.ts
  static const health = '/health';

  // whoami.controller.ts
  static const whoami = '/whoami';
}
