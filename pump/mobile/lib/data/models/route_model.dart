class TransitNode {
  final String name;
  final double lat;
  final double lon;

  const TransitNode({
    required this.name,
    required this.lat,
    required this.lon,
  });

  factory TransitNode.fromJson(Map<String, dynamic> json) {
    final rawLat = json['lat'];
    final rawLon = json['lon'] ?? json['lng'];
    return TransitNode(
      name: json['name']?.toString() ?? '',
      lat: (rawLat is num) ? rawLat.toDouble() : double.tryParse(rawLat?.toString() ?? '0') ?? 0.0,
      lon: (rawLon is num) ? rawLon.toDouble() : double.tryParse(rawLon?.toString() ?? '0') ?? 0.0,
    );
  }


  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lon': lon};
}

class RouteLeg {
  final String mode; // 'walk', 'bus', 'metro'
  final String? line;
  final TransitNode fromNode;
  final TransitNode toNode;
  final int lengthM;
  final int durationMins;
  final String? headsign;
  final int? numStops;
  final int? frequencyMins;
  final int? transferWaitMins;
  final List<String> intermediateStops;

  const RouteLeg({
    required this.mode,
    this.line,
    required this.fromNode,
    required this.toNode,
    required this.lengthM,
    required this.durationMins,
    this.headsign,
    this.numStops,
    this.frequencyMins,
    this.transferWaitMins,
    this.intermediateStops = const [],
  });

  factory RouteLeg.fromJson(Map<String, dynamic> json) {
    return RouteLeg(
      mode: json['mode']?.toString() ?? 'walk',
      line: json['line']?.toString(),
      fromNode: TransitNode.fromJson(json['from_node'] as Map<String, dynamic>? ?? {}),
      toNode: TransitNode.fromJson(json['to_node'] as Map<String, dynamic>? ?? {}),
      lengthM: (json['length_m'] as num?)?.toInt() ?? 0,
      durationMins: (json['duration_mins'] as num?)?.toInt() ?? 0,
      headsign: json['headsign']?.toString(),
      numStops: (json['num_stops'] as num?)?.toInt(),
      frequencyMins: (json['frequency_mins'] as num?)?.toInt(),
      transferWaitMins: (json['transfer_wait_mins'] as num?)?.toInt(),
      intermediateStops: (json['intermediate_stops'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'line': line,
    'from_node': fromNode.toJson(),
    'to_node': toNode.toJson(),
    'length_m': lengthM,
    'duration_mins': durationMins,
    'headsign': headsign,
    'num_stops': numStops,
    'frequency_mins': frequencyMins,
    'transfer_wait_mins': transferWaitMins,
    'intermediate_stops': intermediateStops,
  };
}

class TransitRoute {
  final String routeId;
  final double score;
  final int totalTimeMins;
  final int transfers;
  final int totalWalkM;
  final bool usesMetro;
  final String routeType; // 'fastest', 'least_transfers', 'least_walking', 'alternative'
  final List<RouteLeg> legs;
  final List<String> warnings;
  final String departureTimeUsed;
  final int? nextBusMins;

  const TransitRoute({
    required this.routeId,
    this.score = 0.0,
    required this.totalTimeMins,
    required this.transfers,
    required this.totalWalkM,
    this.usesMetro = false,
    required this.routeType,
    required this.legs,
    this.warnings = const [],
    this.departureTimeUsed = '',
    this.nextBusMins,
  });

  factory TransitRoute.fromJson(Map<String, dynamic> json) {
    final rawLegs = json['legs'] as List<dynamic>? ?? [];
    return TransitRoute(
      routeId: json['route_id']?.toString() ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      totalTimeMins: (json['total_time_mins'] as num?)?.toInt() ?? 0,
      transfers: (json['transfers'] as num?)?.toInt() ?? 0,
      totalWalkM: (json['total_walk_m'] as num?)?.toInt() ?? 0,
      usesMetro: json['uses_metro'] as bool? ?? false,
      routeType: json['route_type']?.toString() ?? 'alternative',
      legs: rawLegs.map((l) => RouteLeg.fromJson(l as Map<String, dynamic>)).toList(),
      warnings: (json['warnings'] as List<dynamic>?)?.map((w) => w.toString()).toList() ?? const [],
      departureTimeUsed: json['departure_time_used']?.toString() ?? '',
      nextBusMins: (json['next_bus_mins'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'route_id': routeId,
    'score': score,
    'total_time_mins': totalTimeMins,
    'transfers': transfers,
    'total_walk_m': totalWalkM,
    'uses_metro': usesMetro,
    'route_type': routeType,
    'legs': legs.map((l) => l.toJson()).toList(),
    'warnings': warnings,
    'departure_time_used': departureTimeUsed,
    'next_bus_mins': nextBusMins,
  };
}

typedef Route = TransitRoute;
typedef Leg = RouteLeg;
typedef Node = TransitNode;

