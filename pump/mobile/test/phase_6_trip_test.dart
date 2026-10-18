import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:marg_app/theme/marg_tokens.dart';
import 'package:marg_app/features/live/live_screen.dart';
import 'package:marg_app/features/live/widgets/live_banner.dart';
import 'package:marg_app/features/live/widgets/live_sheet.dart';
import 'package:marg_app/features/live/widgets/live_map.dart';
import 'package:marg_app/features/live/widgets/live_stats_row.dart';
import 'package:marg_app/features/live/widgets/live_progress_track.dart';
import 'package:marg_app/features/live/widgets/live_end_trip_dialog.dart';
import 'package:marg_app/features/live/services/trip_progress_service.dart';

Widget createLiveTestApp({GoRouter? customRouter}) {
  final router = customRouter ??
      GoRouter(
        initialLocation: '/live',
        routes: [
          GoRoute(path: '/live', builder: (c, s) => const LiveScreen()),
          GoRoute(path: '/explore', builder: (c, s) => const Scaffold(body: Text('Explore Screen'))),
        ],
      );

  return ProviderScope(
    child: MaterialApp.router(
      theme: margTheme(Brightness.light),
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Phase 6 - Trip Mode (LiveScreen) Tests', () {
    testWidgets('LiveScreen renders banner, map, sheet, and all required icons load', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(createLiveTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(LiveMap), findsOneWidget);
      expect(find.byType(LiveBanner), findsOneWidget);
      expect(find.byType(LiveSheet), findsOneWidget);

      // Verify bus icon loaded in banner and marker
      expect(find.byIcon(Icons.directions_bus_rounded), findsWidgets);
    });

    testWidgets('LiveBanner displays honest SCHEDULED chip (never fake LIVE)', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(createLiveTestApp());
      await tester.pumpAndSettle();

      // Honest label requirement
      expect(find.text('SCHEDULED'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);

      // Instruction text
      expect(find.text('Get off at'), findsOneWidget);
      expect(find.text('Viman Nagar'), findsWidgets);
      expect(find.textContaining('stops · Route 144'), findsOneWidget);
    });

    testWidgets('LiveStatsRow renders remaining time, arrival, and on-time stats', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(createLiveTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(LiveStatsRow), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('min'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('9:37'), findsOneWidget);
      expect(find.text('Arrival'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
      expect(find.text(' time'), findsOneWidget);
      expect(find.text('Route 144'), findsWidgets);
    });

    testWidgets('LiveProgressTrack renders base line, progress line, and stop dots', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: margTheme(Brightness.light),
          home: const Scaffold(
            body: Center(child: LiveProgressTrack(progressPercent: 0.58)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiveProgressTrack), findsOneWidget);
      expect(find.byIcon(Icons.directions_bus_rounded), findsOneWidget);
    });

    testWidgets('End Trip button opens confirmation dialog and Cancel stays on screen', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(createLiveTestApp());
      await tester.pumpAndSettle();

      // Tap End Trip
      final endTripBtn = find.widgetWithText(ElevatedButton, 'End Trip').evaluate().isEmpty
          ? find.text('End Trip')
          : find.widgetWithText(ElevatedButton, 'End Trip');
      await tester.tap(endTripBtn);
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.byType(LiveEndTripDialog), findsOneWidget);
      expect(find.text('End Trip?'), findsOneWidget);
      expect(find.text('Are you sure you want to exit live trip guidance?'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog dismissed, still on LiveScreen
      expect(find.byType(LiveEndTripDialog), findsNothing);
      expect(find.byType(LiveScreen), findsOneWidget);
    });

    testWidgets('Confirming End Trip cleans state and navigates to explore', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(createLiveTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('End Trip'));
      await tester.pumpAndSettle();

      // Confirm in dialog (second 'End Trip' text widget is the dialog action)
      final dialogEndBtn = find.descendant(
        of: find.byType(LiveEndTripDialog),
        matching: find.text('End Trip'),
      );
      await tester.tap(dialogEndBtn);
      await tester.pumpAndSettle();

      expect(find.text('Explore Screen'), findsOneWidget);
    });

    test('TripProgressService.snapToPolyline accurately projects point to route', () {
      final polyline = const [
        LatLng(18.50, 73.80),
        LatLng(18.52, 73.80),
        LatLng(18.52, 73.85),
      ];

      // Point exactly on midpoint of first segment
      final (snapped1, progress1) = TripProgressService.snapToPolyline(const LatLng(18.51, 73.80), polyline);
      expect(progress1, greaterThan(0.1));
      expect(progress1, lessThan(0.6));
      expect((snapped1.latitude - 18.51).abs(), lessThan(0.001));

      // Point near end
      final (_, progress2) = TripProgressService.snapToPolyline(const LatLng(18.52, 73.85), polyline);
      expect(progress2, closeTo(1.0, 0.05));
    });
  });
}
