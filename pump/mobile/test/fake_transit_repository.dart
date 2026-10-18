import 'dart:convert';
import 'dart:io';
import 'package:marg_app/data/models/models.dart';
import 'package:marg_app/data/repositories/transit_repository.dart';

class FakeTransitRepository extends TransitRepository {
  final String fixturesPath;
  Exception? routesSearchError;
  bool returnEmptyRoutes = false;

  FakeTransitRepository({
    this.fixturesPath = 'test/fixtures',
    this.routesSearchError,
    this.returnEmptyRoutes = false,
  });

  String _readFixture(String filename) {
    final file = File('$fixturesPath/$filename');
    if (!file.existsSync()) {
      throw FileSystemException('Fixture file not found', file.path);
    }
    return file.readAsStringSync();
  }

  @override
  Future<Map<String, dynamic>> getHealth() async {
    final raw = _readFixture('health.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<List<Stop>> getNearbyStops(double userLat, double userLng) async {
    final raw = _readFixture('stops.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final stops = (data['stops'] as List)
        .map((s) => Stop.fromJson(s as Map<String, dynamic>))
        .where((s) => s.type == 'bus')
        .toList();
    return stops;
  }

  @override
  Future<List<Place>> searchGeocode(String query) async {
    final raw = _readFixture('geocode_search.json');
    final data = jsonDecode(raw) as List;
    final places = data.map((p) => Place.fromJson(p as Map<String, dynamic>)).toList();
    if (query.isEmpty) return places;
    final q = query.toLowerCase();
    return places.where((p) => p.name.toLowerCase().contains(q) || p.displayName.toLowerCase().contains(q)).toList();
  }

  @override
  Future<List<Route>> searchRoutes({
    required double srcLat,
    required double srcLng,
    required double destLat,
    required double destLng,
    String? departureTime,
    String priority = 'fastest',
  }) async {
    if (routesSearchError != null) {
      throw routesSearchError!;
    }
    if (returnEmptyRoutes) {
      return [];
    }
    final raw = _readFixture('routes_search.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final routes = (data['routes'] as List)
        .map((r) => Route.fromJson(r as Map<String, dynamic>))
        .toList();
    return routes;
  }
}
