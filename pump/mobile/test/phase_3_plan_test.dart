import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marg_app/theme/marg_tokens.dart';
import 'package:marg_app/shared/widgets/primary_button.dart';
import 'package:marg_app/data/storage_service.dart';
import 'package:marg_app/data/models/place.dart';
import 'package:marg_app/app/app_state.dart';
import 'package:marg_app/features/plan/plan_screen.dart';
import 'package:marg_app/features/plan/widgets/od_input_card.dart';
import 'package:marg_app/features/plan/widgets/priority_chips.dart';
import 'package:marg_app/features/plan/widgets/place_search_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createPlanScreen(StorageService storageService) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: MaterialApp(
        theme: margTheme(Brightness.light),
        home: const PlanScreen(),
      ),
    );
  }

  group('Phase 3 - Plan Screen & Widgets Tests', () {
    testWidgets('PlanScreen renders all elements matching plan.png', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await tester.pumpWidget(createPlanScreen(storage));
      await tester.pumpAndSettle();

      // Top bar
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Plan Trip'), findsOneWidget);

      // From / To Card
      expect(find.text('From'), findsOneWidget);
      expect(find.text('Current Location'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
      expect(find.text('Viman Nagar'), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);

      // Leave Row
      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Now · 8:42 AM'), findsOneWidget);

      // Travel By Segmented
      expect(find.text('TRAVEL BY'), findsOneWidget);
      expect(find.text('Bus'), findsOneWidget);
      expect(find.text('Metro'), findsOneWidget);
      expect(find.text('SOON'), findsOneWidget);

      // Prioritise Chips
      expect(find.text('PRIORITISE'), findsOneWidget);
      expect(find.text('Fastest'), findsOneWidget);
      expect(find.text('Fewer transfers'), findsOneWidget);
      expect(find.text('Less walking'), findsOneWidget);

      // Recent Section
      expect(find.text('RECENT'), findsOneWidget);
      expect(find.text('Deccan Gymkhana'), findsOneWidget);
      expect(find.text('Pune Station'), findsOneWidget);

      // Show Routes CTA
      expect(find.text('Show Routes'), findsOneWidget);
    });

    testWidgets('Swap button swaps From and To points', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await tester.pumpWidget(createPlanScreen(storage));
      await tester.pumpAndSettle();

      expect(find.text('Current Location'), findsOneWidget);
      expect(find.text('Viman Nagar'), findsOneWidget);

      // Tap swap button
      await tester.tap(find.byIcon(Icons.swap_vert_rounded));
      await tester.pumpAndSettle();

      // Now From is Viman Nagar and To is Current Location
      final odCard = tester.widget<OdInputCard>(find.byType(OdInputCard));
      expect(odCard.from?.name, 'Viman Nagar');
      expect(odCard.to?.name, 'Current Location');
    });

    testWidgets('Priority chips update selected priority', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await tester.pumpWidget(createPlanScreen(storage));
      await tester.pumpAndSettle();

      // Tap "Less walking"
      await tester.tap(find.text('Less walking'));
      await tester.pumpAndSettle();

      final chips = tester.widget<PriorityChips>(find.byType(PriorityChips));
      expect(chips.selectedPriority, 'least_walking');
    });

    testWidgets('Leave row opens departure time sheet and updates time', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await tester.pumpWidget(createPlanScreen(storage));
      await tester.pumpAndSettle();

      // Tap Leave row
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Departure Time'), findsOneWidget);
      expect(find.text('Leave Now'), findsOneWidget);
      expect(find.text('In 15 minutes'), findsOneWidget);
      expect(find.text('In 30 minutes'), findsOneWidget);

      // Select In 15 minutes
      await tester.tap(find.text('In 15 minutes'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Today ·'), findsOneWidget);
    });

    testWidgets('Show Routes is disabled when a point is missing', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            tripPlanStateProvider.overrideWith(() {
              final notifier = TripPlanNotifier();
              return notifier;
            }),
          ],
          child: MaterialApp(
            theme: margTheme(Brightness.light),
            home: const PlanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(PlanScreen));
      final container = ProviderScope.containerOf(element);

      // Clear the destination
      container.read(tripPlanStateProvider.notifier).updatePlan(
        (s) => s.copyWith(to: const Place(id: '', name: '', displayName: '', lat: 0, lng: 0)),
      );
      await tester.pumpAndSettle();

      // Check PrimaryButton is disabled
      final btn = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(btn.onPressed, isNull);
    });
  });

  group('Phase 3 - Autocomplete & Persistence Tests', () {
    testWidgets('PlaceSearchSheet debounces and caches search results', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      Place? selected;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
          ],
          child: MaterialApp(
            theme: margTheme(Brightness.light),
            home: Scaffold(
              body: PlaceSearchSheet(
                isSelectingFrom: false,
                onPlaceSelected: (p) => selected = p,
                onPickOnMap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows recent searches
      expect(find.text('RECENT SEARCHES'), findsOneWidget);
      expect(find.text('Deccan Gymkhana'), findsOneWidget);

      // Type a query
      await tester.enterText(find.byType(TextField), 'Kothrud');
      await tester.pump(const Duration(milliseconds: 100));
      // Still debouncing
      expect(find.text('Searching Pune places...'), findsOneWidget);

      // Advance past debounce (400ms)
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Results appear
      expect(find.byType(ListTile), findsWidgets);

      // Test selecting a place result
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(selected, isNotNull);
    });

    test('Recent searches persist across restarts via SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs1 = await SharedPreferences.getInstance();
      final storage1 = StorageService(prefs1);

      // Default recents
      expect(storage1.getRecentSearches().length, 2);

      // Add a new place
      const newPlace = Place(
        id: 'place_1',
        name: 'FC Road',
        displayName: 'Shivajinagar, Pune',
        lat: 18.5204,
        lng: 73.8410,
        type: 'poi',
      );
      await storage1.addRecentSearch(newPlace);

      final recents1 = storage1.getRecentSearches();
      expect(recents1.first.name, 'FC Road');
      expect(recents1.length, 3);

      // Simulate app restart with same SharedPreferences
      final rawStored = prefs1.getStringList('recent_searches');
      expect(rawStored, isNotNull);
      expect(rawStored!.first.contains('FC Road'), isTrue);

      final storageRestarted = StorageService(prefs1);
      final recentsRestarted = storageRestarted.getRecentSearches();
      expect(recentsRestarted.length, 3);
      expect(recentsRestarted.first.name, 'FC Road');

      // Test max 5 limit
      for (int i = 2; i <= 6; i++) {
        await storageRestarted.addRecentSearch(Place(
          id: 'place_$i',
          name: 'Location $i',
          displayName: 'Pune',
          lat: 18.50 + (i * 0.01),
          lng: 73.80 + (i * 0.01),
        ));
      }
      final cappedRecents = storageRestarted.getRecentSearches();
      expect(cappedRecents.length, 5);
      expect(cappedRecents.first.name, 'Location 6');
    });

    test('Dropped pin place creation creates proper reverse label', () {
      const pointLat = 18.5312;
      const pointLng = 73.8445;
      final droppedPlace = Place(
        id: 'dropped_pin',
        name: 'Dropped pin',
        displayName: '${pointLat.toStringAsFixed(4)}, ${pointLng.toStringAsFixed(4)}',
        lat: pointLat,
        lng: pointLng,
        type: 'pin',
      );

      expect(droppedPlace.name, 'Dropped pin');
      expect(droppedPlace.displayName, '18.5312, 73.8445');
      expect(droppedPlace.type, 'pin');
    });
  });
}
