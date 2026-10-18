import 'dart:math';
import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../models/place.dart';
import '../models/stop.dart';
import '../models/route_model.dart';
import '../models/alert_model.dart';

class TransitRepository {
  final ApiClient apiClient;
  final bool isRelease;

  TransitRepository({ApiClient? client, bool? isRelease})
      : apiClient = client ?? ApiClient(),
        isRelease = isRelease ?? kReleaseMode;

  // Pune Stops dataset for fallback/offline
  static const List<TransitStop> _puneStops = [
    TransitStop(
      id: 'kd_01',
      name: 'Kothrud Depot',
      lat: 18.5074,
      lng: 73.8077,
      type: 'bus',
      subtext: 'Karve Road',
      distanceMeters: 120,
      etas: [StopEta(route: '17', mins: 4), StopEta(route: '144', mins: 4)],
    ),
    TransitStop(
      id: 'pp_02',
      name: 'Paud Phata',
      lat: 18.5098,
      lng: 73.8180,
      type: 'bus',
      subtext: 'Paud Road',
      distanceMeters: 340,
      etas: [StopEta(route: '113', mins: 11)],
    ),
    TransitStop(
      id: 'ns_03',
      name: 'Nal Stop',
      lat: 18.5126,
      lng: 73.8291,
      type: 'bus',
      subtext: 'Karve Road',
      distanceMeters: 620,
      etas: [StopEta(route: '17', mins: 6), StopEta(route: '118', mins: 9)],
    ),
    TransitStop(
      id: 'dg_04',
      name: 'Deccan Gymkhana',
      lat: 18.5182,
      lng: 73.8413,
      type: 'bus',
      subtext: 'FC Road',
      distanceMeters: 1450,
      etas: [StopEta(route: '144', mins: 3), StopEta(route: '17', mins: 8)],
    ),
    TransitStop(
      id: 'sn_05',
      name: 'Shivajinagar',
      lat: 18.5308,
      lng: 73.8475,
      type: 'bus',
      subtext: 'Old Mumbai-Pune Hwy',
      distanceMeters: 2800,
      etas: [StopEta(route: '144', mins: 5), StopEta(route: '118', mins: 7)],
    ),
    TransitStop(
      id: 'ps_06',
      name: 'Pune Station',
      lat: 18.5284,
      lng: 73.8744,
      type: 'bus',
      subtext: 'Station Road',
      distanceMeters: 3900,
      etas: [StopEta(route: '118', mins: 4), StopEta(route: '158', mins: 12)],
    ),
    TransitStop(
      id: 'yw_07',
      name: 'Yerawada',
      lat: 18.5529,
      lng: 73.8797,
      type: 'bus',
      subtext: 'Ahmednagar Road',
      distanceMeters: 5200,
      etas: [StopEta(route: '144', mins: 8)],
    ),
    TransitStop(
      id: 'vn_08',
      name: 'Viman Nagar Bus Stop',
      lat: 18.5679,
      lng: 73.9143,
      type: 'bus',
      subtext: 'Symbiosis Road',
      distanceMeters: 8400,
      etas: [StopEta(route: '144', mins: 2)],
    ),
  ];

  static const List<Place> _punePlaces = [
    Place(id: 'p1', name: 'Current Location', displayName: 'Kothrud, Pune', lat: 18.5074, lng: 73.8077, type: 'poi'),
    Place(id: 'p2', name: 'Viman Nagar', displayName: 'Pune', lat: 18.5679, lng: 73.9143, type: 'poi'),
    Place(id: 'p3', name: 'Deccan Gymkhana', displayName: 'Pune', lat: 18.5182, lng: 73.8413, type: 'stop'),
    Place(id: 'p4', name: 'Pune Station', displayName: 'Pune', lat: 18.5284, lng: 73.8744, type: 'station'),
    Place(id: 'p5', name: 'Kothrud Depot', displayName: 'Karve Road, Pune', lat: 18.5074, lng: 73.8077, type: 'stop'),
    Place(id: 'p6', name: 'Paud Phata', displayName: 'Paud Road, Pune', lat: 18.5098, lng: 73.8180, type: 'stop'),
    Place(id: 'p7', name: 'Shivajinagar', displayName: 'Pune', lat: 18.5308, lng: 73.8475, type: 'station'),
    Place(id: 'p8', name: 'Swargate', displayName: 'Pune', lat: 18.5018, lng: 73.8586, type: 'station'),
    Place(id: 'p9', name: 'Koregaon Park', displayName: 'Pune', lat: 18.5362, lng: 73.8940, type: 'poi'),
    Place(id: 'p10', name: 'Hadapsar', displayName: 'Pune', lat: 18.5089, lng: 73.9260, type: 'poi'),
  ];

