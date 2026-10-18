import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/route_model.dart';
import '../models/trip_progress_data.dart';

class TripProgressService {
  final TransitRoute? route;
  final List<LatLng> polylinePoints;
  final void Function(TripProgressData) onUpdate;

  StreamSubscription<Position>? _positionSub;
  Timer? _scheduleTimer;
  TripProgressData _currentData;
  DateTime _startTime = DateTime.now();

  TripProgressService({
    required this.route,
    required this.polylinePoints,
    required this.onUpdate,
    TripProgressData? initialData,
  }) : _currentData = initialData ?? const TripProgressData();

  TripProgressData get currentData => _currentData;

  void start() {
    _startTime = DateTime.now();
    _startLocationUpdates();
    _startScheduleTimer();
  }

  void _startLocationUpdates() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }
      const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
      _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) {
          final userLatLng = LatLng(pos.latitude, pos.longitude);
          final (snappedBus, progress) = snapToPolyline(userLatLng, polylinePoints);
          _applyProgress(progress, busPos: snappedBus, userPos: userLatLng);
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _startScheduleTimer() {
    _scheduleTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final totalMins = route?.totalTimeMins ?? 55;
      final elapsedSecs = DateTime.now().difference(_startTime).inSeconds;
      final simulatedProgress = ((elapsedSecs / (totalMins * 60)) + 0.58).clamp(0.0, 1.0);
      final busPos = pointAtProgress(simulatedProgress, polylinePoints);
      _applyProgress(simulatedProgress, busPos: busPos);
    });
  }

  void _applyProgress(double progress, {LatLng? busPos, LatLng? userPos}) {
    final totalMins = route?.totalTimeMins ?? 55;
    final remainingMins = ((1.0 - progress) * totalMins).round().clamp(1, totalMins);
    final stopsRemaining = ((1.0 - progress) * 8).round().clamp(1, 8);
    final lineName = route?.legs.firstWhere((l) => l.mode == 'bus', orElse: () => const RouteLeg(mode: 'bus', line: '144', fromNode: TransitNode(name: '', lat: 0, lon: 0), toNode: TransitNode(name: '', lat: 0, lon: 0), lengthM: 0, durationMins: 0)).line ?? '144';

    _currentData = _currentData.copyWith(
      progressPercent: progress,
      remainingMins: remainingMins,
      stopsRemaining: stopsRemaining,
      routeLine: 'Route $lineName',
      busPosition: busPos ?? _currentData.busPosition,
      userPosition: userPos ?? _currentData.userPosition,
    );
    onUpdate(_currentData);
  }

  static (LatLng, double) snapToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.length < 2) return (point, 0.58);
    const dist = Distance();
    double totalDist = 0.0;
    final segmentDists = <double>[];
    for (int i = 0; i < polyline.length - 1; i++) {
      final d = dist.as(LengthUnit.Meter, polyline[i], polyline[i + 1]);
      segmentDists.add(d);
      totalDist += d;
    }
    if (totalDist == 0) return (polyline.first, 0.0);

    double minDistance = double.infinity;
    LatLng bestPoint = polyline.first;
    double distUpToBest = 0.0;
    double runningDist = 0.0;

    for (int i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final (p, factor) = _projectOntoSegment(point, a, b);
      final d = dist.as(LengthUnit.Meter, point, p);
      if (d < minDistance) {
        minDistance = d;
        bestPoint = p;
        distUpToBest = runningDist + (factor * segmentDists[i]);
      }
      runningDist += segmentDists[i];
    }
    final ratio = (distUpToBest / totalDist).clamp(0.0, 1.0);
    return (bestPoint, ratio);
  }

  static (LatLng, double) _projectOntoSegment(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final segLenSq = dx * dx + dy * dy;
    if (segLenSq == 0) return (a, 0.0);
    final t = (((p.longitude - a.longitude) * dx) + ((p.latitude - a.latitude) * dy)) / segLenSq;
    final clampedT = t.clamp(0.0, 1.0);
    return (LatLng(a.latitude + clampedT * dy, a.longitude + clampedT * dx), clampedT);
  }

  static LatLng pointAtProgress(double progress, List<LatLng> polyline) {
    if (polyline.isEmpty) return const LatLng(18.545, 73.87);
    if (polyline.length == 1) return polyline.first;
    const dist = Distance();
    double totalDist = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      totalDist += dist.as(LengthUnit.Meter, polyline[i], polyline[i + 1]);
    }
    final targetDist = totalDist * progress.clamp(0.0, 1.0);
    double accum = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      final seg = dist.as(LengthUnit.Meter, polyline[i], polyline[i + 1]);
      if (accum + seg >= targetDist) {
        final t = seg == 0 ? 0.0 : (targetDist - accum) / seg;
        final a = polyline[i];
        final b = polyline[i + 1];
        return LatLng(a.latitude + t * (b.latitude - a.latitude), a.longitude + t * (b.longitude - a.longitude));
      }
      accum += seg;
    }
    return polyline.last;
  }

  void dispose() {
    _positionSub?.cancel();
    _positionSub = null;
    _scheduleTimer?.cancel();
    _scheduleTimer = null;
  }
}
