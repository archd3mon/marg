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
    final lat = (rawLat is num) ? rawLat.toDouble() : double.tryParse(rawLat?.toString() ?? '0') ?? 0.0;
    final lng = (rawLng is num) ? rawLng.toDouble() : double.tryParse(rawLng?.toString() ?? '0') ?? 0.0;
    final name = json['name']?.toString() ?? '';
    final rawId = json['id']?.toString();
    final id = (rawId != null && rawId.isNotEmpty) ? rawId : '${name}_${lat}_$lng';
    return Place(
      id: id,
      name: name,
      displayName: json['display_name']?.toString() ?? (name.isNotEmpty ? name : ''),
      lat: lat,
      lng: lng,
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
