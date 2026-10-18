import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marg_app/theme/marg_tokens.dart';
import 'package:marg_app/shared/widgets/bus_chip.dart';
import 'package:marg_app/shared/widgets/walk_chip.dart';
import 'package:marg_app/shared/widgets/badge_label.dart';
import 'package:marg_app/shared/widgets/primary_button.dart';
import 'package:marg_app/shared/widgets/segmented_control.dart';
import 'package:marg_app/data/storage_service.dart';
import 'package:marg_app/data/repositories/transit_repository.dart';
import 'package:marg_app/app/app_state.dart';
import 'package:marg_app/main.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: margTheme(Brightness.light),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Shared Widgets Tests', () {
    testWidgets('BusChip renders route number', (tester) async {
      await tester.pumpWidget(_wrap(const BusChip(line: '17')));
      expect(find.text('17'), findsOneWidget);
    });

    testWidgets('WalkChip renders walk duration', (tester) async {
      await tester.pumpWidget(_wrap(const WalkChip(durationMins: 6)));
      expect(find.text('6'), findsOneWidget);
      expect(find.byIcon(Icons.directions_walk), findsOneWidget);
    });

    testWidgets('BadgeLabel renders Fastest badge', (tester) async {
      await tester.pumpWidget(_wrap(const BadgeLabel(type: BadgeType.fastest)));
      expect(find.text('Fastest'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });

    testWidgets('PrimaryButton handles tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          PrimaryButton(
            label: 'Show Routes',
            onPressed: () => tapped = true,
          ),
        ),
      );
      expect(find.text('Show Routes'), findsOneWidget);
      await tester.tap(find.text('Show Routes'));
      expect(tapped, isTrue);
    });

    testWidgets('MargSegmentedControl renders items and triggers callback', (tester) async {
      String selected = 'bus';
      await tester.pumpWidget(
        _wrap(
          MargSegmentedControl<String>(
            items: const [
              SegmentItem(value: 'bus', title: 'Bus'),
              SegmentItem(value: 'metro', title: 'Metro', badge: 'Soon', disabled: true),
            ],
            selectedValue: selected,
            onValueChanged: (val) => selected = val,
          ),
        ),
      );
      expect(find.text('Bus'), findsOneWidget);
      expect(find.text('Metro'), findsOneWidget);
      expect(find.text('Soon'), findsOneWidget);
    });
  });

  group('Data and Repository Tests', () {
    test('TransitRepository fallback stops and search work', () async {
      final repo = TransitRepository();
      final stops = await repo.getNearbyStops(18.5074, 73.8077);
      expect(stops.isNotEmpty, isTrue);
      expect(stops.first.name, 'Kothrud Depot');

      final searchResults = await repo.searchGeocode('Kothrud');
      expect(searchResults.any((p) => p.name.contains('Kothrud')), isTrue);

      final routes = await repo.searchRoutes(
        srcLat: 18.5074,
        srcLng: 73.8077,
        destLat: 18.5679,
        destLng: 73.9143,
        priority: 'fastest',
      );
      expect(routes.length, 3);
      expect(routes.first.totalTimeMins, 55);
      expect(routes.first.legs.length, 4);
    });

    test('StorageService persists recents and settings', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      expect(storage.hasSeenOnboarding, isFalse);
      await storage.setHasSeenOnboarding(true);
      expect(storage.hasSeenOnboarding, isTrue);

      expect(storage.notifyDelays, isTrue);
      await storage.setNotifyDelays(false);
      expect(storage.notifyDelays, isFalse);

      final places = storage.getSavedPlaces();
      expect(places.length, 2);
      expect(places.first.name, 'Home');
    });
  });

  group('App Smoke Test', () {
    testWidgets('App boots with WelcomeScreen on first run', (tester) async {
      SharedPreferences.setMockInitialValues({'has_seen_onboarding': false});
      final storage = await StorageService.init();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
          ],
          child: MargApp(storage: storage),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Pune's buses, planned beautifully."), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  });
}
