// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_history_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionHistoryStore)
final sessionHistoryStoreProvider = SessionHistoryStoreProvider._();

final class SessionHistoryStoreProvider
    extends
        $FunctionalProvider<
          SessionHistoryStore,
          SessionHistoryStore,
          SessionHistoryStore
        >
    with $Provider<SessionHistoryStore> {
  SessionHistoryStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionHistoryStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionHistoryStoreHash();

  @$internal
  @override
  $ProviderElement<SessionHistoryStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionHistoryStore create(Ref ref) {
    return sessionHistoryStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionHistoryStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionHistoryStore>(value),
    );
  }
}

String _$sessionHistoryStoreHash() =>
    r'610ae7cf219713f01337ccc54c890d019b5f38ed';
