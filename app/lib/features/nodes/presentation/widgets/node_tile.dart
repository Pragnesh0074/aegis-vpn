import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/vpn_node.dart';

/// One node row: name, region, and how full it is.
///
/// Used by both the servers tab and the node picker on the add-device sheet, so
/// the load figure means the same thing in both places.
class NodeTile extends StatelessWidget {
  const NodeTile({
    super.key,
    required this.node,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  final VpnNode node;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = node.available && onTap != null;

    return ListTile(
      onTap: enabled ? onTap : null,
      enabled: node.available,
      leading: Icon(
        selected ? Icons.check_circle : Icons.dns_outlined,
        color: selected ? theme.colorScheme.primary : null,
      ),
      title: Text(node.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(node.region),
          SizedBox(height: 6.h),
          NodeLoadLine(node: node),
        ],
      ),
      trailing: trailing,
      isThreeLine: true,
    );
  }
}

/// A load bar plus its percentage. Split out so the node picker in the
/// add-device sheet reports capacity identically to the servers tab.
class NodeLoadLine extends StatelessWidget {
  const NodeLoadLine({super.key, required this.node});

  final VpnNode node;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3.r),
            child: LinearProgressIndicator(
              value: node.load.clamp(0, 1),
              minHeight: 5.h,
              color: _loadColor(theme, node.load),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          node.available ? '${Format.percent(node.load)} full' : 'Full',
          style: theme.textTheme.labelSmall?.copyWith(
            color: node.available
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.error,
          ),
        ),
      ],
    );
  }

  /// The bands are advisory: the backend refuses a peer only at 100%, but a nearly
  /// full node is worth steering away from before it gets there.
  Color _loadColor(ThemeData theme, double load) {
    if (load >= 0.9) return theme.colorScheme.error;
    if (load >= 0.7) return theme.colorScheme.tertiary;
    return theme.colorScheme.primary;
  }
}
