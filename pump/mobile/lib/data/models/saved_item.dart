class SavedPlace {
  final String id;
  final String name; // 'Home', 'Work', 'Gym'
  final String locationName; // 'Kothrud', 'Viman Nagar'
  final double lat;
  final double lng;
  final String type; // 'home', 'work', 'other'

  const SavedPlace({
    required this.id,
    required this.name,
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.type,
  });

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        locationName: json['location_name']?.toString() ?? '',
        lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
        type: json['type']?.toString() ?? 'other',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location_name': locationName,
        'lat': lat,
        'lng': lng,
        'type': type,
      };
}

class SavedRoute {
  final String id;
  final String title; // 'Home -> Work'
  final String fromName;
  final String toName;
  final List<String> busLines; // ['17', '144']
  final String scheduleText; // 'Mon-Fri · 8:40'
  final int totalTimeMins; // 55
  final String statusText; // 'On time'
  final bool isOnTime;
  final double sourceLat;
  final double sourceLng;
  final double destLat;
  final double destLng;

  const SavedRoute({
    required this.id,
    required this.title,
    required this.fromName,
    required this.toName,
    required this.busLines,
    required this.scheduleText,
    required this.totalTimeMins,
    required this.statusText,
    this.isOnTime = true,
    required this.sourceLat,
    required this.sourceLng,
    required this.destLat,
    required this.destLng,
  });

  factory SavedRoute.fromJson(Map<String, dynamic> json) => SavedRoute(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        fromName: json['from_name']?.toString() ?? '',
        toName: json['to_name']?.toString() ?? '',
        busLines: (json['bus_lines'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        scheduleText: json['schedule_text']?.toString() ?? '',
        totalTimeMins: (json['total_time_mins'] as num?)?.toInt() ?? 0,
        statusText: json['status_text']?.toString() ?? '',
        isOnTime: json['is_on_time'] as bool? ?? true,
        sourceLat: (json['source_lat'] as num?)?.toDouble() ?? 0.0,
        sourceLng: (json['source_lng'] as num?)?.toDouble() ?? 0.0,
        destLat: (json['dest_lat'] as num?)?.toDouble() ?? 0.0,
        destLng: (json['dest_lng'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'from_name': fromName,
        'to_name': toName,
        'bus_lines': busLines,
        'schedule_text': scheduleText,
        'total_time_mins': totalTimeMins,
        'status_text': statusText,
        'is_on_time': isOnTime,
        'source_lat': sourceLat,
        'source_lng': sourceLng,
        'dest_lat': destLat,
        'dest_lng': destLng,
      };
}
