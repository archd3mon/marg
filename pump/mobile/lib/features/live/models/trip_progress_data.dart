import 'package:latlong2/latlong.dart';

class TripProgressData {
  final String nextStop;
  final int stopsRemaining;
  final String routeLine;
  final int remainingMins;
  final String arrivalTime;
  final String statusText;
  final double progressPercent;
  final LatLng busPosition;
  final LatLng? userPosition;

  const TripProgressData({
    this.nextStop = 'Viman Nagar',
    this.stopsRemaining = 4,
    this.routeLine = 'Route 144',
    this.remainingMins = 12,
    this.arrivalTime = '9:37',
    this.statusText = 'On time',
    this.progressPercent = 0.58,
    this.busPosition = const LatLng(18.545, 73.87),
    this.userPosition,
  });

  TripProgressData copyWith({
    String? nextStop,
    int? stopsRemaining,
    String? routeLine,
    int? remainingMins,
    String? arrivalTime,
    String? statusText,
    double? progressPercent,
    LatLng? busPosition,
    LatLng? userPosition,
  }) {
    return TripProgressData(
      nextStop: nextStop ?? this.nextStop,
      stopsRemaining: stopsRemaining ?? this.stopsRemaining,
      routeLine: routeLine ?? this.routeLine,
      remainingMins: remainingMins ?? this.remainingMins,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      statusText: statusText ?? this.statusText,
      progressPercent: progressPercent ?? this.progressPercent,
      busPosition: busPosition ?? this.busPosition,
      userPosition: userPosition ?? this.userPosition,
    );
  }
}
