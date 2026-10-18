import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/stop.dart';
import '../../../theme/marg_tokens.dart';

class ExploreMap extends StatelessWidget {
  final MapController mapController;
  final LatLng userLocation;
  final List<TransitStop> nearbyStops;
  final LatLng? droppedPin;
  final void Function(LatLng)? onLongPress;

  const ExploreMap({
    super.key,
    required this.mapController,
    required this.userLocation,
    required this.nearbyStops,
    this.droppedPin,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: userLocation,
        initialZoom: 14.8,
        minZoom: 10,
        maxZoom: 18,
        onLongPress: (tapPosition, point) => onLongPress?.call(point),
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrl,
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'in.marg.marg_app',
        ),
        MarkerLayer(
          markers: [
            // Nearby stop markers with labels
            ...nearbyStops.take(4).map((stop) => Marker(
                  point: LatLng(stop.lat, stop.lng),
                  width: 120,
                  height: 38,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: c.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.blue, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: c.label.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.card.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: c.separator, width: 0.5),
                        ),
                        child: Text(
                          stop.name,
                          style: MargText.caption.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: c.label,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),

            // Dropped Pin Marker
            if (droppedPin != null)
              Marker(
                point: droppedPin!,
                width: 140,
                height: 58,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Sp.x2, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(Rad.sm),
                        border: Border.all(color: c.separator, width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: c.label.withValues(alpha: 0.20),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Dropped pin',
                        style: MargText.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: c.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      Icons.location_on_rounded,
                      color: c.red,
                      size: 28,
                      shadows: [
                        Shadow(
                          color: c.label.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // User Location marker (Apple Maps style soft halo dot)
            Marker(
              point: userLocation,
              width: 48,
              height: 48,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.tint(c.blue, 0.16),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 19,
                      height: 19,
                      decoration: BoxDecoration(
                        color: c.card,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: c.label.withValues(alpha: 0.20),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 13.6,
                      height: 13.6,
                      decoration: BoxDecoration(
                        color: c.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
