class EggFacility {
  const EggFacility({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.distance,
  });

  final String id;
  final String name;
  final String description;
  final String address;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final double? distance;

  factory EggFacility.fromJson(Map<String, dynamic> json) {
    return EggFacility(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      imageUrl: json['image_url'] as String?,
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
    );
  }

  String get distanceText {
    if (distance == null) return '';
    if (distance! < 1000) {
      return '${distance!.toInt()}m';
    }
    return '${(distance! / 1000).toStringAsFixed(1)}km';
  }
}
