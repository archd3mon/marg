import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marg_app/theme/marg_tokens.dart';
import 'package:marg_app/data/storage_service.dart';
import 'package:marg_app/app/app_state.dart';
import 'package:marg_app/shared/widgets/bus_chip.dart';
import 'package:marg_app/shared/widgets/badge_label.dart';
import 'package:marg_app/shared/widgets/primary_button.dart';
import 'package:marg_app/features/itinerary/itinerary_screen.dart';
import 'package:marg_app/features/itinerary/widgets/itinerary_timeline_step.dart';
import 'package:marg_app/features/itinerary/widgets/itinerary_header.dart';
import 'package:marg_app/features/itinerary/widgets/itinerary_top_bar.dart';
import 'package:marg_app/features/itinerary/widgets/itinerary_map.dart';
import 'package:marg_app/features/itinerary/widgets/itinerary_timeline_rail.dart';

Widget createItineraryTestApp({
  GoRouter? customRouter,
  StorageService? storageService,
}) {
  final router = customRouter ??
      GoRouter(
        initialLocation: '/itinerary',
        routes: [
          GoRoute(path: '/itinerary', builder: (c, s) => const ItineraryScreen()),
          GoRoute(path: '/live', builder: (c, s) => const Scaffold(body: Text('Live Screen'))),
        ],
      );

  return ProviderScope(
    overrides: [
      if (storageService != null)
        storageServiceProvider.overrideWithValue(storageService),
    ],
    child: MaterialApp.router(
      theme: margTheme(Brightness.light),
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Phase 5 - Itinerary Screen & Timeline Tests', () {
    testWidgets('Renders map, header, timeline steps and CTA buttons', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(createItineraryTestApp(storageService: storageService));
      await tester.pumpAndSettle();

      // Map and Top bar
      expect(find.byType(ItineraryMap), findsOneWidget);
      expect(find.byType(ItineraryTopBar), findsOneWidget);
      expect(find.byType(ItineraryHeader), findsOneWidget);

      // Header content
      expect(find.text('55 min'), findsOneWidget);
      expect(find.textContaining('Arrive 9:37 AM'), findsOneWidget);
      expect(find.byType(BadgeLabel), findsOneWidget);
      expect(find.text('Fastest'), findsOneWidget);

      // Timeline Steps
      expect(find.text('Current Location'), findsOneWidget);
      expect(find.text('Walk 6 min · 450 m'), findsOneWidget);
      expect(find.text('Kothrud Depot'), findsOneWidget);
      expect(find.text('towards Deccan Gymkhana'), findsOneWidget);
      expect(find.text('Deccan Gymkhana'), findsOneWidget);
      expect(find.text('towards Viman Nagar'), findsOneWidget);
      expect(find.text('Viman Nagar Bus Stop'), findsOneWidget);
      expect(find.text('Viman Nagar'), findsWidgets);

      // Bus chips
      expect(find.widgetWithText(BusChip, '17'), findsOneWidget);
      expect(find.widgetWithText(BusChip, '144'), findsOneWidget);

      // CTAs
      expect(find.widgetWithText(PrimaryButton, 'Start Trip'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('Expandable intermediate stops animate on tap', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(createItineraryTestApp(storageService: storageService));
      await tester.pumpAndSettle();

      // Intermediate stops initially not visible
      expect(find.text('Paud Phata'), findsNothing);
      expect(find.text('Nal Stop'), findsNothing);

      // Find "Show stops" buttons
      final showStopsFinders = find.text('Show stops');
      expect(showStopsFinders, findsWidgets);

      // Tap first "Show stops"
      await tester.tap(showStopsFinders.first);
      await tester.pump();
      await tester.pumpAndSettle();

      // Intermediate stops are now revealed
      expect(find.text('Paud Phata'), findsOneWidget);
      expect(find.text('Nal Stop'), findsOneWidget);
      expect(find.text('Garware College'), findsOneWidget);
      expect(find.text('Hide stops'), findsOneWidget);

      // Tap "Hide stops" to collapse
      await tester.tap(find.text('Hide stops'));
      await tester.pumpAndSettle();

      expect(find.text('Paud Phata'), findsNothing);
      expect(find.text('Hide stops'), findsNothing);
    });

    testWidgets('Tapping Start Trip navigates to Live Trip screen', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(createItineraryTestApp(storageService: storageService));
      await tester.pumpAndSettle();

      final startTripFinder = find.widgetWithText(PrimaryButton, 'Start Trip');
      expect(startTripFinder, findsOneWidget);

      await tester.tap(startTripFinder);
      await tester.pumpAndSettle();

      expect(find.text('Live Screen'), findsOneWidget);
    });

    testWidgets('Tapping Bookmark button toggles saved route state and shows feedback', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(createItineraryTestApp(storageService: storageService));
      await tester.pumpAndSettle();

      final bookmarkFinder = find.byIcon(Icons.bookmark_border);
      expect(bookmarkFinder, findsOneWidget);

      // Tap save
      await tester.tap(bookmarkFinder);
      await tester.pumpAndSettle();

      // Bookmark is now active
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.text('Route saved to Saved tab'), findsOneWidget);
    });

    testWidgets('Timeline rails render dotted walk, solid bus, and destination node', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(createItineraryTestApp(storageService: storageService));
      await tester.pumpAndSettle();

      final steps = find.byType(ItineraryTimelineStep);
      expect(steps, findsNWidgets(5));

      // Destination step has step.isDestination = true
      final destStepFinder = find.byWidgetPredicate(
        (w) => w is ItineraryTimelineStep && w.step.isDestination,
      );
      expect(destStepFinder, findsOneWidget);

      // Walk step has step.isWalk = true
      final walkStepFinder = find.byWidgetPredicate(
        (w) => w is ItineraryTimelineStep && w.step.isWalk,
      );
      expect(walkStepFinder, findsWidgets);

      // Check TimelineRailPainter existence
      final customPaints = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TimelineRailPainter,
      );
      expect(customPaints, findsNWidgets(5));
    });

    testWidgets('Top bar share and back buttons operate cleanly', (tester) async {
      setPhoneSize(tester);
      final customRouter = GoRouter(
        initialLocation: '/results',
        routes: [
          GoRoute(
            path: '/results',
            builder: (c, s) => Scaffold(
              body: ElevatedButton(
                onPressed: () => c.push('/itinerary'),
                child: const Text('Go'),
              ),
            ),
          ),
          GoRoute(path: '/itinerary', builder: (c, s) => const ItineraryScreen()),
        ],
      );

      await tester.pumpWidget(createItineraryTestApp(
        customRouter: customRouter,
        storageService: storageService,
      ));
      await tester.pumpAndSettle();

      // Go to itinerary
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.byType(ItineraryScreen), findsOneWidget);

      // Tap share button (must not crash)
      final shareFinder = find.byIcon(Icons.share_rounded);
      expect(shareFinder, findsOneWidget);
      await tester.tap(shareFinder);
      await tester.pumpAndSettle();

      // Tap back button
      final backFinder = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backFinder, findsOneWidget);
      await tester.tap(backFinder);
      await tester.pumpAndSettle();

      expect(find.text('Go'), findsOneWidget);
    });
  });
}
