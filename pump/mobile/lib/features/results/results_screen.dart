import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import '../../theme/marg_tokens.dart';
import '../../data/models/route_model.dart';
import '../../app/app_state.dart';
import 'widgets/results_top_bar.dart';
import 'widgets/results_map.dart';
import 'widgets/route_card.dart';
import 'widgets/results_skeleton.dart';
import 'widgets/results_error_view.dart';
import 'widgets/results_empty_view.dart';
import 'widgets/results_header.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  final MapController _mapController = MapController();
  List<TransitRoute> _routes = [];
  TransitRoute? _selectedRoute;
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tripPlan = ref.read(tripPlanStateProvider);
      final repo = ref.read(transitRepositoryProvider);
      final routes = await repo.searchRoutes(
        srcLat: tripPlan.from.lat,
        srcLng: tripPlan.from.lng,
        destLat: tripPlan.to.lat,
        destLng: tripPlan.to.lng,
        departureTime: tripPlan.departureTime,
        priority: tripPlan.priority,
      );
      if (mounted) {
        setState(() {
          _routes = routes;
          _selectedRoute = routes.isNotEmpty ? routes.first : null;
          _isLoading = false;
        });
        if (_selectedRoute != null) {
          ref.read(selectedRouteProvider.notifier).setRoute(_selectedRoute);
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e; _isLoading = false; });
    }
  }

  void _onRouteCardTap(TransitRoute route) {
    HapticFeedback.selectionClick();
    if (_selectedRoute?.routeId == route.routeId) {
      context.push('/itinerary');
    } else {
      setState(() => _selectedRoute = route);
      ref.read(selectedRouteProvider.notifier).setRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tripPlan = ref.watch(tripPlanStateProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          ResultsMap(mapController: _mapController, selectedRoute: _selectedRoute, from: tripPlan.from, to: tripPlan.to),
          ResultsTopBar(from: tripPlan.from, to: tripPlan.to),
          DraggableScrollableSheet(
            initialChildSize: 0.58,
            minChildSize: 0.28,
            maxChildSize: 0.88,
            snap: true,
            builder: (context, scrollController) {
              return Glass(
                radius: Rad.sheet,
                topOnly: true,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
                  children: [
                    const SizedBox(height: Sp.x2),
                    Center(child: Container(width: 36, height: 5, decoration: BoxDecoration(color: c.label3, borderRadius: BorderRadius.circular(2.5)))),
                    const SizedBox(height: Sp.x3),
                    ResultsHeader(routeCount: _routes.length, warning: _selectedRoute?.warnings.firstOrNull),
                    const SizedBox(height: Sp.x4),
                    if (_isLoading)
                      const ResultsSkeleton()
                    else if (_error != null)
                      ResultsErrorView(error: _error, onRetry: _fetchRoutes)
                    else if (_routes.isEmpty)
                      const ResultsEmptyView()
                    else
                      ..._routes.map((r) => RouteCard(route: r, isSelected: _selectedRoute?.routeId == r.routeId, onTap: () => _onRouteCardTap(r))),
                    const SizedBox(height: Sp.x6),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
