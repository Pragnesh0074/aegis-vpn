import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/profile_repository.dart';
import '../../domain/user_profile.dart';

part 'profile_providers.g.dart';

/// The signed-in user's profile.
///
/// `keepAlive` because the device count it carries is read from more than one tab
/// (the profile screen shows it, the devices screen uses it to decide whether
/// another device may be added), and both should see the same value. The devices
/// module invalidates this after any mutation.
@Riverpod(keepAlive: true)
Future<UserProfile> userProfile(Ref ref) {
  return ref.watch(profileRepositoryProvider).fetch();
}
