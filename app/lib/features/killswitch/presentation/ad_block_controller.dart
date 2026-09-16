import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure_log.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../tunnel/presentation/vpn_session.dart';

part 'ad_block_controller.g.dart';

/// The ad-blocking setting.
///
/// Unlike the kill switch, nothing about this lives on the phone. The filtering
/// happens on the node, and which of its two resolvers a device is handed is
/// decided server-side from the account's preference. So the source of truth is
/// `/users/me`, not a local store.
///
/// That makes the write a three-step job, and all three have to happen or the
/// switch lies: save the preference, re-read the device config so the phone has
/// the new resolver, and rebuild the tunnel — the resolver is part of the
/// WireGuard `[Interface]` and a live interface will keep using the old one
/// until it is torn down.
@riverpod
class AdBlockController extends _$AdBlockController {
  @override
  Future<bool> build() async {
    // `adBlockActive`, not `adBlockEnabled`: a user whose plan no longer covers
    // it has the preference stored but is not actually being filtered, and the
    // switch should show what is true.
    return (await ref.watch(userProfileProvider.future)).adBlockActive;
  }

  Future<void> setEnabled({required bool enabled}) async {
    if (state.value == enabled && !state.hasError) return;

    final previous = state;
    state = AsyncData(enabled);

    try {
      final profile =
          await ref.read(profileRepositoryProvider).setAdBlockEnabled(enabled);

      // The server decides. If a plan refused the change, this snaps the switch
      // back to the truth rather than leaving it where the user put it.
      state = AsyncData(profile.adBlockActive);

      // Anything reading the profile — the devices screen's capacity check, the
      // profile tab — should see the new value rather than a stale cached one.
      ref.invalidate(userProfileProvider);

      await ref.read(vpnSessionProvider.notifier).refreshResolver();
    } catch (error, stack) {
      logFailure('changing ad blocking', error, stack);
      state = previous;
      rethrow;
    }
  }
}
