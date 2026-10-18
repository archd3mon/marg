import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marg_app/theme/marg_tokens.dart';
import 'package:marg_app/data/storage_service.dart';
import 'package:marg_app/app/app_state.dart';
import 'package:marg_app/features/saved/saved_screen.dart';
import 'package:marg_app/features/saved/widgets/edit_place_sheet.dart';
import 'package:marg_app/features/alerts/alerts_screen.dart';
import 'package:marg_app/features/alerts/widgets/toggle_row.dart';

Widget createTestApp({
  required StorageService storage,
  required Widget child,
  GoRouter? router,
}) {
  if (router != null) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
      child: MaterialApp.router(
        theme: margTheme(Brightness.light),
        routerConfig: router,
      ),
    );
  }

  return ProviderScope(
    overrides: [
      storageServiceProvider.overrideWithValue(storage),
    ],
    child: MaterialApp(
      theme: margTheme(Brightness.light),
      home: child,
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

  group('Phase 7 - Saved Screen Tests', () {
    testWidgets('SavedScreen renders title, Home/Work cards, ROUTES header and routes', (tester) async {
      setPhoneSize(tester);
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      await tester.pumpWidget(createTestApp(
        storage: storage,
        child: const SavedScreen(),
      ));
      await tester.pumpAndSettle();

      // Title & section header
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('ROUTES'), findsOneWidget);

      // Home & Work place cards
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Kothrud'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Viman Nagar'), findsOneWidget);

      // Saved routes & details
      expect(find.text('Home → Work'), findsOneWidget);
      expect(find.text('55'), findsOneWidget);
      expect(find.text('On time'), findsOneWidget);
      expect(find.text('Home → Deccan'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);

      // Bus line chips
      expect(find.text('17'), findsWidgets);
      expect(find.text('144'), findsOneWidget);

      // Footnote
      expect(find.text('Saved routes check live conditions and alert you before you leave.'), findsOneWidget);
    });

    testWidgets('Tapping edit on a place card opens EditPlaceSheet and persists changes', (tester) async {
      setPhoneSize(tester);
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      await tester.pumpWidget(createTestApp(
        storage: storage,
        child: const SavedScreen(),
      ));
      await tester.pumpAndSettle();

      // Long press on Home card to open EditPlaceSheet
      await tester.longPress(find.text('Home'));
      await tester.pumpAndSettle();

      // EditPlaceSheet appears
      expect(find.byType(EditPlaceSheet), findsOneWidget);
      expect(find.text('Edit Home'), findsOneWidget);

      // Select Deccan chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Deccan'));
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Save Place'));
      await tester.pumpAndSettle();

      // Sheet dismissed and location updated
      expect(find.byType(EditPlaceSheet), findsNothing);
      expect(find.text('Deccan'), findsWidgets);

      // Verify persistence in storage
      final places = storage.getSavedPlaces();
      final home = places.firstWhere((p) => p.type == 'home');
      expect(home.locationName, 'Deccan');
    });

    testWidgets('Tapping a saved route re-runs search by navigating to /results', (tester) async {
      setPhoneSize(tester);
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      final router = GoRouter(
        initialLocation: '/saved',
        routes: [
          GoRoute(path: '/saved', builder: (c, s) => const SavedScreen()),
          GoRoute(path: '/results', builder: (c, s) => const Scaffold(body: Text('Results Screen'))),
        ],
      );

      await tester.pumpWidget(createTestApp(
        storage: storage,
        child: const SizedBox.shrink(),
        router: router,
      ));
      await tester.pumpAndSettle();

      // Tap Home → Work route
      await tester.tap(find.text('Home → Work'));
      await tester.pumpAndSettle();

      expect(find.text('Results Screen'), findsOneWidget);
    });

    testWidgets('Swipe-to-delete removes saved route and persists to storage', (tester) async {
      setPhoneSize(tester);
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      await tester.pumpWidget(createTestApp(
        storage: storage,
        child: const SavedScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Home → Work'), findsOneWidget);

      // Dismiss the first route
      final dismissible = find.byKey(const ValueKey('sr1'));
      expect(dismissible, findsOneWidget);

      await tester.drag(dismissible, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Route removed
      expect(find.text('Home → Work'), findsNothing);
      expect(find.text('Home → Deccan'), findsOneWidget);

      // Storage updated
      final routes = storage.getSavedRoutes();
      expect(routes.any((r) => r.id == 'sr1'), isFalse);
    });
  });

  group('Phase 7 - Alerts Screen Tests', () {
    testWidgets('AlertsScreen renders title, segmented control, NOTIFY ME header and toggles', (tester) async {
      setPhoneSize(tester);
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      await tester.pumpWidget(createTestApp(
        storage: storage,
        child: const AlertsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('My Routes'), findsOneWidget);
      expect(find.text('All Service'), findsOneWidget);
      expect(find.text('NOTIFY ME'), findsOneWidget);

      // Notification toggles
      expect(find.text('Delays on saved routes'), findsOneWidget);
      expect(find.text('Leave-now reminders'), findsOneWidget);
      expect(find.text('Service changes'), findsOneWidget);
    });

    testWidgets('kDemoAlerts flag defaults to false and only local reminders are shown', (tester) async {
      setPhoneSize(tester);
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      expect(storage.demoAlertsEnabled, isFalse);

      await tester.pumpWidget(createTestApp(
        storage: storage,
        child: const AlertsScreen(),
      ));
      await tester.pumpAndSettle();

      // Only local reminder 'Your commute' shown by default
      expect(find.text('Your commute'), findsOneWidget);
      expect(find.text('Leave by 8:35 to reach Viman Nagar by 9:30.'), findsOneWidget);

      // Sample notices are hidden when flag is off
      expect(find.text('Route 144 · Delay'), findsNothing);
      expect(find.text('Route 17 · Diversion'), findsNothing);
    });

    testWidgets('Enabling kDemoAlerts shows sample notices clearly labelled "Sample"', (tester) async {
      setPhoneSize(tester);
      SharedPreferences.setMockInitialValues({'demo_alerts_enabled': true});
      final storage = await StorageService.init();

      await tester.pumpWidget(createTestApp(
        storage: storage,
        child: const AlertsScreen(),
      ));
      await tester.pumpAndSettle();

      // Sample notices appear
      expect(find.text('Route 144 · Delay'), findsOneWidget);
      expect(find.text('Route 17 · Diversion'), findsOneWidget);
      expect(find.text('Your commute'), findsOneWidget);

      // Sample label is displayed on sample notices
      expect(find.text('Sample'), findsWidgets);
    });

    testWidgets('Toggling notification settings updates state and persists across restarts', (tester) async {
      setPhoneSize(tester);
      final mockMap = <String, Object>{};
      SharedPreferences.setMockInitialValues(mockMap);
      var storage = await StorageService.init();

      expect(storage.notifyServiceChanges, isFalse);

      await tester.pumpWidget(createTestApp(
        storage: storage,
        child: const AlertsScreen(),
      ));
      await tester.pumpAndSettle();

      // Toggle 'Service changes' switch
      final serviceSwitch = find.descendant(
        of: find.widgetWithText(ToggleRow, 'Service changes'),
        matching: find.byType(Switch),
      );
      expect(serviceSwitch, findsOneWidget);

      await tester.tap(serviceSwitch);
      await tester.pumpAndSettle();

      expect(storage.notifyServiceChanges, isTrue);

      // Re-initialize storage to verify restart persistence
      final restartedStorage = await StorageService.init();
      expect(restartedStorage.notifyServiceChanges, isTrue);
    });
  });
}
