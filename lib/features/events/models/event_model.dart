class PeetixEvent {
  const PeetixEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.eventDate,
    required this.locationName,
    this.peatixEventId,
    this.peetixUrl,
    this.imageUrl,
    required this.status,
  });

  final String id;
  final String title;
  final String description;
  final DateTime eventDate;
  final String locationName;
  final String? peatixEventId;
  final String? peetixUrl;
  final String? imageUrl;
  final String status;

  factory PeetixEvent.fromJson(Map<String, dynamic> json) {
    return PeetixEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      eventDate: DateTime.parse(json['event_date'] as String),
      locationName: json['location_name'] as String? ?? '',
      peatixEventId: json['peatix_event_id'] as String?,
      peetixUrl: json['peetix_url'] as String?,
      imageUrl: json['image_url'] as String?,
      status: json['status'] as String? ?? 'active',
    );
  }

  bool get isUpcoming => eventDate.isAfter(DateTime.now());

  String get area {
    final loc = locationName.toLowerCase();
    if (loc.contains('オンライン') || loc.contains('online')) return 'オンライン';
    if (loc.contains('大阪') || loc.contains('なんば') || loc.contains('梅田') ||
        loc.contains('京都') || loc.contains('神戸') || loc.contains('兵庫') ||
        loc.contains('奈良') || loc.contains('滋賀') || loc.contains('和歌山') ||
        loc.contains('関西') || loc.contains('kansai')) return '関西';
    if (loc.contains('東京') || loc.contains('渋谷') || loc.contains('新宿') ||
        loc.contains('品川') || loc.contains('池袋') || loc.contains('六本木') ||
        loc.contains('神奈川') || loc.contains('横浜') || loc.contains('千葉') ||
        loc.contains('埼玉') || loc.contains('関東') || loc.contains('kanto')) return '関東';
    if (loc.isEmpty) return 'その他';
    return 'その他';
  }
}
