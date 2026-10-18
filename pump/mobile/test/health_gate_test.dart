import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marg_app/app/health_gate.dart';
import 'package:marg_app/app/app_state.dart';
import 'package:marg_app/theme/marg_tokens.dart';
import 'package:marg_app/data/storage_service.dart';
import 'package:marg_app/main.dart';
import 'fake_transit_repository.dart';

void main() {
  group('App-Start Health Gate Tests', () {
    testWidgets('(a) unhealthy then healthy -> proceeds', (tester) async {
      int checkCount = 0;
      final fakeRepo = FakeTransitRepository();
      fakeRepo.onCheckHealth = () {
        checkCount++;
        // First check (at start) is unhealthy, second check (after 1s backoff) is healthy
        return checkCount >= 2;
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transitRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: margTheme(Brightness.light),
            home: const HealthGate(
              child: Text('Marg App Main Screen'),
            ),
          ),
        ),
      );

      // On initial build: first health check ran and returned false.
      // Shows "Waking up Marg…" state.
      expect(find.text('Waking up Marg…'), findsOneWidget);
      expect(find.text('Marg App Main Screen'), findsNothing);
      expect(checkCount, 1);

      // Advance by the 1s initial backoff
      await tester.pump(const Duration(seconds: 1));
      // Second check runs and returns true -> proceeds to child!
      await tester.pumpAndSettle();

      expect(checkCount, 2);
      expect(find.text('Marg App Main Screen'), findsOneWidget);
      expect(find.text('Waking up Marg…'), findsNothing);
    });

    testWidgets('(b) never healthy -> error view with Retry', (tester) async {
      final fakeRepo = FakeTransitRepository();
      fakeRepo.checkHealthResult = false; // Always unhealthy

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transitRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: margTheme(Brightness.light),
            home: const HealthGate(
              child: Text('Marg App Main Screen'),
            ),
          ),
        ),
      );

      // Initial check
      await tester.pump();
      expect(find.text('Waking up Marg…'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Marg App Main Screen'), findsNothing);

      // Advance through all backoff delays (1s, 3s, 5s * 11) up to ~60s
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      for (int i = 0; i < 11; i++) {
        await tester.pump(const Duration(seconds: 5));
      }
      await tester.pumpAndSettle();

      // Exhausted retries -> error view with Retry button
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Waking up Marg…'), findsOneWidget);
      expect(find.text('Marg App Main Screen'), findsNothing);

      // Tapping Retry when backend is now healthy restarts polling and proceeds
      fakeRepo.checkHealthResult = true;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Marg App Main Screen'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('MargApp integrated health gate cold start flow', (tester) async {
      SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
      final storage = await StorageService.init();

      int checkCount = 0;
      final fakeRepo = FakeTransitRepository();
      fakeRepo.onCheckHealth = () {
        checkCount++;
        return checkCount >= 2;
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            transitRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MargApp(storage: storage),
        ),
      );

      // Initially shows Waking up Marg…
      expect(find.text('Waking up Marg…'), findsOneWidget);

      // After 1s, wakes up and proceeds to explore
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Waking up Marg…'), findsNothing);
      expect(find.text('Explore'), findsWidgets);
    });
  });
}
