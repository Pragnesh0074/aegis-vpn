import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_view.dart';
import '../../nodes/domain/region_geo.dart';
import '../data/session_history_store.dart';
import '../domain/vpn_session_record.dart';
import 'session_recorder.dart';

/// Where the tunnel has been, and for how long.
///
/// Local to this device and never sent anywhere. The screen says so, because a
/// VPN app that starts keeping a usage log owes the user an explicit answer
/// about where that log lives.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'Every recorded session is deleted from this device. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(sessionHistoryStoreProvider).clear();
    ref.invalidate(sessionHistoryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(sessionHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if ((history.value ?? const []).isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              onPressed: () => _clear(context, ref),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: AsyncView(
        value: history,
        onRetry: () => ref.invalidate(sessionHistoryProvider),
        data: (sessions) {
          if (sessions.isEmpty) return const _NoSessions();

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
            itemCount: sessions.length + 1,
            separatorBuilder: (_, _) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              if (index == 0) return _Summary(sessions: sessions);
              return _SessionTile(session: sessions[index - 1]);
            },
          );
        },
      ),
    );
  }
}

/// Everything the list adds up to, which is the number people actually come here
/// for.
class _Summary extends StatelessWidget {
  const _Summary({required this.sessions});

  final List<VpnSessionRecord> sessions;

  @override
  Widget build(BuildContext context) {
    final total = sessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + session.duration,
    );
    final bytes = sessions.fold<int>(0, (sum, session) => sum + session.totalBytes);

    return Container(
      padding: EdgeInsets.all(16.r),
      margin: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Sessions',
                  value: '${sessions.length}',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Protected for',
                  value: Format.duration(total.inSeconds),
                ),
              ),
              Expanded(
                child: _Stat(label: 'Through the tunnel', value: Format.bytes(bytes)),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'Kept on this device only, for the last ${SessionHistoryStore.limit} '
            'sessions. Nothing here is sent to the server.',
            style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textHigh,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          maxLines: 2,
          style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final VpnSessionRecord session;

  @override
  Widget build(BuildContext context) {
    final geo = session.region == null ? null : RegionGeo.parse(session.region!);
    final flag = geo?.flag;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Text(
            flag ?? '🌐',
            style: TextStyle(fontSize: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // A session whose config had already been replaced cannot say
                  // where it exited, and inventing a country would be worse than
                  // admitting it.
                  session.nodeName ?? 'Unknown location',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHigh,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  Format.dateTime(session.startedAt),
                  style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Format.clock(session.duration),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                '↓ ${Format.bytes(session.rxBytes)}  ↑ ${Format.bytes(session.txBytes)}',
                style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoSessions extends StatelessWidget {
  const _NoSessions();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 38.r, color: AppColors.textMuted),
            Gap.md,
            Text(
              'No sessions yet. Each time you connect and disconnect, the tunnel '
              'is recorded here — on this device only.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
