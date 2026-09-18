import 'package:aegis_vpn/features/profile/data/profile_repository.dart';
import 'package:aegis_vpn/features/profile/domain/user_profile.dart';
import 'package:aegis_vpn/features/profile/presentation/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The account page is the one whose data goes stale on its own — entitlement
/// expires against the clock. The shell keeps tabs alive in an IndexedStack, so
/// nothing re-reads the profile unless something invalidates it.
void main() {
  test('invalidating refetches, and keeps the old profile visible meanwhile', () async {
    final repo = _CountingRepository();
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final first = await container.read(userProfileProvider.future);
    expect(repo.calls, 1);
    expect(first.email, 'a@b.c');

    // What the shell does when the Account tab is tapped.
    container.invalidate(userProfileProvider);

    // The previous value is still readable while the new one is in flight, which
    // is what stops the page flashing a spinner on every tab change.
    final whileRefreshing = container.read(userProfileProvider);
    expect(whileRefreshing.isLoading, isTrue);
    expect(
      whileRefreshing.value?.email,
      'a@b.c',
      reason: 'a refresh must not blank the page it is refreshing',
    );

    await container.read(userProfileProvider.future);
    expect(repo.calls, 2, reason: 'the tab change has to actually re-hit the API');
  });
}

class _CountingRepository implements ProfileRepository {
  int calls = 0;

  @override
  Future<UserProfile> fetch() async {
    calls++;
    return UserProfile(
      id: 'u1',
      email: 'a@b.c',
      createdAt: DateTime.utc(2026),
      deviceCount: 1,
      maxDevices: 5,
      adBlockEnabled: true,
      adBlockEntitled: true,
      access: const AccessState(
        entitled: true,
        onTrial: true,
        subscribed: false,
        remaining: Duration(hours: 5),
      ),
    );
  }

  @override
  Future<UserProfile> setAdBlockEnabled(bool enabled) => fetch();

  @override
  Future<UserProfile> subscribe(String plan) => fetch();

  @override
  Future<UserProfile> cancelSubscription() => fetch();
}
