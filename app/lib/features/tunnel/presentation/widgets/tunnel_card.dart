import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/tunnel_status.dart';
import '../controller/tunnel_controller.dart';
import '../../data/tunnel_channel.dart';

/// Connect/disconnect for one device, with what the tunnel is actually doing.
///
/// Reports two different things on purpose. "Connected" means the interface is
/// up and holding the routes; the handshake line underneath says whether the peer
/// is answering. A tunnel can sit in the first state and carry nothing — a
/// blocked UDP port or a revoked peer look exactly like that — so showing only a
/// green badge would tell someone they are protected when they are not.
class TunnelCard extends ConsumerWidget {
  const TunnelCard({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status =
        ref.watch(tunnelStatusStreamProvider).value ??
        TunnelStatus.disconnected;
    final command = ref.watch(tunnelControllerProvider);

    // Another device's tunnel is up. Connecting this one would tear that down,
    // so say so rather than silently switching.
    final otherDeviceIsUp =
        status.state.isUp &&
        status.deviceId != null &&
        status.deviceId != deviceId;
    final isThisDevice = status.deviceId == deviceId;
    final state = isThisDevice ? status.state : TunnelState.disconnected;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: Gap.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StateDot(
                  state: state,
                  isPeerResponding: status.stats.isPeerResponding,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _headline(state),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        _detail(state, status),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (state.isUp) ...[
              Gap.sm,
              Row(
                children: [
                  Expanded(
                    child: _Counter(
                      label: 'Received',
                      bytes: status.stats.rxBytes,
                    ),
                  ),
                  Expanded(
                    child: _Counter(label: 'Sent', bytes: status.stats.txBytes),
                  ),
                ],
              ),
            ],
            if (otherDeviceIsUp) ...[
              Gap.sm,
              Text(
                'Another device is connected. Connecting this one will disconnect it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (command.hasError) ...[
              Gap.sm,
              Text(
                _errorText(command.error!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            Gap.md,
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                // Disabled only while a command or a platform transition is in
                // flight, so the button never fights the state it is showing.
                onPressed: command.isLoading || state.isBusy
                    ? null
                    : () => ref
                          .read(tunnelControllerProvider.notifier)
                          .toggle(deviceId),
                icon: Icon(state.isUp ? Icons.link_off : Icons.shield_outlined),
                label: Text(_buttonLabel(state, command.isLoading)),
                style: state.isUp
                    ? FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.errorContainer,
                        foregroundColor: theme.colorScheme.onErrorContainer,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _headline(TunnelState state) => switch (state) {
    TunnelState.connected => 'Connected',
    TunnelState.connecting => 'Connecting',
    TunnelState.disconnecting => 'Disconnecting',
    TunnelState.disconnected => 'Not connected',
  };

  static String _detail(TunnelState state, TunnelStatus status) {
    return switch (state) {
      TunnelState.connected when status.stats.isPeerResponding =>
        'Handshake ${Format.lastSeen(status.stats.lastHandshake).toLowerCase()}',
      // Up but nothing coming back. The usual causes are a blocked UDP 51820 or a
      // peer that was revoked server-side while the tunnel stayed up.
      TunnelState.connected =>
        'Interface up, but the server has not replied yet',
      TunnelState.connecting => 'Waiting for the system VPN permission',
      TunnelState.disconnecting => 'Tearing down the interface',
      TunnelState.disconnected => 'Traffic is not being tunnelled',
    };
  }

  static String _buttonLabel(TunnelState state, bool isCommandRunning) {
    if (isCommandRunning) return 'Please wait';
    return switch (state) {
      TunnelState.connected => 'Disconnect',
      TunnelState.connecting => 'Connecting',
      TunnelState.disconnecting => 'Disconnecting',
      TunnelState.disconnected => 'Connect',
    };
  }

  static String _errorText(Object error) {
    if (error is TunnelException) {
      return error.isPermissionDenied
          ? 'Permission is needed to create a VPN connection. Tap Connect and allow it.'
          // Includes the case where the prompt never rendered: error.message
          // then explains what is blocking it, which retrying will not clear.
          : error.message;
    }
    return 'Could not change the tunnel. Try again.';
  }
}

class _StateDot extends StatelessWidget {
  const _StateDot({required this.state, required this.isPeerResponding});

  final TunnelState state;
  final bool isPeerResponding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (state.isBusy) {
      return SizedBox(
        width: 14.r,
        height: 14.r,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // Amber, not green, for an interface that is up without a handshake — the
    // distinction the headline alone cannot carry.
    final color = switch (state) {
      TunnelState.connected when isPeerResponding => theme.colorScheme.primary,
      TunnelState.connected => Colors.amber.shade700,
      _ => theme.colorScheme.outline,
    };

    return Container(
      width: 14.r,
      height: 14.r,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.bytes});

  final String label;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(Format.bytes(bytes), style: theme.textTheme.titleSmall),
      ],
    );
  }
}
