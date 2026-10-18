import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/place.dart';
import '../data/models/route_model.dart';
import '../data/models/saved_item.dart';
import '../data/repositories/transit_repository.dart';
import '../data/storage_service.dart';
import '../shared/widgets/glass_tab_bar.dart';

// Theme mode provider
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;
  void setMode(ThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// Storage service provider
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden in ProviderScope');
});

// Transit repo provider
final transitRepositoryProvider = Provider<TransitRepository>((ref) {
  return TransitRepository();
});

// Navigation state
class CurrentTabNotifier extends Notifier<MargTab> {
  @override
  MargTab build() => MargTab.explore;
  void setTab(MargTab tab) => state = tab;
}

final currentTabProvider = NotifierProvider<CurrentTabNotifier, MargTab>(CurrentTabNotifier.new);

// Plan trip state
class TripPlanState {
  final Place from;
  final Place to;
  final String departureTime;
  final String priority; // 'fastest', 'least_transfers', 'least_walking'
  final bool isMetroDisabled;

  const TripPlanState({
    required this.from,
    required this.to,
    required this.departureTime,
    this.priority = 'fastest',
    this.isMetroDisabled = true,
  });

  TripPlanState copyWith({
    Place? from,
    Place? to,
    String? departureTime,
    String? priority,
    bool? isMetroDisabled,
  }) {
    return TripPlanState(
      from: from ?? this.from,
      to: to ?? this.to,
      departureTime: departureTime ?? this.departureTime,
      priority: priority ?? this.priority,
      isMetroDisabled: isMetroDisabled ?? this.isMetroDisabled,
    );
  }
}

class TripPlanNotifier extends Notifier<TripPlanState> {
  @override
  TripPlanState build() => const TripPlanState(
        from: Place(
          id: 'from_curr',
          name: 'Current Location',
          displayName: 'Kothrud, Pune',
          lat: 18.5074,
          lng: 73.8077,
          type: 'poi',
        ),
        to: Place(
          id: 'to_viman',
          name: 'Viman Nagar',
          displayName: 'Pune',
          lat: 18.5679,
          lng: 73.9143,
          type: 'poi',
        ),
        departureTime: 'Now · 8:42 AM',
        priority: 'fastest',
      );

  void updatePlan(TripPlanState Function(TripPlanState) fn) {
    state = fn(state);
  }

  void setPlan(TripPlanState newState) {
    state = newState;
  }
}

final tripPlanStateProvider = NotifierProvider<TripPlanNotifier, TripPlanState>(TripPlanNotifier.new);

enum MapPickTarget { none, origin, destination }

class MapPickTargetNotifier extends Notifier<MapPickTarget> {
  @override
  MapPickTarget build() => MapPickTarget.none;
  void setTarget(MapPickTarget target) => state = target;
}

final mapPickTargetProvider = NotifierProvider<MapPickTargetNotifier, MapPickTarget>(MapPickTargetNotifier.new);

class DroppedPinNotifier extends Notifier<Place?> {
  @override
  Place? build() => null;
  void setPin(Place? pin) => state = pin;
}

final droppedPinProvider = NotifierProvider<DroppedPinNotifier, Place?>(DroppedPinNotifier.new);

// Selected Route for details and live mode
class SelectedRouteNotifier extends Notifier<TransitRoute?> {
  @override
  TransitRoute? build() => null;
  void setRoute(TransitRoute? route) => state = route;
}

final selectedRouteProvider = NotifierProvider<SelectedRouteNotifier, TransitRoute?>(SelectedRouteNotifier.new);

// Live Trip State
class LiveTripState {
  final bool isActive;
  final TransitRoute? route;
  final int remainingMins;
  final String nextStop;
  final int stopsRemaining;
  final String arrivalTime;
  final String statusText;
  final double progressPercent; // 0.0 to 1.0

  const LiveTripState({
    this.isActive = false,
    this.route,
    this.remainingMins = 12,
    this.nextStop = 'Viman Nagar',
    this.stopsRemaining = 4,
    this.arrivalTime = '9:37',
    this.statusText = 'On time',
    this.progressPercent = 0.65,
  });
}

class LiveTripNotifier extends Notifier<LiveTripState> {
  @override
  LiveTripState build() => const LiveTripState();

  void updateTrip(LiveTripState Function(LiveTripState) fn) {
    state = fn(state);
  }

  void setTrip(LiveTripState newState) {
    state = newState;
  }
}

final liveTripProvider = NotifierProvider<LiveTripNotifier, LiveTripState>(LiveTripNotifier.new);

// Saved Places Notifier
class SavedPlacesNotifier extends Notifier<List<SavedPlace>> {
  @override
  List<SavedPlace> build() {
    return ref.watch(storageServiceProvider).getSavedPlaces();
  }

  Future<void> updatePlace(SavedPlace place) async {
    final list = state.map((p) => p.id == place.id ? place : p).toList();
    if (!list.any((p) => p.id == place.id)) {
      list.add(place);
    }
    state = list;
    await ref.read(storageServiceProvider).savePlaces(list);
  }
}

final savedPlacesProvider = NotifierProvider<SavedPlacesNotifier, List<SavedPlace>>(SavedPlacesNotifier.new);

// Saved Routes Notifier
class SavedRoutesNotifier extends Notifier<List<SavedRoute>> {
  @override
  List<SavedRoute> build() {
    return ref.watch(storageServiceProvider).getSavedRoutes();
  }

  Future<void> toggleSave(SavedRoute route) async {
    await ref.read(storageServiceProvider).toggleSaveRoute(route);
    state = ref.read(storageServiceProvider).getSavedRoutes();
  }

  Future<void> removeRoute(String id) async {
    final list = state.where((r) => r.id != id).toList();
    state = list;
    await ref.read(storageServiceProvider).saveRoutes(list);
  }
}

final savedRoutesProvider = NotifierProvider<SavedRoutesNotifier, List<SavedRoute>>(SavedRoutesNotifier.new);
