import 'package:intl/intl.dart';

/// Utility for formatting dates into user-friendly strings.
class DateFormatter {
  DateFormatter._();

  /// Returns a relative date string like "Just now", "5 min ago",
  /// "Yesterday", or a formatted date.
  static String relative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    // Same year — show month and day
    if (date.year == now.year) {
      return DateFormat('MMM d').format(date);
    }

    // Different year
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Full date-time string: "Apr 26, 2026 at 2:30 PM"
  static String full(DateTime date) {
    return DateFormat('MMM d, yyyy \'at\' h:mm a').format(date);
  }
}
