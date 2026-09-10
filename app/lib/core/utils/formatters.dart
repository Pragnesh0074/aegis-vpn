import 'package:intl/intl.dart';

/// Date and number formatting used across screens.
abstract final class Format {
  static final _dateTime = DateFormat('d MMM y, HH:mm');
  static final _date = DateFormat('d MMM y');

  /// The API returns UTC ISO strings; every timestamp is shown in local time.
  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());

  static String date(DateTime value) => _date.format(value.toLocal());

  /// `lastSeenAt` is nullable on a device that has never connected.
  static String lastSeen(DateTime? value) => value == null ? 'Never' : relative(value);

  /// Coarse relative time. Enough for "when did this device last check in".
  static String relative(DateTime value) {
    final delta = DateTime.now().toUtc().difference(value.toUtc());
    if (delta.isNegative || delta.inMinutes < 1) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 30) return '${delta.inDays}d ago';
    return dateTime(value);
  }

  /// `NodeSummary.load` is 0.0-1.0.
  static String percent(double value) => '${(value * 100).round()}%';

  /// `uptimeSeconds` from `GET /health`.
  static String duration(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  /// Tunnel transfer counters. Binary units, matching what `wg show` reports.
  static String bytes(int value) {
    if (value < 1024) return '$value B';
    const units = ['KiB', 'MiB', 'GiB', 'TiB'];
    var size = value / 1024;
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unit]}';
  }

  /// Long base64 keys are unreadable in a list row; the full value stays
  /// selectable and copyable on the detail screen.
  static String truncateKey(String key, {int head = 10, int tail = 6}) {
    if (key.length <= head + tail + 1) return key;
    return '${key.substring(0, head)}…${key.substring(key.length - tail)}';
  }
}
