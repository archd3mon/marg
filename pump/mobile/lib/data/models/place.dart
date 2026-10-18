class Place {
  final String id;
  final String name;
  final String displayName;
  final double lat;
  final double lng;
  final String type; // 'stop', 'poi', 'station'

  const Place({
    required this.id,
    required this.name,
    required this.displayName,
    required this.lat,
    required this.lng,
    this.type = 'poi',
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    final rawLat = json['lat'];
    final rawLng = json['lng'] ?? json['lon'];
    return Place(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? json['name']?.toString() ?? '',
      lat: (rawLat is num) ? rawLat.toDouble() : double.tryParse(rawLat?.toString() ?? '0') ?? 0.0,
      lng: (rawLng is num) ? rawLng.toDouble() : double.tryParse(rawLng?.toString() ?? '0') ?? 0.0,
      type: json['type']?.toString() ?? 'poi',
    );
  }


  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'display_name': displayName,
    'lat': lat,
    'lng': lng,
    'type': type,
  };
}
