import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/secure_store.dart';

part 'node_selection_store.g.dart';

/// Remembers which exit node the user picked on the locations screen.
///
/// Kept in the keystore rather than plain preferences for the same reason
/// `TunnelConfigStore` is: the node is not a secret, but "which country this
/// person routes their traffic through" is exactly the metadata the product
/// exists to keep private, and it should not survive in a world-readable
/// preferences file.
///
/// The absence of a value means automatic — the backend picks the least-loaded
/// node with capacity, which is the right default for almost everyone.
class NodeSelectionStore {
  const NodeSelectionStore(this._store);

  final SecureStore _store;

  static const _key = 'aegis.nodes.selectedNodeId';

  Future<String?> read() => _store.read(_key);

  Future<void> write(String nodeId) => _store.write(_key, nodeId);

  Future<void> clear() => _store.delete(_key);
}

@Riverpod(keepAlive: true)
NodeSelectionStore nodeSelectionStore(Ref ref) {
  return NodeSelectionStore(ref.watch(secureStoreProvider));
}
