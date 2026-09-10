import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A label/value pair. The app shows a lot of raw backend fields — tunnel IPs,
/// public keys, endpoints — and this keeps them aligned and copyable.
///
/// Two layouts. Wide enough, and the label sits in a fixed column so every value
/// in a section lines up. Below that, label and value stack: a 44-character
/// base64 key beside a label and a copy button does not fit on a small phone.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.monospace = false,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool monospace;
  final bool copyable;

  /// Below this, the side-by-side layout leaves the value too narrow to read.
  static const _stackBelow = 260.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < _stackBelow;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: stacked ? _stackedLayout(context) : _columnLayout(context),
        );
      },
    );
  }

  Widget _columnLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 116.w, child: _label(context)),
        Expanded(child: _value(context)),
        if (copyable) _copyButton(context),
      ],
    );
  }

  Widget _stackedLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context),
        SizedBox(height: 2.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _value(context)),
            if (copyable) _copyButton(context),
          ],
        ),
      ],
    );
  }

  Widget _label(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }

  Widget _value(BuildContext context) {
    final theme = Theme.of(context);
    return SelectableText(
      value,
      style: monospace
          ? theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')
          : theme.textTheme.bodyMedium,
    );
  }

  Widget _copyButton(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tight(Size(32.r, 32.r)),
      padding: EdgeInsets.zero,
      iconSize: 18.r,
      tooltip: 'Copy',
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (context.mounted) showMessage(context, '$label copied');
      },
      icon: const Icon(Icons.copy),
    );
  }
}

/// Shows a message in a snack bar. Used for the outcome of a mutation, where an
/// inline error view would be too heavy.
void showMessage(BuildContext context, String message, {bool isError = false}) {
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? theme.colorScheme.errorContainer : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
