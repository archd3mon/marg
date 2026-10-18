import 'package:go_router/go_router.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/results/results_screen.dart';
import '../features/itinerary/itinerary_screen.dart';
import '../features/live/live_screen.dart';
import '../data/storage_service.dart';
import 'app_shell.dart';

GoRouter createRouter(StorageService storage) {
  final initialLocation = storage.hasSeenOnboarding ? '/explore' : '/welcome';

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/explore',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: '/saved',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: '/alerts',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: '/plan',
        builder: (context, state) => const PlanScreen(),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) => const ResultsScreen(),
      ),
      GoRoute(
        path: '/itinerary',
        builder: (context, state) => const ItineraryScreen(),
      ),
      GoRoute(
        path: '/live',
        builder: (context, state) => const LiveScreen(),
      ),
    ],
  );
}
