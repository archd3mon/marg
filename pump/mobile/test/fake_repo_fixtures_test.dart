import 'package:flutter_test/flutter_test.dart';
import 'package:marg_app/data/api_client.dart' as api;
import 'fake_transit_repository.dart';


void main() {
  group('Fake Transit Repository & Fixtures Parsing Tests', () {
    late FakeTransitRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeTransitRepository();
    });

    test('parses health.json fixture correctly', () async {
      final health = await fakeRepo.getHealth();
      expect(health['status'], 'ok');
      expect(health['graph'], 'ready');
      expect(health['ml'], 'ready');
      expect(health['search'], 'ready');
    });

    test('parses stops.json fixture and filters bus stops', () async {
      final stops = await fakeRepo.getNearbyStops(18.5074, 73.8077);
      expect(stops.isNotEmpty, isTrue);
      // Ensure all returned stops are buses and metro is filtered out in v1
      for (final stop in stops) {
        expect(stop.type, 'bus');
      }
      final kothrud = stops.firstWhere((s) => s.name == 'Kothrud Depot');
      expect(kothrud.etas.length, 2);
      expect(kothrud.etas.first.route, '17');
      expect(kothrud.etas.first.mins, 4);
    });

    test('parses geocode_search.json fixture with queries', () async {
      final allPlaces = await fakeRepo.searchGeocode('');
      expect(allPlaces.length, 4);

      final kothrudResults = await fakeRepo.searchGeocode('kothrud');
      expect(kothrudResults.length, 2);
      expect(kothrudResults.every((p) => p.name.contains('Kothrud')), isTrue);
    });

    test('parses routes_search.json fixture with routes, legs, nodes and warnings', () async {
      final routes = await fakeRepo.searchRoutes(
        srcLat: 18.5074,
        srcLng: 73.8077,
        destLat: 18.5679,
        destLng: 73.9143,
      );

      expect(routes.length, 2);

      final fastest = routes.first;
      expect(fastest.routeId, 'route_pmpml_17_144');
      expect(fastest.totalTimeMins, 55);
      expect(fastest.transfers, 1);
      expect(fastest.legs.length, 4);

      // Verify walk leg
      final walkLeg = fastest.legs[0];
      expect(walkLeg.mode, 'walk');
      expect(walkLeg.fromNode.name, 'Current Location');
      expect(walkLeg.toNode.name, 'Kothrud Depot');

      // Verify bus leg
      final busLeg = fastest.legs[1];
      expect(busLeg.mode, 'bus');
      expect(busLeg.line, '17');
      expect(busLeg.headsign, 'Hadapsar Gadital');
      expect(busLeg.intermediateStops, contains('Karve Statue'));
      expect(busLeg.intermediateStops, contains('Deccan Gymkhana'));
    });

    test('ApiClient typed errors Offline, Unavailable503, and Timeout are defined', () {
      final offline = api.Offline('offline');
      expect(offline, isA<api.ApiOfflineException>());

      final unavail = api.Unavailable503('service unavailable', statusCode: 503);
      expect(unavail, isA<api.ApiUnavailableException>());

      final timeout = api.Timeout('timeout');
      expect(timeout, isA<api.ApiTimeoutException>());
    });
  });
}

