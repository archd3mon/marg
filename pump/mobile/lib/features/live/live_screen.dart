import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/marg_tokens.dart';
import '../../data/models/route_model.dart';
import '../../app/app_state.dart';
import '../results/widgets/results_map_data.dart';
import 'models/trip_progress_data.dart';
import 'services/trip_progress_service.dart';
import 'widgets/live_banner.dart';
import 'widgets/live_sheet.dart';
import 'widgets/live_map.dart';
import 'widgets/live_end_trip_dialog.dart';

class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  final MapController _mapController = MapController();
  TripProgressService? _progressService;
  TripProgressData _progressData = const TripProgressData();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ref.read(selectedRouteProvider);
      final tripPlan = ref.read(tripPlanStateProvider);
      final points = ResultsMapData.getAllPoints(
        route ?? const TransitRoute(routeId: 'r1', totalTimeMins: 55, transfers: 1, totalWalkM: 650, routeType: 'fastest', legs: []),
      );

      _progressService = TripProgressService(
        route: route,
        polylinePoints: points,
        initialData: TripProgressData(
          nextStop: tripPlan.to.name.isNotEmpty ? tripPlan.to.name : 'Viman Nagar',
          routeLine: 'Route 144',
        ),
        onUpdate: (data) {
          if (mounted) setState(() => _progressData = data);
        },
      )..start();
    });
  }

  @override
  void dispose() {
    _progressService?.dispose();
    _progressService = null;
    super.dispose();
  }

  void _shareEta() {
    SharePlus.instance.share(
      ShareParams(
        text: 'My ETA to ${_progressData.nextStop} is ${_progressData.arrivalTime} '
            '(${_progressData.remainingMins} min remaining on ${_progressData.routeLine}). Marg Pune Bus.',
      ),
    );
  }

  void _endTrip() {
    LiveEndTripDialog.show(
      context,
      onConfirm: () {
        ref.read(liveTripProvider.notifier).setTrip(const LiveTripState(isActive: false));
        context.go('/explore');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tripPlan = ref.watch(tripPlanStateProvider);
    final route = ref.watch(selectedRouteProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          LiveMap(
            mapController: _mapController,
            route: route,
            from: tripPlan.from,
            to: tripPlan.to,
            busPosition: _progressData.busPosition,
            userPosition: _progressData.userPosition,
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LiveBanner(
              nextStop: _progressData.nextStop,
              stopsRemaining: _progressData.stopsRemaining,
              routeLine: _progressData.routeLine,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiveSheet(
              remainingMins: _progressData.remainingMins,
              arrivalTime: _progressData.arrivalTime,
              routeLine: _progressData.routeLine,
              statusText: _progressData.statusText,
              progressPercent: _progressData.progressPercent,
              onShareEta: _shareEta,
              onEndTrip: _endTrip,
            ),
          ),
        ],
      ),
    );
  }
}
