import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure_log.dart';
import '../../../tunnel/data/tunnel_channel.dart';
import '../../../tunnel/data/tunnel_config_store.dart';
import '../../../tunnel/domain/tunnel_status.dart';
import '../../data/session_history_store.dart';
import '../../domain/vpn_session_record.dart';

part 'session_recorder.g.dart';

/// Sessions already written, newest first.
@Riverpod(keepAlive: true)
Future<List<VpnSessionRecord>> sessionHistory(Ref ref) {
  return ref.watch(sessionHistoryStoreProvider).read();
}

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
@Riverpod(keepAlive: true)
class SessionRecorder extends _$SessionRecorder {
  _OpenSession? _open;

  /// Sessions shorter than this with no traffic at all are not written.
  ///
  /// An interface that came up and went straight back down carried nothing and
  /// tells the user nothing; a list full of those would bury the sessions that
  /// matter. Anything that moved a byte is kept however short it was.
  static const _minimumWorthKeeping = Duration(seconds: 2);

  @override
  void build() {
    ref.listen(tunnelStatusStreamProvider, (_, next) {
      final status = next.value;
      if (status == null) return;

      if (status.state.isUp) {
        _sample(status);
      } else {
        _close();
      }
    });

    // A session open when the provider goes away is one the app is losing
    // anyway — the process is going with it — so this is the last chance to
    // write it.
    ref.onDispose(_close);
  }

  void _sample(TunnelStatus status) {
    final open = _open ??= _start(status);
    open.observe(status.stats);
  }

  _OpenSession _start(TunnelStatus status) {
    final session = _OpenSession(startedAt: DateTime.now());

    // Resolved asynchronously and allowed to land late: the config read is a
    // keystore round trip, and holding the session open for it would risk
    // missing the first counters. A session that ends before it resolves is
    // written without a node name, which is honest — the app genuinely could
    // not say.
    final deviceId = status.deviceId;
    if (deviceId != null) {
      unawaited(
        ref
            .read(tunnelConfigStoreProvider)
            .read(deviceId)
            .then((config) {
              if (config == null) return;
              session.nodeName = config.node.name;
              session.region = config.node.region;
            })
            .catchError((Object error, StackTrace stack) {
              logFailure('reading the session node', error, stack);
            }),
      );
    }

    return session;
  }

  void _close() {
    final open = _open;
    if (open == null) return;
    _open = null;

    final record = open.finish();
    if (record == null) return;

    unawaited(
      ref
          .read(sessionHistoryStoreProvider)
          .add(record)
          .then((_) {
            ref.invalidate(sessionHistoryProvider);
          })
          .catchError((Object error, StackTrace stack) {
            // Losing a history row is not worth surfacing to someone who was only
            // trying to disconnect.
            logFailure('recording the session', error, stack);
          }),
    );
  }
}

/// A session in progress, and the counter arithmetic that survives a rebuild.
class _OpenSession {
  _OpenSession({required this.startedAt});

  final DateTime startedAt;
  String? nodeName;
  String? region;

  /// Totals from interfaces that have already been torn down this session.
  int _carriedRx = 0;
  int _carriedTx = 0;

  /// The newest reading from the interface that is up.
  int _rx = 0;
  int _tx = 0;

  void observe(TunnelStats stats) {
    // Backwards means a new interface. Bank what the old one carried before
    // adopting the new reading.
    if (stats.rxBytes < _rx) _carriedRx += _rx;
    if (stats.txBytes < _tx) _carriedTx += _tx;
    _rx = stats.rxBytes;
    _tx = stats.txBytes;
  }

  VpnSessionRecord? finish() {
    final endedAt = DateTime.now();
    final rx = _carriedRx + _rx;
    final tx = _carriedTx + _tx;

    if (endedAt.difference(startedAt) < SessionRecorder._minimumWorthKeeping &&
        rx + tx == 0) {
      return null;
    }

    return VpnSessionRecord(
      startedAt: startedAt,
      endedAt: endedAt,
      rxBytes: rx,
      txBytes: tx,
      nodeName: nodeName,
      region: region,
    );
  }
}
