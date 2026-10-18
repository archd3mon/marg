import 'package:latlong2/latlong.dart';

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
  final List<LatLng> path;
  final List<String> lineOptions;

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
    this.path = const [],
    this.lineOptions = const [],
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
      path: (json['path'] as List<dynamic>?)
              ?.map((p) {
                if (p is List && p.length >= 2) {
                  final lat = (p[0] as num).toDouble();
                  final lon = (p[1] as num).toDouble();
                  return LatLng(lat, lon);
                }
                return null;
              })
              .whereType<LatLng>()
              .toList() ??
          const [],
      lineOptions: (json['line_options'] as List<dynamic>?)
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
    'path': path.map((pt) => [pt.latitude, pt.longitude]).toList(),
    'line_options': lineOptions,
  };
}

/// Pure function used by UI only: merges consecutive legs with the same mode
/// AND same line (e.g. metro stations on the same line, or consecutive walk legs).
/// Never merges different bus lines.
List<RouteLeg> collapseLegs(List<RouteLeg> legs) {
  if (legs.isEmpty) return const [];
  final collapsed = <RouteLeg>[];
  RouteLeg current = legs.first;

  for (int i = 1; i < legs.length; i++) {
    final next = legs[i];
    final bool canMerge;
    if (current.mode != next.mode) {
      canMerge = false;
    } else if (current.mode == 'walk') {
      canMerge = true;
    } else if (current.mode == 'metro') {
      canMerge = (current.line ?? '') == (next.line ?? '');
    } else if (current.mode == 'bus') {
      // Do NOT merge different bus lines. Only merge identical non-empty line.
      canMerge = current.line != null &&
          current.line!.isNotEmpty &&
          current.line == next.line;
    } else {
      canMerge = (current.line ?? '') == (next.line ?? '');
    }

    if (canMerge) {
      // Concatenate path, deduplicating identical adjacent point if present
      final mergedPath = <LatLng>[...current.path];
      if (next.path.isNotEmpty) {
        if (mergedPath.isNotEmpty &&
            mergedPath.last.latitude == next.path.first.latitude &&
            mergedPath.last.longitude == next.path.first.longitude) {
          mergedPath.addAll(next.path.skip(1));
        } else {
          mergedPath.addAll(next.path);
        }
      }

      // Merge intermediate stops: current's toNode becomes an intermediate stop
      final mergedStops = <String>[...current.intermediateStops];
      if (current.toNode.name.isNotEmpty && !mergedStops.contains(current.toNode.name)) {
        mergedStops.add(current.toNode.name);
      }
      for (final s in next.intermediateStops) {
        if (!mergedStops.contains(s)) {
          mergedStops.add(s);
        }
      }

      // Merge lineOptions
      final mergedLineOptions = <String>[...current.lineOptions];
      for (final opt in next.lineOptions) {
        if (!mergedLineOptions.contains(opt)) {
          mergedLineOptions.add(opt);
        }
      }

      final mergedNumStops = (current.numStops != null || next.numStops != null)
          ? ((current.numStops ?? 0) + (next.numStops ?? 0))
          : null;

      current = RouteLeg(
        mode: current.mode,
        line: current.line,
        fromNode: current.fromNode,
        toNode: next.toNode,
        lengthM: current.lengthM + next.lengthM,
        durationMins: current.durationMins + next.durationMins,
        headsign: next.headsign ?? current.headsign,
        numStops: mergedNumStops,
        frequencyMins: current.frequencyMins ?? next.frequencyMins,
        transferWaitMins: current.transferWaitMins ?? next.transferWaitMins,
        intermediateStops: mergedStops,
        path: mergedPath,
        lineOptions: mergedLineOptions,
      );
    } else {
      collapsed.add(current);
      current = next;
    }
  }
  collapsed.add(current);
  return collapsed;
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

