// Runs the REAL ApiClient + TransitRepository against captured backend payloads.
// Requires the Phase M2 seam:  ApiClient({String? customBaseUrl, Dio? dio})
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marg_app/data/api_client.dart';
import 'package:marg_app/data/repositories/transit_repository.dart';
import 'real_fixture.dart';
import 'stub_adapter.dart';

const _base = 'http://stub.local/api/v1';

(TransitRepository, StubAdapter) _repo((int, Object?) Function(RequestOptions) handler) {
  final adapter = StubAdapter(handler);
  final dio = Dio()..httpClientAdapter = adapter;
  return (TransitRepository(client: ApiClient(customBaseUrl: _base, dio: dio)), adapter);
}

void main() {
  group('geocode', () {
    test('unwraps {results: [...]} and returns REAL places, not the offline mock list', () async {
      final (repo, adapter) = _repo((o) => (200, realFixture('geocode_search.json')));
      final places = await repo.searchGeocode('kothrud');
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, endsWith('/geocode/search'));
      expect(places, isNotEmpty);
      expect(places.first.displayName, isNot('Kothrud, Pune'), reason: 'that string only exists in the hardcoded mock');
      expect(places.map((p) => p.name), contains('Kothrud Bus Depot'));
    });

    test('a backend failure surfaces as an error instead of silently showing mock places', () async {
      final (repo, _) = _repo((o) => (500, {'detail': 'boom'}));
      expect(() => repo.searchGeocode('kothrud'), throwsA(isA<Exception>()));
    });

    test('queries shorter than 2 chars do not hit the network', () async {
      final (repo, adapter) = _repo((o) => (200, realFixture('geocode_search.json')));
      await repo.searchGeocode('k');
      expect(adapter.requests, isEmpty);
    });
  });

  group('nearby stops', () {
    test('uses /network/stops/nearby with the user position and returns bus stops by distance', () async {
      final (repo, adapter) = _repo((o) => (200, realFixture('stops_nearby.json')));
      final stops = await repo.getNearbyStops(18.5074, 73.8077);
      final req = adapter.requests.single;
      expect(req.path, endsWith('/network/stops/nearby'));
      expect(req.queryParameters['lat'], 18.5074);
      expect(req.queryParameters['lng'], 73.8077);
      expect(stops, isNotEmpty);
      expect(stops.every((s) => s.type == 'bus'), isTrue, reason: 'metro is hidden in v1');
      final d = stops.map((s) => s.distanceMeters).toList();
      expect(d, [...d]..sort());
    });

    test('a backend failure surfaces as an error', () async {
      final (repo, _) = _repo((o) => (500, {'detail': 'boom'}));
      expect(() => repo.getNearbyStops(18.5, 73.8), throwsA(isA<Exception>()));
    });
  });

  group('route search', () {
    test('sends the v1 bus-only request the backend understands', () async {
      final (repo, adapter) = _repo((o) => (200, realFixture('routes_search_bus_only.json')));
      await repo.searchRoutes(
        srcLat: 18.5074, srcLng: 73.8077, destLat: 18.5679, destLng: 73.9143,
        departureTime: '2026-10-19T08:42:00+05:30', priority: 'least_walking',
      );
      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['source'], {'lat': 18.5074, 'lng': 73.8077});
      expect(body['destination'], {'lat': 18.5679, 'lng': 73.9143});
      expect(body['departure_time'], '2026-10-19T08:42:00+05:30');
      final prefs = body['mode_preferences'] as Map<String, dynamic>;
      expect(prefs['exclude_metro'], isTrue);
      expect(prefs['less_walking'], isTrue);
    });

    test('copies top-level warnings and departure_time_used onto each route', () async {
      final payload = Map<String, dynamic>.from(realFixture('routes_search_bus_only.json') as Map)
        ..['warnings'] = ['High-frequency direct connections may have ceased for the night.'];
      final (repo, _) = _repo((o) => (200, payload));
      final routes = await repo.searchRoutes(srcLat: 18.5, srcLng: 73.8, destLat: 18.56, destLng: 73.9);
      expect(routes, isNotEmpty);
      expect(routes.first.departureTimeUsed, startsWith('2026-10-19T08:42'));
      expect(routes.first.warnings, isNotEmpty);
    });

    test('too-far response (routes: [] + message) returns an empty list, not an exception', () async {
      final (repo, _) = _repo((o) => (200, realFixture('routes_empty.json')));
      expect(await repo.searchRoutes(srcLat: 18.5, srcLng: 73.8, destLat: 19.5, destLng: 75.5), isEmpty);
    });

    test('503 becomes ApiUnavailableException (drives the "Waking up Marg…" state)', () async {
      final (repo, _) = _repo((o) => (503, {'detail': 'Routing engine unavailable'}));
      expect(
        () => repo.searchRoutes(srcLat: 18.5, srcLng: 73.8, destLat: 18.56, destLng: 73.9, retryDelay: Duration.zero),
        throwsA(isA<ApiUnavailableException>()),
      );
    });

    test('auto-retries once on 503 and succeeds on second attempt', () async {
      int attempts = 0;
      final (repo, adapter) = _repo((o) {
        attempts++;
        if (attempts == 1) return (503, {'detail': 'Routing engine warming up'});
        return (200, realFixture('routes_search_bus_only.json'));
      });
      final routes = await repo.searchRoutes(
        srcLat: 18.5,
        srcLng: 73.8,
        destLat: 18.56,
        destLng: 73.9,
        retryDelay: Duration.zero,
      );
      expect(attempts, 2);
      expect(routes, isNotEmpty);
      expect(adapter.requests.length, 2);
    });

    test('priority "fastest" keeps the recommended route first', () async {
      final (repo, _) = _repo((o) => (200, realFixture('routes_search_bus_only.json')));
      final routes = await repo.searchRoutes(srcLat: 18.5, srcLng: 73.8, destLat: 18.56, destLng: 73.9);
      expect(routes.first.routeType, anyOf('recommended', 'fastest'));
    });
  });

  group('health', () {
    test('reads the real nested health payload and reports ready', () async {
      final (repo, _) = _repo((o) => (200, realFixture('health.json')));
      expect(await repo.checkHealth(), isTrue);
    });

    test('degraded / routing_available=false is NOT healthy', () async {
      final (repo, _) = _repo((o) => (200, {'status': 'degraded', 'routing_available': false, 'components': {}}));
      expect(await repo.checkHealth(), isFalse);
    });
  });

  group('demo mode', () {
    test('with no API_BASE the repository serves the offline demo data (explicitly)', () async {
      final repo = TransitRepository(client: ApiClient(customBaseUrl: ''));
      expect(await repo.searchGeocode('kothrud'), isNotEmpty);
    });
  });
}
