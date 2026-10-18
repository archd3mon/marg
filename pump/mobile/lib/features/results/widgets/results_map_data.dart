import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/marg_tokens.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/place.dart';

abstract final class ResultsMapData {
  static List<LatLng> getAllPoints(TransitRoute route) {
    if (route.legs.isNotEmpty) {
      final points = <LatLng>[];
      for (final leg in route.legs) {
        if (leg.path.isNotEmpty) {
          points.addAll(leg.path);
        } else if (leg.fromNode.lat != 0.0 || leg.toNode.lat != 0.0) {
          points.add(LatLng(leg.fromNode.lat, leg.fromNode.lon));
          points.add(LatLng(leg.toNode.lat, leg.toNode.lon));
        }
      }
      if (points.isNotEmpty) return points;
    }

    if (route.routeId == 'r_transfers') {
      return const [
        LatLng(18.5074, 73.8077), LatLng(18.5126, 73.8291), LatLng(18.5182, 73.8413),
        LatLng(18.5284, 73.8744), LatLng(18.5529, 73.8797), LatLng(18.5679, 73.9143),
      ];
    }
    return const [
      LatLng(18.5074, 73.8077), LatLng(18.5098, 73.8180), LatLng(18.5182, 73.8413),
      LatLng(18.5308, 73.8475), LatLng(18.5529, 73.8797), LatLng(18.5679, 73.9143),
    ];
  }

  static List<LatLng> trimPoints(List<LatLng> points, double progress) {
    if (progress >= 1.0) return points;
    if (points.isEmpty || progress <= 0.0) return const [];
    if (points.length == 1) return points;
    final totalSegments = points.length - 1;
    final targetPos = progress * totalSegments;
    final index = targetPos.floor();
    final frac = targetPos - index;

    final result = <LatLng>[];
    for (int i = 0; i <= index && i < points.length; i++) {
      result.add(points[i]);
    }
    if (index < totalSegments && frac > 0.001) {
      final p1 = points[index];
      final p2 = points[index + 1];
      result.add(LatLng(
        p1.latitude + (p2.latitude - p1.latitude) * frac,
        p1.longitude + (p2.longitude - p1.longitude) * frac,
      ));
    }
    return result;
  }

  static List<Polyline> buildPolylines(
    TransitRoute route,
    double opacity,
    MargColors c,
    Place from,
    Place to, {
    double drawProgress = 1.0,
  }) {
    if (route.legs.isNotEmpty) {
      final polylines = <Polyline>[];
      final n = route.legs.length;

      for (int i = 0; i < n; i++) {
        final leg = route.legs[i];
        final List<LatLng> rawPoints;
        if (leg.path.isNotEmpty) {
          rawPoints = leg.path;
        } else if (leg.fromNode.lat != 0.0 || leg.toNode.lat != 0.0) {
          rawPoints = [
            LatLng(leg.fromNode.lat, leg.fromNode.lon),
            LatLng(leg.toNode.lat, leg.toNode.lon),
          ];
        } else {
          rawPoints = const [];
        }

        if (rawPoints.length < 2) continue;

        final double legProgress;
        if (drawProgress >= 1.0) {
          legProgress = 1.0;
        } else {
          final legStart = i / n;
          final legSpan = 1.0 / n;
          legProgress = ((drawProgress - legStart) / legSpan).clamp(0.0, 1.0);
        }

        final trimmed = trimPoints(rawPoints, legProgress);
        if (trimmed.length < 2) continue;

        if (leg.mode == 'walk') {
          polylines.add(Polyline(
            points: trimmed,
            strokeWidth: 4,
            color: c.gray.withValues(alpha: opacity),
            pattern: const StrokePattern.dotted(spacingFactor: 1.5),
          ));
        } else if (leg.mode == 'metro') {
          polylines.add(Polyline(
            points: trimmed,
            strokeWidth: 8,
            color: c.card.withValues(alpha: opacity),
          ));
          polylines.add(Polyline(
            points: trimmed,
            strokeWidth: 5,
            color: c.purple.withValues(alpha: opacity),
          ));
        } else {
          polylines.add(Polyline(
            points: trimmed,
            strokeWidth: 8,
            color: c.card.withValues(alpha: opacity),
          ));
          polylines.add(Polyline(
            points: trimmed,
            strokeWidth: 5,
            color: c.blue.withValues(alpha: opacity),
          ));
        }
      }

      if (polylines.isNotEmpty) return polylines;
    }

    final walkPts = [LatLng(from.lat, from.lng), const LatLng(18.5098, 73.8180)];
    final busPts = route.routeId == 'r_transfers'
        ? const [
            LatLng(18.5126, 73.8291), LatLng(18.5182, 73.8413), LatLng(18.5284, 73.8744),
            LatLng(18.5529, 73.8797), LatLng(18.5670, 73.9130),
          ]
        : const [
            LatLng(18.5098, 73.8180), LatLng(18.5182, 73.8413), LatLng(18.5308, 73.8475),
            LatLng(18.5529, 73.8797), LatLng(18.5670, 73.9130),
          ];
    final endWalkPts = [const LatLng(18.5670, 73.9130), LatLng(to.lat, to.lng)];

    final trimmedWalk = trimPoints(walkPts, (drawProgress * 3.0).clamp(0.0, 1.0));
    final trimmedBus = trimPoints(busPts, ((drawProgress - 0.2) * 1.5).clamp(0.0, 1.0));
    final trimmedEndWalk = trimPoints(endWalkPts, ((drawProgress - 0.7) * 3.3).clamp(0.0, 1.0));

    final isMetro = route.legs.any((l) => l.mode == 'metro');
    final transitColor = isMetro ? c.purple : c.blue;

    final polylines = <Polyline>[];
    if (trimmedWalk.length >= 2) {
      polylines.add(Polyline(
        points: trimmedWalk,
        strokeWidth: 4,
        color: c.gray.withValues(alpha: opacity),
        pattern: const StrokePattern.dotted(spacingFactor: 1.5),
      ));
    }
    if (trimmedBus.length >= 2) {
      polylines.add(Polyline(
        points: trimmedBus,
        strokeWidth: 8,
        color: c.card.withValues(alpha: opacity),
      ));
      polylines.add(Polyline(
        points: trimmedBus,
        strokeWidth: 5,
        color: transitColor.withValues(alpha: opacity),
      ));
    }
    if (trimmedEndWalk.length >= 2) {
      polylines.add(Polyline(
        points: trimmedEndWalk,
        strokeWidth: 4,
        color: c.gray.withValues(alpha: opacity),
        pattern: const StrokePattern.dotted(spacingFactor: 1.5),
      ));
    }
    return polylines;
  }
}
