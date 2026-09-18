import 'dart:async';

import 'package:aegis_vpn/features/profile/data/profile_repository.dart';
import 'package:aegis_vpn/features/profile/domain/user_profile.dart';
import 'package:aegis_vpn/features/profile/presentation/profile_providers.dart';
import 'package:aegis_vpn/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// The account page is the one whose data goes stale on its own — entitlement
/// expires against the clock — and the shell keeps tabs alive in an IndexedStack,
/// so nothing re-reads the profile unless something invalidates it.
void main() {
  test('invalidating really re-hits the API', () async {
    final repo = _CountingRepository();
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(userProfileProvider.future);
    expect(repo.calls, 1);

    // What the shell does when the Account tab is tapped.
    container.invalidate(userProfileProvider);
    await container.read(userProfileProvider.future);

    expect(repo.calls, 2, reason: 'the tab change has to actually refetch');
  });

  // Every figure on this page moves together — entitlement, the countdown, the
  // lock on each setting. Holding the old profile while the new one lands makes
  // the page rewrite itself piece by piece, which reads as flicker, so this
  // screen asks for the loader that other screens deliberately skip.
  testWidgets('shows a loader while refetching, not the stale profile',
      (tester) async {
    final repo = _GatedRepository();
    await pumpScreen(
      tester,
      const ProfileScreen(),
      surfaceSize: const Size(430, 932),
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    );

    repo.release();
    await tester.pumpAndSettle();
    expect(find.text('first@example.com'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // The tab tap.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfileScreen)),
    );
    container.invalidate(userProfileProvider);
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason: 'the refresh has to show a loader on this screen',
    );
    expect(find.text('first@example.com'), findsNothing);

    repo.release();
    await tester.pumpAndSettle();
    expect(find.text('second@example.com'), findsOneWidget);
  });
}

UserProfile _profile(String email) => UserProfile(
      id: 'u1',
      email: email,
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

class _CountingRepository implements ProfileRepository {
  int calls = 0;

  @override
  Future<UserProfile> fetch() async {
    calls++;
    return _profile('a@b.c');
  }

  @override
  Future<UserProfile> setAdBlockEnabled(bool enabled) => fetch();
  @override
  Future<UserProfile> subscribe(String plan) => fetch();
  @override
  Future<UserProfile> cancelSubscription() => fetch();
}

/// Holds each fetch open until released, so the loading frame can be inspected
/// rather than raced past.
class _GatedRepository implements ProfileRepository {
  final List<Completer<UserProfile>> _pending = [];
  int calls = 0;

  void release() {
    for (final c in _pending) {
      if (!c.isCompleted) {
        c.complete(_profile(calls == 1 ? 'first@example.com' : 'second@example.com'));
      }
    }
    _pending.clear();
  }

  @override
  Future<UserProfile> fetch() {
    calls++;
    final completer = Completer<UserProfile>();
    _pending.add(completer);
    return completer.future;
  }

  @override
  Future<UserProfile> setAdBlockEnabled(bool enabled) => fetch();
  @override
  Future<UserProfile> subscribe(String plan) => fetch();
  @override
  Future<UserProfile> cancelSubscription() => fetch();
}
