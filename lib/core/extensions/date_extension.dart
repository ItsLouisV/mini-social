import 'package:timeago/timeago.dart' as timeago;

extension DateTimeExtension on DateTime {
  // Luôn làm việc với giờ địa phương (local time)
  DateTime get _local => isUtc ? toLocal() : this;

  String get timeAgo {
    return timeago.format(_local, locale: 'vi');
  }

  String get timeAgoEn {
    return timeago.format(_local, locale: 'en');
  }

  String get formattedDate {
    final local = _local;
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day/$month/$year';
  }

  String get formattedDateTime {
    final d = formattedDate;
    final local = _local;
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$d lúc $h:$m';
  }

  String get localTimeHHmm {
    final local = _local;
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get chatTimestamp {
    final local = _local;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sixDaysAgo = today.subtract(const Duration(days: 6));

    final dateToCompare = DateTime(local.year, local.month, local.day);

    if (dateToCompare == today) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (dateToCompare == yesterday) {
      return 'Hôm qua';
    } else if (dateToCompare.isAfter(sixDaysAgo)) {
      const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
      final index = local.weekday == 7 ? 0 : local.weekday;
      return days[index];
    } else {
      return formattedDate;
    }
  }

  bool get isToday {
    final local = _local;
    final now = DateTime.now();
    return local.day == now.day && local.month == now.month && local.year == now.year;
  }

  bool isSameDay(DateTime other) {
    final local = _local;
    final otherLocal = other._local;
    return local.day == otherLocal.day &&
        local.month == otherLocal.month &&
        local.year == otherLocal.year;
  }
}
