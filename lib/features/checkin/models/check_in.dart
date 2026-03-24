import 'package:intl/intl.dart';

class CheckIn {
  const CheckIn({
    required this.id,
    required this.userId,
    required this.facilityId,
    required this.checkedInAt,
    this.checkedOutAt,
    this.facilityName,
    this.facilityAddress,
  });

  final String id;
  final String userId;
  final String facilityId;
  final DateTime checkedInAt;
  final DateTime? checkedOutAt;
  final String? facilityName;
  final String? facilityAddress;

  bool get isActive => checkedOutAt == null;

  String get durationText {
    final end = checkedOutAt ?? DateTime.now();
    final duration = end.difference(checkedInAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '$hours時間$minutes分';
    }
    return '$minutes分';
  }

  static const _weekdays = ['月', '火', '水', '木', '金', '土', '日'];

  /// 相対日付ラベル（時刻なし）: 今日 / 昨日 / M/d (曜日)
  String get relativeDateLabel {
    final local = checkedInAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(local.year, local.month, local.day);

    if (dateDay == today) return '今日';
    if (dateDay == today.subtract(const Duration(days: 1))) return '昨日';
    final wd = _weekdays[local.weekday - 1];
    return '${local.month}/${local.day} ($wd)';
  }

  /// 相対日付ラベル（時刻付き）: 今日 HH:mm / 昨日 HH:mm / M/d (曜日) HH:mm
  String get relativeDateTimeLabel {
    final local = checkedInAt.toLocal();
    final timeStr = DateFormat('HH:mm').format(local);
    return '$relativeDateLabel $timeStr';
  }

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    final facility = json['egg_facilities'] as Map<String, dynamic>?;
    return CheckIn(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      facilityId: json['facility_id'] as String,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      checkedOutAt: json['checked_out_at'] != null
          ? DateTime.parse(json['checked_out_at'] as String)
          : null,
      facilityName: facility?['name'] as String?,
      facilityAddress: facility?['address'] as String?,
    );
  }
}
