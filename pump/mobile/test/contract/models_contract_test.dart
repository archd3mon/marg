// Parses REAL backend payloads (test/fixtures/real/*) with the app's models.
// These guard the exact mismatches found when the two repos were compared.
import 'package:flutter_test/flutter_test.dart';
import 'package:marg_app/data/models/models.dart';
import 'real_fixture.dart';

void main() {
  group('TransitStop vs real /network/stops', () {
    final raw = (realFixture('stops.json')['stops'] as List).cast<Map<String, dynamic>>();

    test('backend type "bus_stop" maps to app type "bus"', () {
      final bus = raw.firstWhere((s) => s['type'] == 'bus_stop');
      expect(TransitStop.fromJson(bus).type, 'bus');
    });

    test('backend type "metro_station" maps to app type "metro"', () {
      final metro = raw.firstWhere((s) => s['type'] == 'metro_station');
      expect(TransitStop.fromJson(metro).type, 'metro');
    });

    test('coordinates come from lat/lon and are real numbers', () {
      for (final s in raw) {
        final stop = TransitStop.fromJson(s);
        expect(stop.lat, inInclusiveRange(18.0, 19.0));
        expect(stop.lng, inInclusiveRange(73.0, 74.5));
        expect(stop.name, isNotEmpty);
      }
    });

    test('nearby payload carries distance_meters', () {
      final nearby = (realFixture('stops_nearby.json')['stops'] as List).cast<Map<String, dynamic>>();
      expect(nearby, isNotEmpty);
      expect(TransitStop.fromJson(nearby.first).distanceMeters, greaterThan(0));
    });
  });

  group('Place vs real /geocode/search', () {
    final results = (realFixture('geocode_search.json')['results'] as List).cast<Map<String, dynamic>>();

    test('parses name, display name and coordinates', () {
      final p = Place.fromJson(results.first);
      expect(p.name, isNotEmpty);
      expect(p.displayName, isNotEmpty);
      expect(p.lat, inInclusiveRange(18.0, 19.0));
      expect(p.lng, inInclusiveRange(73.0, 74.5));
    });

    test('has a non-empty id even though the backend sends none (lists/keys/recents need it)', () {
      expect(Place.fromJson(results.first).id, isNotEmpty);
    });

    test('two different results never share an id', () {
      final ids = results.map((r) => Place.fromJson(r).id).toSet();
      expect(ids.length, results.length);
    });
  });

  group('TransitRoute vs real /routes/search', () {
    final payload = realFixture('routes_search_bus_only.json') as Map<String, dynamic>;
    final routes = (payload['routes'] as List)
        .map((r) => TransitRoute.fromJson(r as Map<String, dynamic>))
        .toList();

    test('every route has an id, unique within the response', () {
      expect(routes.every((r) => r.routeId.isNotEmpty), isTrue);
      expect(routes.map((r) => r.routeId).toSet().length, routes.length);
    });

    test('bus-only fixture contains no metro', () {
      for (final r in routes) {
        expect(r.usesMetro, isFalse);
        expect(r.legs.any((l) => l.mode == 'metro'), isFalse);
      }
    });

    test('every bus leg has a line label for its chip', () {
      final bus = routes.expand((r) => r.legs).where((l) => l.mode == 'bus');
      expect(bus, isNotEmpty);
      expect(bus.every((l) => (l.line ?? '').isNotEmpty), isTrue);
    });

    test('legs have durations and coordinates', () {
      for (final l in routes.expand((r) => r.legs)) {
        expect(l.durationMins, greaterThanOrEqualTo(0));
        expect(l.fromNode.lat, inInclusiveRange(18.0, 19.0));
        expect(l.toNode.lon, inInclusiveRange(73.0, 74.5));
      }
      expect(routes.first.legs.any((l) => l.durationMins > 0), isTrue);
    });

    test('route types are ones the UI badge table knows', () {
      const known = {'recommended', 'fastest', 'least_transfers', 'least_walking', 'alternative'};
      expect(routes.every((r) => known.contains(r.routeType)), isTrue);
    });

    test('total time, transfers and walk are populated', () {
      for (final r in routes) {
        expect(r.totalTimeMins, greaterThan(0));
        expect(r.transfers, greaterThanOrEqualTo(0));
        expect(r.totalWalkM, greaterThanOrEqualTo(0));
      }
    });
  });
}
