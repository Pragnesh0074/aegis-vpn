// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in user's profile.
///
/// `keepAlive` because the device count it carries is read from more than one tab
/// (the profile screen shows it, the devices screen uses it to decide whether
/// another device may be added), and both should see the same value. The devices
/// module invalidates this after any mutation.

@ProviderFor(userProfile)
final userProfileProvider = UserProfileProvider._();

/// The signed-in user's profile.
///
/// `keepAlive` because the device count it carries is read from more than one tab
/// (the profile screen shows it, the devices screen uses it to decide whether
/// another device may be added), and both should see the same value. The devices
/// module invalidates this after any mutation.

final class UserProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserProfile>,
          UserProfile,
          FutureOr<UserProfile>
        >
    with $FutureModifier<UserProfile>, $FutureProvider<UserProfile> {
  /// The signed-in user's profile.
  ///
  /// `keepAlive` because the device count it carries is read from more than one tab
  /// (the profile screen shows it, the devices screen uses it to decide whether
  /// another device may be added), and both should see the same value. The devices
  /// module invalidates this after any mutation.
  UserProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userProfileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userProfileHash();

  @$internal
  @override
  $FutureProviderElement<UserProfile> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UserProfile> create(Ref ref) {
    return userProfile(ref);
  }
}

String _$userProfileHash() => r'e3b13250889706c121001b96218ef277f95e740c';
