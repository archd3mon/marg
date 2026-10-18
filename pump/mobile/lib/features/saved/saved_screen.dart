import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/marg_tokens.dart';
import '../../data/models/saved_item.dart';
import '../../data/models/place.dart';
import '../../app/app_state.dart';
import 'widgets/saved_places_grid.dart';
import 'widgets/saved_routes_list.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  void _onPlaceTap(BuildContext context, WidgetRef ref, SavedPlace place) {
    ref.read(tripPlanStateProvider.notifier).updatePlan((state) => state.copyWith(
      to: Place(
        id: place.id,
        name: place.name,
        displayName: place.locationName,
        lat: place.lat,
        lng: place.lng,
        type: place.type,
      ),
    ));
    context.push('/plan');
  }

  void _onRouteTap(BuildContext context, WidgetRef ref, SavedRoute route) {
    ref.read(tripPlanStateProvider.notifier).setPlan(TripPlanState(
      from: Place(
        id: 'src_${route.id}',
        name: route.fromName,
        displayName: 'Pune',
        lat: route.sourceLat,
        lng: route.sourceLng,
      ),
      to: Place(
        id: 'dest_${route.id}',
        name: route.toName,
        displayName: 'Pune',
        lat: route.destLat,
        lng: route.destLng,
      ),
      departureTime: 'Now · 8:42 AM',
      priority: 'fastest',
    ));
    context.push('/results');
  }

  void _onRouteDelete(BuildContext context, WidgetRef ref, SavedRoute route) {
    ref.read(savedRoutesProvider.notifier).removeRoute(route.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${route.title}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final places = ref.watch(savedPlacesProvider);
    final routes = ref.watch(savedRoutesProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
          children: [
            const SizedBox(height: Sp.x4),
            Text(
              'Saved',
              style: MargText.largeTitle.copyWith(color: c.label),
            ),
            const SizedBox(height: Sp.x4),

            // Quick places grid (Home & Work)
            SavedPlacesGrid(
              places: places,
              onPlaceTap: (place) => _onPlaceTap(context, ref, place),
            ),

            const SizedBox(height: Sp.x6),

            // "ROUTES" Section Header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: Sp.x2),
              child: Text(
                'ROUTES',
                style: MargText.footnote.copyWith(
                  color: c.label2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Saved Routes grouped list with swipe-to-delete
            SavedRoutesList(
              routes: routes,
              onRouteTap: (route) => _onRouteTap(context, ref, route),
              onRouteDelete: (route) => _onRouteDelete(context, ref, route),
            ),

            const SizedBox(height: Sp.x3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.x2),
              child: Text(
                'Saved routes check live conditions and alert you before you leave.',
                style: MargText.footnote.copyWith(color: c.label2),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
