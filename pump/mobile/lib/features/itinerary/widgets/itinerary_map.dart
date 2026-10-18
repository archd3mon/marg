import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/marg_tokens.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/place.dart';
import '../../results/widgets/results_map_data.dart';

class ItineraryMap extends StatefulWidget {
  final MapController mapController;
  final TransitRoute? route;
  final Place from;
  final Place to;

  const ItineraryMap({
    super.key,
    required this.mapController,
    required this.route,
    required this.from,
    required this.to,
  });

  @override
  State<ItineraryMap> createState() => _ItineraryMapState();
}

class _ItineraryMapState extends State<ItineraryMap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitRouteBounds();
    });
  }

  void _fitRouteBounds() {
    final points = widget.route != null
        ? ResultsMapData.getAllPoints(widget.route!)
        : [
            LatLng(widget.from.lat, widget.from.lng),
            const LatLng(18.5182, 73.8413),
            const LatLng(18.5308, 73.8475),
            const LatLng(18.5529, 73.8797),
            LatLng(widget.to.lat, widget.to.lng),
          ];

    if (points.isEmpty) return;

    final cameraFit = CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.only(top: 110, bottom: 360, left: 44, right: 44),
      maxZoom: 15.0,
    );
    final fit = cameraFit.fit(widget.mapController.camera);
    widget.mapController.move(fit.center, fit.zoom);
  }

  Marker _buildMarker(LatLng point, Widget child, {double size = 22}) {
    return Marker(point: point, width: size, height: size, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    final effectiveRoute = widget.route ??
        const TransitRoute(
          routeId: 'route_pmpml_17_144',
          score: 12.3,
          totalTimeMins: 55,
          transfers: 1,
          totalWalkM: 650,
          usesMetro: false,
          routeType: 'fastest',
          legs: [],
          warnings: [],
          departureTimeUsed: '8:42 AM',
        );

    final polylines = ResultsMapData.buildPolylines(effectiveRoute, 1.0, c, widget.from, widget.to);

    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: LatLng((widget.from.lat + widget.to.lat) / 2, (widget.from.lng + widget.to.lng) / 2),
        initialZoom: 12.8,
      ),
      children: [
        TileLayer(urlTemplate: tileUrl, subdomains: const ['a', 'b', 'c', 'd'], userAgentPackageName: 'in.marg.marg_app'),
        PolylineLayer(polylines: polylines),
        MarkerLayer(
          markers: [
            _buildMarker(
              LatLng(widget.from.lat, widget.from.lng),
              Container(decoration: BoxDecoration(color: c.blue, shape: BoxShape.circle, border: Border.all(color: c.card, width: 3))),
            ),
            if (effectiveRoute.legs.isNotEmpty) ...[
              for (int i = 0; i < effectiveRoute.legs.length - 1; i++)
                if (effectiveRoute.legs[i].mode != 'walk' && effectiveRoute.legs[i + 1].mode != 'walk')
                  _buildMarker(
                    LatLng(effectiveRoute.legs[i].toNode.lat, effectiveRoute.legs[i].toNode.lon),
                    Container(decoration: BoxDecoration(color: c.card, shape: BoxShape.circle, border: Border.all(color: c.blue, width: 3.5))),
                    size: 20,
                  ),
            ] else if (effectiveRoute.transfers > 0) ...[
              _buildMarker(
                const LatLng(18.5182, 73.8413),
                Container(decoration: BoxDecoration(color: c.card, shape: BoxShape.circle, border: Border.all(color: c.blue, width: 3.5))),
                size: 20,
              ),
            ],
            _buildMarker(
              LatLng(widget.to.lat, widget.to.lng),
              Container(
                decoration: BoxDecoration(color: c.card, shape: BoxShape.circle, border: Border.all(color: c.red, width: 3.5)),
                child: Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.red, shape: BoxShape.circle))),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
