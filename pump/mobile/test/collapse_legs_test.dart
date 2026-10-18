import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:marg_app/data/models/route_model.dart';
import 'package:marg_app/features/itinerary/models/itinerary_step_data.dart';
import 'package:marg_app/app/app_state.dart';
import 'package:marg_app/data/models/place.dart';
import 'package:marg_app/features/results/widgets/results_map_data.dart';
import 'package:marg_app/theme/marg_tokens.dart';
import 'contract/real_fixture.dart';

void main() {
  group('RouteLeg path and line_options parsing', () {
    test('parses path and line_options from real bus-only fixture', () {
      final payload = realFixture('routes_search_bus_only.json') as Map<String, dynamic>;
      final routes = (payload['routes'] as List)
          .map((r) => TransitRoute.fromJson(r as Map<String, dynamic>))
          .toList();

      expect(routes, isNotEmpty);
      final firstRoute = routes.first;
      expect(firstRoute.legs, isNotEmpty);

      // Check walk leg has path
      final walkLeg = firstRoute.legs.first;
      expect(walkLeg.mode, 'walk');
      expect(walkLeg.path, isNotEmpty);
      expect(walkLeg.path.first, isA<LatLng>());
      expect(walkLeg.path.first.latitude, inInclusiveRange(18.0, 19.0));
      expect(walkLeg.path.first.longitude, inInclusiveRange(73.0, 74.5));

      // Check bus leg has path and line_options
      final busLeg = firstRoute.legs.firstWhere((l) => l.mode == 'bus');
      expect(busLeg.path, isNotEmpty);
      expect(busLeg.lineOptions, isNotEmpty);
      expect(busLeg.lineOptions, contains(busLeg.line));
    });

    test('parses path from real metro fixture', () {
      final payload = realFixture('routes_search_with_metro.json') as Map<String, dynamic>;
      final routes = (payload['routes'] as List)
          .map((r) => TransitRoute.fromJson(r as Map<String, dynamic>))
          .toList();

      final metroLeg = routes.first.legs.firstWhere((l) => l.mode == 'metro');
      expect(metroLeg.path, isNotEmpty);
      expect(metroLeg.line, 'Aqua');
    });

    test('defaults to empty list when path or line_options are missing', () {
      final leg = RouteLeg.fromJson({
        'mode': 'bus',
        'line': '17',
        'from_node': {'name': 'A', 'lat': 18.5, 'lon': 73.8},
        'to_node': {'name': 'B', 'lat': 18.6, 'lon': 73.9},
        'length_m': 1000,
        'duration_mins': 10,
      });

      expect(leg.path, isEmpty);
      expect(leg.lineOptions, isEmpty);
    });
  });

  group('collapseLegs pure function', () {
    test('merges consecutive metro legs with the same line from real fixture', () {
      final payload = realFixture('routes_search_with_metro.json') as Map<String, dynamic>;
      final routes = (payload['routes'] as List)
          .map((r) => TransitRoute.fromJson(r as Map<String, dynamic>))
          .toList();

      final routeWithMetro = routes.first;
      final rawMetroLegs = routeWithMetro.legs.where((l) => l.mode == 'metro').toList();
      expect(rawMetroLegs.length, greaterThan(1)); // 10 individual station hops in real fixture

      final collapsed = collapseLegs(routeWithMetro.legs);
      final collapsedMetroLegs = collapsed.where((l) => l.mode == 'metro').toList();

      // Should be collapsed into 1 Aqua metro leg
      expect(collapsedMetroLegs.length, 1);
      final aquaLeg = collapsedMetroLegs.first;
      expect(aquaLeg.mode, 'metro');
      expect(aquaLeg.line, 'Aqua');

      // Verify sums
      final expectedLength = rawMetroLegs.fold<int>(0, (sum, l) => sum + l.lengthM);
      final expectedDuration = rawMetroLegs.fold<int>(0, (sum, l) => sum + l.durationMins);
      expect(aquaLeg.lengthM, equals(expectedLength));
      expect(aquaLeg.durationMins, equals(expectedDuration));

      // Verify endpoints
      expect(aquaLeg.fromNode.name, rawMetroLegs.first.fromNode.name);
      expect(aquaLeg.toNode.name, rawMetroLegs.last.toNode.name);

      // Verify path was concatenated
      expect(aquaLeg.path.length, greaterThanOrEqualTo(rawMetroLegs.first.path.length));
    });

    test('does NOT merge different bus lines', () {
      final payload = realFixture('routes_search_bus_only.json') as Map<String, dynamic>;
      final routes = (payload['routes'] as List)
          .map((r) => TransitRoute.fromJson(r as Map<String, dynamic>))
          .toList();

      // Route 1 in fixture has multiple different bus transfers: 99, 144A, METRO SHUTTLE 2, 157, etc.
      final multiBusRoute = routes[1];
      final busLegs = multiBusRoute.legs.where((l) => l.mode == 'bus').toList();
      expect(busLegs.length, greaterThan(2));

      final collapsed = collapseLegs(multiBusRoute.legs);
      final collapsedBusLegs = collapsed.where((l) => l.mode == 'bus').toList();

      // Each distinct bus line must remain a distinct leg
      expect(collapsedBusLegs.length, equals(busLegs.length));
      for (int i = 0; i < busLegs.length; i++) {
        expect(collapsedBusLegs[i].line, equals(busLegs[i].line));
      }
    });

    test('merges consecutive legs of the SAME bus line', () {
      const leg1 = RouteLeg(
        mode: 'bus',
        line: '144',
        fromNode: TransitNode(name: 'Stop 1', lat: 18.50, lon: 73.80),
        toNode: TransitNode(name: 'Stop 2', lat: 18.51, lon: 73.81),
        lengthM: 1000,
        durationMins: 5,
        path: [LatLng(18.50, 73.80), LatLng(18.51, 73.81)],
        lineOptions: ['144', '17'],
      );
      const leg2 = RouteLeg(
        mode: 'bus',
        line: '144',
        fromNode: TransitNode(name: 'Stop 2', lat: 18.51, lon: 73.81),
        toNode: TransitNode(name: 'Stop 3', lat: 18.52, lon: 73.82),
        lengthM: 1200,
        durationMins: 6,
        path: [LatLng(18.51, 73.81), LatLng(18.52, 73.82)],
        lineOptions: ['144'],
      );

      final collapsed = collapseLegs([leg1, leg2]);
      expect(collapsed.length, 1);
      expect(collapsed.first.mode, 'bus');
      expect(collapsed.first.line, '144');
      expect(collapsed.first.lengthM, 2200);
      expect(collapsed.first.durationMins, 11);
      expect(collapsed.first.fromNode.name, 'Stop 1');
      expect(collapsed.first.toNode.name, 'Stop 3');
      expect(collapsed.first.path.length, 3); // deduplicated joint point
      expect(collapsed.first.lineOptions, ['144', '17']);
    });

    test('merges consecutive walk legs', () {
      final payload = realFixture('routes_search_bus_only.json') as Map<String, dynamic>;
      final routes = (payload['routes'] as List)
          .map((r) => TransitRoute.fromJson(r as Map<String, dynamic>))
          .toList();

      final firstRoute = routes.first;
      // In firstRoute, legs[4] and legs[5] are both walk
      expect(firstRoute.legs[4].mode, 'walk');
      expect(firstRoute.legs[5].mode, 'walk');

      final collapsed = collapseLegs(firstRoute.legs);
      expect(collapsed.length, firstRoute.legs.length - 1);
      final lastWalk = collapsed.last;
      expect(lastWalk.mode, 'walk');
      expect(lastWalk.lengthM, firstRoute.legs[4].lengthM + firstRoute.legs[5].lengthM);
      expect(lastWalk.durationMins, firstRoute.legs[4].durationMins + firstRoute.legs[5].durationMins);
    });

    test('returns empty list for empty legs', () {
      expect(collapseLegs([]), isEmpty);
    });
  });

  group('Itinerary details and no invented data', () {
    test('shows +N in itinerary step lineSuffix when lineOptions.length > 1', () {
      final route = TransitRoute(
        routeId: 'r_options',
        totalTimeMins: 30,
        transfers: 0,
        totalWalkM: 200,
        routeType: 'fastest',
        legs: const [
          RouteLeg(
            mode: 'bus',
            line: '95',
            fromNode: TransitNode(name: 'Vanaj', lat: 18.5, lon: 73.8),
            toNode: TransitNode(name: 'Deccan', lat: 18.52, lon: 73.84),
            lengthM: 4000,
            durationMins: 20,
            lineOptions: ['95', '79', '103M'],
          ),
        ],
      );

      final steps = ItineraryStepData.buildSteps(
        route: route,
        tripPlan: const TripPlanState(
          departureTime: '8:42 AM',
          from: Place(id: 'f', name: 'Vanaj', displayName: 'Vanaj', lat: 18.5, lng: 73.8),
          to: Place(id: 't', name: 'Deccan', displayName: 'Deccan', lat: 18.52, lng: 73.84),
        ),
      );

      final busStep = steps.firstWhere((s) => s.busLine == '95');
      expect(busStep.lineSuffix, '+2');
    });

    test('no +N when lineOptions.length <= 1', () {
      final route = TransitRoute(
        routeId: 'r_single',
        totalTimeMins: 30,
        transfers: 0,
        totalWalkM: 200,
        routeType: 'fastest',
        legs: const [
          RouteLeg(
            mode: 'bus',
            line: '1030',
            fromNode: TransitNode(name: 'Vanaj', lat: 18.5, lon: 73.8),
            toNode: TransitNode(name: 'Deccan', lat: 18.52, lon: 73.84),
            lengthM: 4000,
            durationMins: 20,
            lineOptions: ['1030'],
          ),
        ],
      );

      final steps = ItineraryStepData.buildSteps(
        route: route,
        tripPlan: const TripPlanState(
          departureTime: '8:42 AM',
          from: Place(id: 'f', name: 'Vanaj', displayName: 'Vanaj', lat: 18.5, lng: 73.8),
          to: Place(id: 't', name: 'Deccan', displayName: 'Deccan', lat: 18.52, lng: 73.84),
        ),
      );

      final busStep = steps.firstWhere((s) => s.busLine == '1030');
      expect(busStep.lineSuffix, isNull);
    });

    test('hides headsign, stops and frequency when null (never invents)', () {
      final route = TransitRoute(
        routeId: 'r_nulls',
        totalTimeMins: 20,
        transfers: 0,
        totalWalkM: 100,
        routeType: 'fastest',
        legs: const [
          RouteLeg(
            mode: 'bus',
            line: '144',
            fromNode: TransitNode(name: 'Swargate', lat: 18.5, lon: 73.8),
            toNode: TransitNode(name: 'Station', lat: 18.52, lon: 73.84),
            lengthM: 3000,
            durationMins: 15,
            headsign: null,
            numStops: null,
            frequencyMins: null,
            intermediateStops: [],
          ),
        ],
      );

      final steps = ItineraryStepData.buildSteps(
        route: route,
        tripPlan: const TripPlanState(
          departureTime: '8:42 AM',
          from: Place(id: 'f', name: 'Swargate', displayName: 'Swargate', lat: 18.5, lng: 73.8),
          to: Place(id: 't', name: 'Station', displayName: 'Station', lat: 18.52, lng: 73.84),
        ),
      );

      final busStep = steps.firstWhere((s) => s.busLine == '144');
      expect(busStep.headsign, isNull);
      expect(busStep.meta, isNot(contains('stops')));
      expect(busStep.meta, isNot(contains('Every')));
      expect(busStep.intermediateStops, isEmpty);
    });
  });

  group('ResultsMapData polylines with path & fallback', () {
    test('uses path coordinates when available', () {
      final route = TransitRoute(
        routeId: 'r_path',
        totalTimeMins: 20,
        transfers: 0,
        totalWalkM: 100,
        routeType: 'fastest',
        legs: const [
          RouteLeg(
            mode: 'bus',
            line: '144',
            fromNode: TransitNode(name: 'A', lat: 18.5, lon: 73.8),
            toNode: TransitNode(name: 'B', lat: 18.6, lon: 73.9),
            lengthM: 3000,
            durationMins: 15,
            path: [
              LatLng(18.51, 73.81),
              LatLng(18.52, 73.82),
              LatLng(18.53, 73.83),
            ],
          ),
        ],
      );

      final polylines = ResultsMapData.buildPolylines(
        route,
        1.0,
        MargColors.light,
        const Place(id: 'f', name: 'A', displayName: 'A', lat: 18.5, lng: 73.8),
        const Place(id: 't', name: 'B', displayName: 'B', lat: 18.6, lng: 73.9),
      );

      expect(polylines, isNotEmpty);
      expect(polylines.any((p) => p.points.length == 3 && p.points[1] == const LatLng(18.52, 73.82)), isTrue);
    });

    test('falls back to fromNode/toNode when path is empty', () {
      final route = TransitRoute(
        routeId: 'r_fallback',
        totalTimeMins: 20,
        transfers: 0,
        totalWalkM: 100,
        routeType: 'fastest',
        legs: const [
          RouteLeg(
            mode: 'bus',
            line: '144',
            fromNode: TransitNode(name: 'A', lat: 18.55, lon: 73.85),
            toNode: TransitNode(name: 'B', lat: 18.65, lon: 73.95),
            lengthM: 3000,
            durationMins: 15,
            path: [],
          ),
        ],
      );

      final polylines = ResultsMapData.buildPolylines(
        route,
        1.0,
        MargColors.light,
        const Place(id: 'f', name: 'A', displayName: 'A', lat: 18.5, lng: 73.8),
        const Place(id: 't', name: 'B', displayName: 'B', lat: 18.6, lng: 73.9),
      );

      expect(polylines, isNotEmpty);
      expect(polylines.any((p) => p.points.first == const LatLng(18.55, 73.85)), isTrue);
    });
  });
}
