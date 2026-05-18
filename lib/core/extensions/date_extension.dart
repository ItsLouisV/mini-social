import 'package:timeago/timeago.dart' as timeago;

extension DateTimeExtension on DateTime {
  String get timeAgo {
    return timeago.format(this, locale: 'vi');
  }

  String get timeAgoEn {
    return timeago.format(this, locale: 'en');
  }

  String get formattedDate {
    final day = this.day.toString().padLeft(2, '0');
    final month = this.month.toString().padLeft(2, '0');
    final year = this.year.toString();
    return '$day/$month/$year';
  }

  String get formattedDateTime {
    final d = formattedDate;
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$d lúc $h:$m';
  }

  String get chatTimestamp {
    final now = DateTime.now();
    final diff = now.difference(this);
    if (diff.inDays == 0) {
      final h = hour.toString().padLeft(2, '0');
      final m = minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (diff.inDays == 1) {
      return 'Hôm qua';
    } else if (diff.inDays < 7) {
      const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
      return days[weekday % 7];
    } else {
      return formattedDate;
    }
  }

  bool get isToday {
    final now = DateTime.now();
    return day == now.day && month == now.month && year == now.year;
  }

  bool isSameDay(DateTime other) {
    return day == other.day && month == other.month && year == other.year;
  }
}
