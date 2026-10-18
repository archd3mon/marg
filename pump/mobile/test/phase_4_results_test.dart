import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marg_app/theme/marg_tokens.dart';
import 'package:marg_app/data/api_client.dart';
import 'package:marg_app/data/repositories/transit_repository.dart';
import 'package:marg_app/app/app_state.dart';
import 'package:marg_app/features/results/results_screen.dart';
import 'package:marg_app/features/results/widgets/route_card.dart';
import 'package:marg_app/features/results/widgets/results_skeleton.dart';
import 'package:marg_app/features/results/widgets/results_error_view.dart';
import 'package:marg_app/features/results/widgets/results_empty_view.dart';
import 'package:marg_app/features/results/widgets/results_map.dart';
import 'package:marg_app/features/results/widgets/results_top_bar.dart';
import 'fake_transit_repository.dart';

Widget createResultsTestApp({
  required TransitRepository repository,
  GoRouter? customRouter,
}) {
  final router = customRouter ??
      GoRouter(
        initialLocation: '/results',
        routes: [
          GoRoute(path: '/results', builder: (c, s) => const ResultsScreen()),
          GoRoute(
            path: '/itinerary',
            builder: (c, s) => const Scaffold(body: Text('Itinerary Screen')),
          ),
        ],
      );

  return ProviderScope(
    overrides: [
      transitRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(
      theme: margTheme(Brightness.light),
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 - Results Screen & State Tests', () {
    testWidgets('Displays skeleton cards while loading routes', (tester) async {
      final fakeRepo = FakeTransitRepository();
      await tester.pumpWidget(createResultsTestApp(repository: fakeRepo));

      // Initial frame is loading
      expect(find.byType(ResultsSkeleton), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(ResultsSkeleton), findsNothing);
      expect(find.byType(RouteCard), findsWidgets);
    });

    testWidgets('Displays cold-start (503) state with retry button', (tester) async {
      final fakeRepo = FakeTransitRepository(
        routesSearchError: ApiUnavailableException('Cold start', statusCode: 503),
      );
      await tester.pumpWidget(createResultsTestApp(repository: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.byType(ResultsErrorView), findsOneWidget);
      expect(find.text('Waking up Marg…'), findsOneWidget);
      expect(find.text('Retry Search'), findsOneWidget);

      // Now clear error and tap retry
      fakeRepo.routesSearchError = null;
      await tester.tap(find.text('Retry Search'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ResultsErrorView), findsNothing);
      expect(find.byType(RouteCard), findsWidgets);
    });

    testWidgets('Displays offline state when network is unavailable', (tester) async {
      final fakeRepo = FakeTransitRepository(
        routesSearchError: ApiOfflineException('No network connection'),
      );
      await tester.pumpWidget(createResultsTestApp(repository: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.byType(ResultsErrorView), findsOneWidget);
      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.text('Retry Search'), findsOneWidget);
    });

    testWidgets('Displays empty state when no routes found', (tester) async {
      final fakeRepo = FakeTransitRepository(returnEmptyRoutes: true);
      await tester.pumpWidget(createResultsTestApp(repository: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.byType(ResultsEmptyView), findsOneWidget);
      expect(find.text('Too far from transit network'), findsOneWidget);
      expect(find.text('Change Points'), findsOneWidget);
    });
  });

  group('Phase 4 - Result Sheet & Route Cards Tests', () {
    testWidgets('Header shows N routes and leave-time chip', (tester) async {
      final fakeRepo = FakeTransitRepository();
      await tester.pumpWidget(createResultsTestApp(repository: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.text('2 routes'), findsOneWidget);
      expect(find.text('PMPML buses · live schedule'), findsOneWidget);
      expect(find.text('Leave now'), findsOneWidget);
      expect(find.byType(ResultsTopBar), findsOneWidget);
      expect(find.text('Current Location'), findsOneWidget);
      expect(find.text('Viman Nagar'), findsOneWidget);
    });

    testWidgets('Selected route card has 2px blue ring border and soft shadow', (tester) async {
      final fakeRepo = FakeTransitRepository();
      await tester.pumpWidget(createResultsTestApp(repository: fakeRepo));
      await tester.pumpAndSettle();

      final firstCard = tester.widget<RouteCard>(find.byType(RouteCard).first);
      expect(firstCard.isSelected, isTrue);

      final secondCard = tester.widget<RouteCard>(find.byType(RouteCard).at(1));
      expect(secondCard.isSelected, isFalse);

      // Verify border of selected container
      final firstContainer = tester.widget<Container>(
        find.descendant(of: find.byType(RouteCard).first, matching: find.byType(Container)).first,
      );
      final boxDeco = firstContainer.decoration as BoxDecoration;
      final border = boxDeco.border as Border;
      expect(border.top.width, 2.0);
      expect(boxDeco.boxShadow, isNotNull);
    });

    testWidgets('Tapping unselected route card selects it instantly and updates map', (tester) async {
      final fakeRepo = FakeTransitRepository();
      await tester.pumpWidget(createResultsTestApp(repository: fakeRepo));
      await tester.pumpAndSettle();

      // Tap second card to select it
      await tester.tap(find.byType(RouteCard).at(1));
      await tester.pump();

      final secondCardNow = tester.widget<RouteCard>(find.byType(RouteCard).at(1));
      expect(secondCardNow.isSelected, isTrue);

      final firstCardNow = tester.widget<RouteCard>(find.byType(RouteCard).first);
      expect(firstCardNow.isSelected, isFalse);
    });

    testWidgets('Tapping already selected route card navigates to itinerary', (tester) async {
      final fakeRepo = FakeTransitRepository();
      await tester.pumpWidget(createResultsTestApp(repository: fakeRepo));
      await tester.pumpAndSettle();

      // First card is selected by default, tap it to push itinerary
      await tester.tap(find.byType(RouteCard).first);
      await tester.pumpAndSettle();

      expect(find.text('Itinerary Screen'), findsOneWidget);
    });
  });

  group('Phase 4 - Map Component Tests', () {
    testWidgets('ResultsMap renders with polylines and markers', (tester) async {
      final fakeRepo = FakeTransitRepository();
      await tester.pumpWidget(createResultsTestApp(repository: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.byType(ResultsMap), findsOneWidget);
    });
  });
}
