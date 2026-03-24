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
}
