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
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sixDaysAgo = today.subtract(const Duration(days: 6));

    final dateToCompare = DateTime(year, month, day);

    if (dateToCompare == today) {
      final h = hour.toString().padLeft(2, '0');
      final m = minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (dateToCompare == yesterday) {
      return 'Hôm qua';
    } else if (dateToCompare.isAfter(sixDaysAgo)) {
      const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
      final index = weekday == 7 ? 0 : weekday;
      return days[index];
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
