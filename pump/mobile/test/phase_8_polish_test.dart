import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:marg_app/theme/marg_tokens.dart';
import 'package:marg_app/data/models/place.dart';
import 'package:marg_app/data/models/route_model.dart';
import 'package:marg_app/data/models/stop.dart';
import 'package:marg_app/features/results/widgets/results_map_data.dart';
import 'package:marg_app/features/results/widgets/route_card.dart';
import 'package:marg_app/features/plan/widgets/od_input_card.dart';
import 'package:marg_app/features/plan/widgets/leave_time_row.dart';
import 'package:marg_app/features/plan/widgets/priority_chips.dart';
import 'package:marg_app/features/explore/widgets/explore_shortcuts.dart';
import 'package:marg_app/features/explore/widgets/nearby_stop_tile.dart';
import 'package:marg_app/features/itinerary/widgets/itinerary_top_bar.dart';
import 'package:marg_app/features/itinerary/widgets/itinerary_timeline_step.dart';
import 'package:marg_app/features/itinerary/widgets/itinerary_cta_bar.dart';
import 'package:marg_app/features/itinerary/models/itinerary_step_data.dart';
import 'package:marg_app/shared/widgets/glass_tab_bar.dart';

void main() {
  const dummyFrom = Place(
    id: 'p_from',
    name: 'Kothrud Depot',
    displayName: 'Kothrud, Pune',
    lat: 18.5074,
    lng: 73.8077,
    type: 'stop',
  );

  const dummyTo = Place(
    id: 'p_to',
    name: 'Viman Nagar',
    displayName: 'Viman Nagar, Pune',
    lat: 18.5679,
    lng: 73.9143,
    type: 'poi',
  );

  const nodeA = TransitNode(name: 'Origin', lat: 18.5074, lon: 73.8077);
  const nodeB = TransitNode(name: 'Kothrud Stand', lat: 18.5098, lon: 73.8180);
  const nodeC = TransitNode(name: 'Viman Nagar', lat: 18.5670, lon: 73.9130);
  const nodeD = TransitNode(name: 'Destination', lat: 18.5679, lon: 73.9143);

  final dummyRoute = TransitRoute(
    routeId: 'r_direct',
    routeType: 'fastest',
    totalTimeMins: 45,
    transfers: 0,
    totalWalkM: 250,
    departureTimeUsed: 'Now · 8:42 AM',
    nextBusMins: 6,
    legs: const [
      RouteLeg(
        mode: 'walk',
        durationMins: 4,
        lengthM: 250,
        fromNode: nodeA,
        toNode: nodeB,
      ),
      RouteLeg(
        mode: 'bus',
        line: '148',
        durationMins: 38,
        lengthM: 12000,
        fromNode: nodeB,
        toNode: nodeC,
      ),
      RouteLeg(
        mode: 'walk',
        durationMins: 3,
        lengthM: 100,
        fromNode: nodeC,
        toNode: nodeD,
      ),
    ],
  );

  group('Phase 8 - Blur Fallback & Performance Tests', () {
    testWidgets('Glass respects forceDisableBlur flag and disables BackdropFilter', (tester) async {
      Glass.forceDisableBlur = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Glass(child: const Text('Blur active')),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);

      Glass.forceDisableBlur = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Glass(child: const Text('Blur disabled')),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      Glass.forceDisableBlur = false; // Reset
    });

    testWidgets('Glass disables BackdropFilter when MediaQuery disableAnimations is true', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: Glass(child: const Text('Reduced motion')),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('Phase 8 - Polyline Trim & Reserved Metro Styling Tests', () {
    test('trimPoints interpolates coordinates along segments', () {
      final points = [
        const LatLng(10.0, 10.0),
        const LatLng(20.0, 20.0),
        const LatLng(30.0, 30.0),
      ];

      final trimmed0 = ResultsMapData.trimPoints(points, 0.0);
      expect(trimmed0.isEmpty, isTrue);

      final trimmed1 = ResultsMapData.trimPoints(points, 1.0);
      expect(trimmed1.length, equals(3));
      expect(trimmed1.last, equals(const LatLng(30.0, 30.0)));

      final trimmedHalf = ResultsMapData.trimPoints(points, 0.5);
      expect(trimmedHalf.length, equals(2));
      expect(trimmedHalf.last.latitude, closeTo(20.0, 0.01));
    });

    test('buildPolylines colors metro legs with MargColors purple', () {
      final metroRoute = TransitRoute(
        routeId: 'r_metro',
        routeType: 'fastest',
        totalTimeMins: 30,
        transfers: 0,
        totalWalkM: 100,
        departureTimeUsed: '8:42 AM',
        legs: const [
          RouteLeg(
            mode: 'metro',
            line: 'Purple Line',
            durationMins: 20,
            lengthM: 8000,
            fromNode: nodeB,
            toNode: nodeC,
          ),
        ],
      );

      final polylines = ResultsMapData.buildPolylines(
        metroRoute,
        1.0,
        MargColors.light,
        dummyFrom,
        dummyTo,
      );

      final hasMetroPurple = polylines.any((p) => p.color == MargColors.light.purple);
      expect(hasMetroPurple, isTrue);
    });
  });

  group('Phase 8 - TalkBack Semantics Pass Tests', () {
    testWidgets('Explore shortcuts and tab bar include Semantics labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: GlassTabBar(
              currentTab: MargTab.explore,
              onTabSelected: (_) {},
            ),
            body: ExploreShortcuts(
              onHomeTap: () {},
              onWorkTap: () {},
              onAddTap: () {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel(RegExp(r'Home shortcut')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Work shortcut')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Explore tab')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Saved tab')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Alerts tab')), findsOneWidget);
    });

    testWidgets('NearbyStopTile includes accessible stop and lines summary', (tester) async {
      const stop = TransitStop(
        id: 's_kothrud',
        name: 'Kothrud Stand',
        lat: 18.5074,
        lng: 73.8077,
        distanceMeters: 120,
        etas: [StopEta(route: '148', mins: 4)],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NearbyStopTile(stop: stop),
          ),
        ),
      );

      expect(find.bySemanticsLabel(RegExp(r'Kothrud Stand')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'148')), findsOneWidget);
    });

    testWidgets('Plan screen widgets contain descriptive accessibility labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OdInputCard(
                  from: dummyFrom,
                  to: dummyTo,
                  onFromTap: () {},
                  onToTap: () {},
                  onSwap: () {},
                ),
                LeaveTimeRow(
                  departureTime: 'Now · 8:42 AM',
                  onTimeChanged: (_) {},
                ),
                PriorityChips(
                  selectedPriority: 'fastest',
                  onPriorityChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel(RegExp(r'Origin: Kothrud Depot')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Destination: Viman Nagar')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Swap origin and destination')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Departure time')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Fastest priority')), findsOneWidget);
    });

    testWidgets('RouteCard provides accessible summary with arrival and transfer details', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteCard(
              route: dummyRoute,
              isSelected: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel(RegExp(r'Route option, 45 minutes')), findsOneWidget);
    });

    testWidgets('Itinerary components provide button semantics and intermediate stop expand labels', (tester) async {
      final step = ItineraryStepData(
        time: '8:42 AM',
        title: 'Board Bus 148',
        busLine: '148',
        intermediateStops: const ['Stop 1', 'Stop 2', 'Stop 3'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ItineraryTopBar(
                  onBack: () {},
                  onShare: () {},
                ),
                ItineraryTimelineStep(
                  step: step,
                  isExpanded: false,
                  onToggleExpand: () {},
                ),
                ItineraryCtaBar(
                  onStartTrip: () {},
                  onToggleSave: () {},
                  isSaved: true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel(RegExp(r'Back to results')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Share itinerary')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Show.*intermediate stops')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Route saved')), findsOneWidget);
    });
  });

  group('Phase 8 - Font Scaling Resilience Tests (0.85x and 1.3x)', () {
    Widget buildScaledApp(double scale) {
      return MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  OdInputCard(
                    from: dummyFrom,
                    to: dummyTo,
                    onFromTap: () {},
                    onToTap: () {},
                    onSwap: () {},
                  ),
                  RouteCard(
                    route: dummyRoute,
                    isSelected: false,
                    onTap: () {},
                  ),
                  ItineraryCtaBar(
                    onStartTrip: () {},
                    onToggleSave: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders properly without overflow at 1.3x text scale', (tester) async {
      await tester.pumpWidget(buildScaledApp(1.3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders properly without overflow at 0.85x text scale', (tester) async {
      await tester.pumpWidget(buildScaledApp(0.85));
      expect(tester.takeException(), isNull);
    });
  });
}
