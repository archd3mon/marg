import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/marg_tokens.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/place.dart';
import '../../results/widgets/results_map_data.dart';

class LiveMap extends StatelessWidget {
  final MapController mapController;
  final TransitRoute? route;
  final Place from;
  final Place to;
  final LatLng busPosition;
  final LatLng? userPosition;

  const LiveMap({
    super.key,
    required this.mapController,
    required this.route,
    required this.from,
    required this.to,
    required this.busPosition,
    this.userPosition,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    final effectiveRoute = route ??
        const TransitRoute(
          routeId: 'route_pmpml_17_144',
          score: 12.3,
          totalTimeMins: 55,
          transfers: 1,
          totalWalkM: 650,
          usesMetro: false,
          routeType: 'fastest',
          legs: [],
          departureTimeUsed: '8:42 AM',
        );

    final polylines = ResultsMapData.buildPolylines(effectiveRoute, 1.0, c, from, to);

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: busPosition,
        initialZoom: 13.5,
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrl,
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'in.marg.marg_app',
        ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(
          markers: [
            // Destination bullseye
            Marker(
              point: LatLng(to.lat, to.lng),
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: c.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.card, width: 3),
                ),
              ),
            ),

            // Live Bus Marker (snapped to route)
            Marker(
              point: busPosition,
              width: 44,
              height: 44,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.tint(c.blue, 0.25),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.card, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: c.label.withValues(alpha: 0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(Icons.directions_bus_rounded, color: c.card, size: 14),
                    ),
                  ],
                ),
              ),
            ),

            // User location pulsing dot (if available)
            if (userPosition != null)
              Marker(
                point: userPosition!,
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.card, width: 2.5),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
