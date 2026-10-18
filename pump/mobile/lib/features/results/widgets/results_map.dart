import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/marg_tokens.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/place.dart';
import 'results_map_data.dart';

class ResultsMap extends StatefulWidget {
  final MapController mapController;
  final TransitRoute? selectedRoute;
  final Place from;
  final Place to;

  const ResultsMap({
    super.key,
    required this.mapController,
    required this.selectedRoute,
    required this.from,
    required this.to,
  });

  @override
  State<ResultsMap> createState() => _ResultsMapState();
}

class _ResultsMapState extends State<ResultsMap> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _drawController;
  late final Animation<double> _drawAnimation;
  AnimationController? _moveController;
  TransitRoute? _previousRoute;
  TransitRoute? _currentRoute;

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.selectedRoute;
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250), value: 1.0);
    _drawController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _drawAnimation = CurvedAnimation(parent: _drawController, curve: Curves.easeOutCubic);
    _drawController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentRoute != null) _animateFitRoute(_currentRoute!);
    });
  }

  @override
  void didUpdateWidget(covariant ResultsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedRoute?.routeId != oldWidget.selectedRoute?.routeId) {
      _previousRoute = oldWidget.selectedRoute;
      _currentRoute = widget.selectedRoute;
      _fadeController.forward(from: 0.0);
      if (_currentRoute != null) _animateFitRoute(_currentRoute!);
    }
  }

  @override
  void dispose() {
    _drawController.dispose();
    _fadeController.dispose();
    _moveController?.dispose();
    super.dispose();
  }

  void _animateFitRoute(TransitRoute route) {
    final points = ResultsMapData.getAllPoints(route);
    if (points.isEmpty) return;
    final cameraFit = CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.only(top: 130, bottom: 340, left: 44, right: 44),
      maxZoom: 15.0,
    );
    final fit = cameraFit.fit(widget.mapController.camera);
    final latTween = Tween<double>(begin: widget.mapController.camera.center.latitude, end: fit.center.latitude);
    final lngTween = Tween<double>(begin: widget.mapController.camera.center.longitude, end: fit.center.longitude);
    final zoomTween = Tween<double>(begin: widget.mapController.camera.zoom, end: fit.zoom);

    _moveController?.dispose();
    final moveCtrl = AnimationController(duration: const Duration(milliseconds: 350), vsync: this);
    _moveController = moveCtrl;
    final anim = CurvedAnimation(parent: moveCtrl, curve: Curves.easeOutCubic);
    moveCtrl.addListener(() {
      widget.mapController.move(LatLng(latTween.evaluate(anim), lngTween.evaluate(anim)), zoomTween.evaluate(anim));
    });
    moveCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeController, _drawAnimation]),
      builder: (context, _) {
        final currentPolylines = _currentRoute != null
            ? ResultsMapData.buildPolylines(
                _currentRoute!,
                _fadeController.value,
                c,
                widget.from,
                widget.to,
                drawProgress: _drawAnimation.value,
              )
            : <Polyline>[];
        final prevPolylines = (_previousRoute != null && _fadeController.value < 1.0)
            ? ResultsMapData.buildPolylines(
                _previousRoute!,
                1.0 - _fadeController.value,
                c,
                widget.from,
                widget.to,
              )
            : <Polyline>[];

        return FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: LatLng((widget.from.lat + widget.to.lat) / 2, (widget.from.lng + widget.to.lng) / 2),
            initialZoom: 12.8,
          ),
          children: [
            TileLayer(urlTemplate: tileUrl, subdomains: const ['a', 'b', 'c', 'd'], userAgentPackageName: 'in.marg.marg_app'),
            PolylineLayer(polylines: [...prevPolylines, ...currentPolylines]),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(widget.from.lat, widget.from.lng),
                  width: 22, height: 22,
                  child: Container(
                    decoration: BoxDecoration(color: c.blue, shape: BoxShape.circle, border: Border.all(color: c.card, width: 3),
                      boxShadow: [BoxShadow(color: c.label.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 1))]),
                  ),
                ),
                if ((_currentRoute?.transfers ?? 1) > 0)
                  Marker(
                    point: const LatLng(18.5182, 73.8413),
                    width: 20, height: 20,
                    child: Container(
                      decoration: BoxDecoration(color: c.card, shape: BoxShape.circle, border: Border.all(color: c.blue, width: 3.5),
                        boxShadow: [BoxShadow(color: c.label.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 1))]),
                    ),
                  ),
                Marker(
                  point: LatLng(widget.to.lat, widget.to.lng),
                  width: 22, height: 22,
                  child: Container(
                    decoration: BoxDecoration(color: c.card, shape: BoxShape.circle, border: Border.all(color: c.red, width: 3.5),
                      boxShadow: [BoxShadow(color: c.label.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 1))]),
                    child: Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.red, shape: BoxShape.circle))),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
