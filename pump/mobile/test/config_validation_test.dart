import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marg_app/app/config_validator.dart';
import 'package:marg_app/app/config_error_screen.dart';
import 'package:marg_app/data/api_client.dart';
import 'package:marg_app/data/storage_service.dart';
import 'package:marg_app/data/repositories/transit_repository.dart';
import 'package:marg_app/app/app_state.dart';
import 'package:marg_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigValidator Unit Tests', () {
    test('allows empty or http API_BASE in debug mode', () {
      expect(ConfigValidator.validateApiBase(apiBase: '', isRelease: false), isNull);
      expect(ConfigValidator.validateApiBase(apiBase: 'http://10.0.2.2:8000/api/v1', isRelease: false), isNull);
    });

    test('rejects empty API_BASE in release mode', () {
      final err = ConfigValidator.validateApiBase(apiBase: '', isRelease: true);
      expect(err, isNotNull);
      expect(err, contains('API_BASE configuration is missing'));
    });

    test('rejects cleartext HTTP API_BASE in release mode', () {
      final err = ConfigValidator.validateApiBase(apiBase: 'http://10.0.2.2:8000/api/v1', isRelease: true);
      expect(err, isNotNull);
      expect(err, contains('Insecure or invalid API_BASE'));
      expect(err, contains('strictly require an HTTPS URL'));
    });

    test('accepts valid HTTPS API_BASE in release mode', () {
      final err = ConfigValidator.validateApiBase(apiBase: 'https://api.marg.in/api/v1', isRelease: true);
      expect(err, isNull);
    });
  });

  group('Release Mode Repository Guard Tests', () {
    test('disallows demo fallback in release mode if API_BASE is missing', () async {
      final repo = TransitRepository(
        client: ApiClient(customBaseUrl: ''),
        isRelease: true,
      );

      expect(await repo.checkHealth(), isFalse);
      expect(() => repo.getNearbyStops(18.5, 73.8), throwsA(isA<ApiUnavailableException>()));
      expect(() => repo.searchGeocode('Kothrud'), throwsA(isA<ApiUnavailableException>()));
      expect(() => repo.searchRoutes(srcLat: 18.5, srcLng: 73.8, destLat: 18.6, destLng: 73.9), throwsA(isA<ApiUnavailableException>()));
    });
  });

  group('Startup Check Widget Tests', () {
    testWidgets('Release build with empty API_BASE displays ConfigErrorScreen', (tester) async {
      SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
      final storage = await StorageService.init();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
          ],
          child: MargApp(
            storage: storage,
            apiBaseOverride: '',
            isReleaseOverride: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConfigErrorScreen), findsOneWidget);
      expect(find.text('Configuration Error'), findsOneWidget);
      expect(find.textContaining('API_BASE configuration is missing'), findsOneWidget);
    });

    testWidgets('Release build with cleartext HTTP API_BASE displays ConfigErrorScreen', (tester) async {
      SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
      final storage = await StorageService.init();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
          ],
          child: MargApp(
            storage: storage,
            apiBaseOverride: 'http://10.0.2.2:8000/api/v1',
            isReleaseOverride: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConfigErrorScreen), findsOneWidget);
      expect(find.text('Configuration Error'), findsOneWidget);
      expect(find.textContaining('Insecure or invalid API_BASE'), findsOneWidget);
    });

    testWidgets('Debug build with empty API_BASE starts normally into demo mode', (tester) async {
      SharedPreferences.setMockInitialValues({'has_seen_onboarding': false});
      final storage = await StorageService.init();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
          ],
          child: MargApp(
            storage: storage,
            apiBaseOverride: '',
            isReleaseOverride: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConfigErrorScreen), findsNothing);
      expect(find.text("Pune's buses, planned beautifully."), findsOneWidget);
    });
  });
}