  Future<bool> checkHealth({int maxRetries = 0}) async {
    if (!apiClient.hasBaseUrl || (isRelease && !apiClient.baseUrl.toLowerCase().startsWith('https://'))) {
      if (isRelease) return false;
      return true;
    }
    try {
      final res = await apiClient.get('/health', maxRetries: maxRetries);
      if (res is Map<String, dynamic>) {
        return res['status'] == 'ok' && res['routing_available'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getHealth() async {
    if (apiClient.hasBaseUrl) {
      try {
        final res = await apiClient.get('/health');
        if (res is Map<String, dynamic>) return res;
      } catch (e) {
        // Fall through to error throwing in release mode or fallback in dev
      }
    }
    if (isRelease) {
      throw ApiUnavailableException('Demo mode is disabled in release builds. Configure a secure HTTPS API_BASE.');
    }
    return {'status': 'ok', 'graph': 'ready', 'ml': 'ready', 'search': 'ready'};
  }

  Future<List<TransitStop>> getNearbyStops(double userLat, double userLng) async {
    if (!apiClient.hasBaseUrl) {
      if (isRelease) {
        throw ApiUnavailableException('Demo mode is disabled in release builds. Configure a secure HTTPS API_BASE.');
      }
      return _rankStopsByDistance(_puneStops, userLat, userLng);
    }
    final res = await apiClient.get(
      '/network/stops/nearby',
      queryParameters: {
        'lat': userLat,
        'lng': userLng,
        'radius_m': 1500,
        'limit': 30,
      },
    );
    if (res is Map<String, dynamic> && res['stops'] is List) {
      final stops = (res['stops'] as List)
          .map((s) => TransitStop.fromJson(s as Map<String, dynamic>))
          .where((s) => s.type == 'bus')
          .toList();
      stops.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return stops;
    }
    return [];
  }

  List<TransitStop> _rankStopsByDistance(List<TransitStop> stops, double uLat, double uLng) {
    final list = stops.map((s) {
      final d = _haversineMeters(uLat, uLng, s.lat, s.lng);
      return TransitStop(
        id: s.id,
        name: s.name,
        lat: s.lat,
        lng: s.lng,
        type: s.type,
        subtext: s.subtext,
        distanceMeters: d.round(),
        etas: s.etas,
      );
    }).toList();
    list.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return list;
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  Future<List<Place>> searchGeocode(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    if (!apiClient.hasBaseUrl) {
      if (isRelease) {
        throw ApiUnavailableException('Demo mode is disabled in release builds. Configure a secure HTTPS API_BASE.');
      }
      final qLower = q.toLowerCase();
      return _punePlaces.where((p) {
        return p.name.toLowerCase().contains(qLower) || p.displayName.toLowerCase().contains(qLower);
      }).toList();
    }

    final res = await apiClient.get('/geocode/search', queryParameters: {'q': q, 'limit': 8});
    if (res is Map<String, dynamic> && res['results'] is List) {
      return (res['results'] as List)
          .map((item) => Place.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<TransitRoute>> searchRoutes({
    required double srcLat,
    required double srcLng,
    required double destLat,
    required double destLng,
    String? departureTime,
    String priority = 'fastest',
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    if (apiClient.hasBaseUrl) {
      final body = {
        'source': {'lat': srcLat, 'lng': srcLng},
        'destination': {'lat': destLat, 'lng': destLng},
        'departure_time': departureTime,
        'mode_preferences': {
          'prefer_bus': true,
          'exclude_metro': true,
          'less_walking': priority == 'least_walking',
        }
      };
      final res = await apiClient.post(
        '/routes/search',
        data: body,
        maxRetries: 1,
        retryDelay: retryDelay,
      );
      if (res is Map<String, dynamic> && res['routes'] is List) {
        final rawRoutes = res['routes'] as List;
        if (rawRoutes.isEmpty) return [];

        final topWarnings = (res['warnings'] as List<dynamic>?)
                ?.map((w) => w.toString())
                .toList() ??
            const <String>[];
        final topDepartureTime = res['departure_time_used']?.toString() ?? '';

        final routes = rawRoutes.map((r) {
          final map = r as Map<String, dynamic>;
          final parsed = TransitRoute.fromJson(map);
          return TransitRoute(
            routeId: parsed.routeId,
            score: parsed.score,
            totalTimeMins: parsed.totalTimeMins,
            transfers: parsed.transfers,
            totalWalkM: parsed.totalWalkM,
            usesMetro: parsed.usesMetro,
            routeType: parsed.routeType,
            legs: parsed.legs,
            warnings: topWarnings.isNotEmpty ? topWarnings : parsed.warnings,
            departureTimeUsed: topDepartureTime.isNotEmpty ? topDepartureTime : parsed.departureTimeUsed,
            nextBusMins: parsed.nextBusMins,
          );
        }).toList();

        return _sortRoutes(routes, priority);
      }
      return [];
    }

    if (isRelease) {
      throw ApiUnavailableException('Demo mode is disabled in release builds. Configure a secure HTTPS API_BASE.');
    }

    // High fidelity Pune routes corresponding to 00_overview reference
    final route1 = TransitRoute(
      routeId: 'r_fastest',
      score: 15.0,
      totalTimeMins: 55,
      transfers: 1,
      totalWalkM: 650,
      usesMetro: false,
      routeType: 'fastest',
      nextBusMins: 4,
      departureTimeUsed: departureTime ?? '8:42 AM',
      legs: const [
        RouteLeg(
          mode: 'walk',
          fromNode: TransitNode(name: 'Current Location', lat: 18.5074, lon: 73.8077),
          toNode: TransitNode(name: 'Kothrud Depot', lat: 18.5074, lon: 73.8077),
          lengthM: 450,
          durationMins: 6,
        ),
        RouteLeg(
          mode: 'bus',
          line: '17',
          headsign: 'Deccan Gymkhana',
          fromNode: TransitNode(name: 'Kothrud Depot', lat: 18.5074, lon: 73.8077),
          toNode: TransitNode(name: 'Deccan Gymkhana', lat: 18.5182, lon: 73.8413),
          lengthM: 3800,
          durationMins: 18,
          numStops: 9,
          frequencyMins: 10,
          intermediateStops: ['Paud Phata', 'More Vidyalaya', 'Ideal Colony', 'Nal Stop', 'SNDT College', 'Canara Bank', 'Garware College', 'Deccan Corner'],
        ),
        RouteLeg(
          mode: 'bus',
          line: '144',
          headsign: 'Viman Nagar',
          fromNode: TransitNode(name: 'Deccan Gymkhana', lat: 18.5182, lon: 73.8413),
          toNode: TransitNode(name: 'Viman Nagar Bus Stop', lat: 18.5670, lon: 73.9130),
          lengthM: 8200,
          durationMins: 24,
          numStops: 11,
          transferWaitMins: 4,
          intermediateStops: ['Goodluck Chowk', 'FC Road', 'Shivajinagar Station', 'COEP', 'Wakdewadi', 'Sangamwadi', 'Yerawada', 'Gunjan Talkies', 'Golf Club', 'Shastri Nagar', 'Airport Corner'],
        ),
        RouteLeg(
          mode: 'walk',
          fromNode: TransitNode(name: 'Viman Nagar Bus Stop', lat: 18.5670, lon: 73.9130),
          toNode: TransitNode(name: 'Viman Nagar', lat: 18.5679, lon: 73.9143),
          lengthM: 200,
          durationMins: 3,
        ),
      ],
    );

    final route2 = TransitRoute(
      routeId: 'r_transfers',
      score: 14.0,
      totalTimeMins: 63,
      transfers: 0,
      totalWalkM: 900,
      usesMetro: false,
      routeType: 'least_transfers',
      departureTimeUsed: departureTime ?? '8:42 AM',
      legs: const [
        RouteLeg(
          mode: 'walk',
          fromNode: TransitNode(name: 'Current Location', lat: 18.5074, lon: 73.8077),
          toNode: TransitNode(name: 'Nal Stop', lat: 18.5126, lon: 73.8291),
          lengthM: 650,
          durationMins: 12,
        ),
        RouteLeg(
          mode: 'bus',
          line: '118',
          headsign: 'Viman Nagar Direct',
          fromNode: TransitNode(name: 'Nal Stop', lat: 18.5126, lon: 73.8291),
          toNode: TransitNode(name: 'Viman Nagar Bus Stop', lat: 18.5670, lon: 73.9130),
          lengthM: 9800,
          durationMins: 48,
          numStops: 16,
          intermediateStops: ['Deccan Gymkhana', 'Shivajinagar', 'Pune Station', 'Yerawada', 'Shastri Nagar'],
        ),
        RouteLeg(
          mode: 'walk',
          fromNode: TransitNode(name: 'Viman Nagar Bus Stop', lat: 18.5670, lon: 73.9130),
          toNode: TransitNode(name: 'Viman Nagar', lat: 18.5679, lon: 73.9143),
          lengthM: 250,
          durationMins: 3,
        ),
      ],
    );

    final route3 = TransitRoute(
      routeId: 'r_walking',
      score: 13.0,
      totalTimeMins: 61,
      transfers: 1,
      totalWalkM: 280,
      usesMetro: false,
      routeType: 'least_walking',
      departureTimeUsed: departureTime ?? '8:42 AM',
      legs: const [
        RouteLeg(
          mode: 'walk',
          fromNode: TransitNode(name: 'Current Location', lat: 18.5074, lon: 73.8077),
          toNode: TransitNode(name: 'Kothrud Depot Door', lat: 18.5076, lon: 73.8079),
          lengthM: 200,
          durationMins: 3,
        ),
        RouteLeg(
          mode: 'bus',
          line: '17',
          headsign: 'Deccan Gymkhana',
          fromNode: TransitNode(name: 'Kothrud Depot', lat: 18.5074, lon: 73.8077),
          toNode: TransitNode(name: 'Deccan Gymkhana', lat: 18.5182, lon: 73.8413),
          lengthM: 3800,
          durationMins: 20,
          numStops: 9,
        ),
        RouteLeg(
          mode: 'bus',
          line: '144',
          headsign: 'Viman Nagar',
          fromNode: TransitNode(name: 'Deccan Gymkhana', lat: 18.5182, lon: 73.8413),
          toNode: TransitNode(name: 'Viman Nagar Main Chowk', lat: 18.5675, lon: 73.9138),
          lengthM: 8200,
          durationMins: 25,
          numStops: 11,
          transferWaitMins: 4,
        ),
        RouteLeg(
          mode: 'walk',
          fromNode: TransitNode(name: 'Viman Nagar Main Chowk', lat: 18.5675, lon: 73.9138),
          toNode: TransitNode(name: 'Viman Nagar', lat: 18.5679, lon: 73.9143),
          lengthM: 80,
          durationMins: 1,
        ),
      ],
    );

    final routes = [route1, route2, route3];
    return _sortRoutes(routes, priority);
  }

  List<TransitRoute> _sortRoutes(List<TransitRoute> routes, String priority) {
    final list = List<TransitRoute>.from(routes);
    if (priority == 'fastest') {
      // Fastest first, followed by fewer transfers and less walking
      return list;
    } else if (priority == 'least_transfers') {
      list.sort((a, b) {
        final t = a.transfers.compareTo(b.transfers);
        return t != 0 ? t : a.totalTimeMins.compareTo(b.totalTimeMins);
      });
    } else if (priority == 'least_walking') {
      list.sort((a, b) {
        final w = a.totalWalkM.compareTo(b.totalWalkM);
        return w != 0 ? w : a.totalTimeMins.compareTo(b.totalTimeMins);
      });
    }
    return list;
  }

  List<TransitAlert> getAlerts({
    bool myRoutesOnly = true,
    bool showDemoAlerts = false,
    bool notifyLeaveNow = true,
    bool notifyDelays = true,
    bool notifyServiceChanges = true,
  }) {
    const all = [
      TransitAlert(
        id: 'a1',
        title: 'Route 144 · Delay',
        timeAgo: '8 min ago',
        body: 'About 10 min late near Yerawada because of heavy traffic. Leave 5 min earlier.',
        type: 'delay',
        routeLine: '144',
        isSavedRoute: true,
        isSample: true,
      ),
      TransitAlert(
        id: 'a2',
        title: 'Route 17 · Diversion',
        timeAgo: '1 h ago',
        body: 'Buses skip Karve Road stops near Nal Stop until 6 PM.',
        type: 'diversion',
        routeLine: '17',
        isSavedRoute: true,
        isSample: true,
      ),
      TransitAlert(
        id: 'a3',
        title: 'Your commute',
        timeAgo: 'Today',
        body: 'Leave by 8:35 to reach Viman Nagar by 9:30.',
        type: 'commute',
        routeLine: null,
        isSavedRoute: true,
        isSample: false,
      ),
      TransitAlert(
        id: 'a4',
        title: 'Route 118 · Maintenance',
        timeAgo: '2 h ago',
        body: 'Minor fleet adjustments on Swargate - Pune Station corridor.',
        type: 'maintenance',
        routeLine: '118',
        isSavedRoute: false,
        isSample: true,
      ),
    ];

    return all.where((a) {
      if (a.isSample && !showDemoAlerts) return false;
      if (myRoutesOnly && !a.isSavedRoute) return false;
      if (a.type == 'commute' && !notifyLeaveNow) return false;
      if (a.type == 'delay' && !notifyDelays) return false;
      if (a.type == 'maintenance' && !notifyServiceChanges) return false;
      return true;
    }).toList();
  }
}
