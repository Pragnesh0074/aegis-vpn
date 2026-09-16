// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_recorder.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Sessions already written, newest first.

@ProviderFor(sessionHistory)
final sessionHistoryProvider = SessionHistoryProvider._();

/// Sessions already written, newest first.

final class SessionHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VpnSessionRecord>>,
          List<VpnSessionRecord>,
          FutureOr<List<VpnSessionRecord>>
        >
    with
        $FutureModifier<List<VpnSessionRecord>>,
        $FutureProvider<List<VpnSessionRecord>> {
  /// Sessions already written, newest first.
  SessionHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionHistoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionHistoryHash();

  @$internal
  @override
  $FutureProviderElement<List<VpnSessionRecord>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VpnSessionRecord>> create(Ref ref) {
    return sessionHistory(ref);
  }
}

String _$sessionHistoryHash() => r'8da8131d30bcbe414c2eeef568371ae143908cde';

/// Turns the live status stream into a record per session.
///
/// The numbers were already being computed — the connect screen shows a session
/// clock and transfer counters — and then discarded the moment the tunnel went
/// down. This keeps them.
///
/// Two details are what make the totals true rather than approximately true:
///
/// The platform reports zeroes once the interface is gone, so the counters have
/// to be captured while it is still up. The last sample seen while connected is
/// what gets written, not whatever arrives with the teardown.
///
/// And WireGuard's counters restart from zero when the interface is rebuilt,
/// which the kill switch does routinely. A counter that went backwards means a
/// new interface, not traffic flowing backwards, so the previous reading is
/// banked and the new one starts from there. Without that, a session that
/// survived three reconnects would report only what moved after the last one.

@ProviderFor(SessionRecorder)
final sessionRecorderProvider = SessionRecorderProvider._();

/// Turns the live status stream into a record per session.
///
/// The numbers were already being computed — the connect screen shows a session
/// clock and transfer counters — and then discarded the moment the tunnel went
/// down. This keeps them.
///
/// Two details are what make the totals true rather than approximately true:
///
/// The platform reports zeroes once the interface is gone, so the counters have
/// to be captured while it is still up. The last sample seen while connected is
/// what gets written, not whatever arrives with the teardown.
///
/// And WireGuard's counters restart from zero when the interface is rebuilt,
/// which the kill switch does routinely. A counter that went backwards means a
/// new interface, not traffic flowing backwards, so the previous reading is
/// banked and the new one starts from there. Without that, a session that
/// survived three reconnects would report only what moved after the last one.
final class SessionRecorderProvider
    extends $NotifierProvider<SessionRecorder, void> {
  /// Turns the live status stream into a record per session.
  ///
  /// The numbers were already being computed — the connect screen shows a session
  /// clock and transfer counters — and then discarded the moment the tunnel went
  /// down. This keeps them.
  ///
  /// Two details are what make the totals true rather than approximately true:
  ///
  /// The platform reports zeroes once the interface is gone, so the counters have
  /// to be captured while it is still up. The last sample seen while connected is
  /// what gets written, not whatever arrives with the teardown.
  ///
  /// And WireGuard's counters restart from zero when the interface is rebuilt,
  /// which the kill switch does routinely. A counter that went backwards means a
  /// new interface, not traffic flowing backwards, so the previous reading is
  /// banked and the new one starts from there. Without that, a session that
  /// survived three reconnects would report only what moved after the last one.
  SessionRecorderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionRecorderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionRecorderHash();

  @$internal
  @override
  SessionRecorder create() => SessionRecorder();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$sessionRecorderHash() => r'b56fa5641aefa8c7d6d7a0abb2078796e98e6dfe';

/// Turns the live status stream into a record per session.
///
/// The numbers were already being computed — the connect screen shows a session
/// clock and transfer counters — and then discarded the moment the tunnel went
/// down. This keeps them.
///
/// Two details are what make the totals true rather than approximately true:
///
/// The platform reports zeroes once the interface is gone, so the counters have
/// to be captured while it is still up. The last sample seen while connected is
/// what gets written, not whatever arrives with the teardown.
///
/// And WireGuard's counters restart from zero when the interface is rebuilt,
/// which the kill switch does routinely. A counter that went backwards means a
/// new interface, not traffic flowing backwards, so the previous reading is
/// banked and the new one starts from there. Without that, a session that
/// survived three reconnects would report only what moved after the last one.

abstract class _$SessionRecorder extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
