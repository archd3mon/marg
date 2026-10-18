import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/marg_tokens.dart';
import '../../shared/widgets/badge_label.dart';
import '../../data/models/saved_item.dart';
import '../../app/app_state.dart';
import 'models/itinerary_step_data.dart';
import 'widgets/itinerary_map.dart';
import 'widgets/itinerary_top_bar.dart';
import 'widgets/itinerary_sheet.dart';

class ItineraryScreen extends ConsumerStatefulWidget {
  const ItineraryScreen({super.key});

  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen> {
  final MapController _mapController = MapController();

  void _shareTrip() {
    final route = ref.read(selectedRouteProvider);
    final tripPlan = ref.read(tripPlanStateProvider);
    final totalTime = route?.totalTimeMins ?? 55;
    final summary = 'Marg Pune Bus Trip: ${tripPlan.from.name} to ${tripPlan.to.name}\n'
        'Duration: $totalTime min · Arrive 9:37 AM · 1 transfer\n'
        '• Walk 6 min (450 m) to Kothrud Depot\n'
        '• Bus 17 towards Deccan Gymkhana (9 stops · 18 min)\n'
        '• Bus 144 towards Viman Nagar (11 stops · 24 min)\n'
        '• Walk 3 min (200 m) to ${tripPlan.to.name}\n'
        'Planned with Marg';

    try {
      SharePlus.instance.share(ShareParams(text: summary));
    } catch (_) {
      // Graceful fallback for test runners
    }
  }

  void _toggleSaveRoute() {
    final route = ref.read(selectedRouteProvider);
    final tripPlan = ref.read(tripPlanStateProvider);
    final routeId = route?.routeId ?? 'route_pmpml_17_144';
    final isAlreadySaved = ref.read(savedRoutesProvider).any((r) => r.id == routeId);

    final savedRoute = SavedRoute(
      id: routeId,
      title: '${tripPlan.from.name} → ${tripPlan.to.name}',
      fromName: tripPlan.from.name,
      toName: tripPlan.to.name,
      busLines: const ['17', '144'],
      scheduleText: 'Mon–Fri · 8:40',
      totalTimeMins: route?.totalTimeMins ?? 55,
      statusText: 'On time',
      isOnTime: true,
      sourceLat: tripPlan.from.lat,
      sourceLng: tripPlan.from.lng,
      destLat: tripPlan.to.lat,
      destLng: tripPlan.to.lng,
    );

    ref.read(savedRoutesProvider.notifier).toggleSave(savedRoute);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAlreadySaved ? 'Route removed from Saved' : 'Route saved to Saved tab',
          style: MargText.footnote.copyWith(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startTrip() {
    final route = ref.read(selectedRouteProvider);
    ref.read(liveTripProvider.notifier).setTrip(LiveTripState(
      isActive: true,
      route: route,
      remainingMins: 12,
      nextStop: 'Viman Nagar',
      stopsRemaining: 4,
      arrivalTime: '9:37',
      statusText: 'On time',
      progressPercent: 0.65,
    ));
    context.push('/live');
  }

  @override
  Widget build(BuildContext context) {
    final tripPlan = ref.watch(tripPlanStateProvider);
    final route = ref.watch(selectedRouteProvider);
    final savedRoutes = ref.watch(savedRoutesProvider);

    final routeId = route?.routeId ?? 'route_pmpml_17_144';
    final isSaved = savedRoutes.any((r) => r.id == routeId);

    final steps = ItineraryStepData.buildSteps(
      route: route,
      tripPlan: tripPlan,
    );

    final badgeType = switch (route?.routeType) {
      'least_transfers' => BadgeType.fewerTransfers,
      'least_walking' => BadgeType.lessWalking,
      _ => BadgeType.fastest,
    };

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-bleed interactive route map
          ItineraryMap(
            mapController: _mapController,
            route: route,
            from: tripPlan.from,
            to: tripPlan.to,
          ),

          // 2. Floating top bar with circular glass back and share buttons
          ItineraryTopBar(
            onBack: () => context.pop(),
            onShare: _shareTrip,
          ),

          // 3. Draggable glass sheet with journey timeline and CTAs
          ItinerarySheet(
            totalTimeMins: route?.totalTimeMins ?? 55,
            arrivalTime: '9:37 AM',
            transfers: route?.transfers ?? 1,
            totalWalkM: route?.totalWalkM ?? 650,
            badgeType: badgeType,
            steps: steps,
            onStartTrip: _startTrip,
            onToggleSave: _toggleSaveRoute,
            isSaved: isSaved,
          ),
        ],
      ),
    );
  }
}
