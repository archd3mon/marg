import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/marg_tokens.dart';
import '../../data/models/stop.dart';
import '../../data/models/place.dart';
import '../../app/app_state.dart';
import 'widgets/explore_map.dart';
import 'widgets/map_action_buttons.dart';
import 'widgets/explore_sheet.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final MapController _mapController = MapController();
  LatLng _userLocation = const LatLng(18.5074, 73.8077);
  List<TransitStop> _nearbyStops = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initLocationAndStops();
  }

  Future<void> _initLocationAndStops() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.always ||
          hasPermission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 3),
          ),
        );
        _userLocation = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}

    await _loadNearbyStops();
  }

  Future<void> _loadNearbyStops() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(transitRepositoryProvider);
      final stops = await repo.getNearbyStops(_userLocation.latitude, _userLocation.longitude);
      if (mounted) {
        setState(() {
          _nearbyStops = stops;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Couldn't load nearby stops";
        });
      }
    }
  }

  void _onLocateMe() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 3),
        ),
      );
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_userLocation, 15.0);
      }
    } catch (_) {
      _mapController.move(_userLocation, 15.0);
    }
  }

  void _onToggleLayers() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transit layer active'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onSearchTap() {
    context.push('/plan');
  }

  void _onShortcutTap(String type) {
    final places = ref.read(savedPlacesProvider);
    final place = places.firstWhere((p) => p.type == type, orElse: () => places.first);
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

  void _onStopTap(TransitStop stop) {
    ref.read(tripPlanStateProvider.notifier).updatePlan((state) => state.copyWith(
      to: Place(
        id: stop.id,
        name: stop.name,
        displayName: stop.subtext.isNotEmpty ? stop.subtext : 'Pune',
        lat: stop.lat,
        lng: stop.lng,
        type: 'stop',
      ),
    ));
    context.push('/plan');
  }

  void _onMapLongPress(LatLng point) {
    HapticFeedback.mediumImpact();
    final droppedPlace = Place(
      id: 'dropped_pin',
      name: 'Dropped pin',
      displayName: '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
      lat: point.latitude,
      lng: point.longitude,
      type: 'pin',
    );

    ref.read(droppedPinProvider.notifier).setPin(droppedPlace);
    final pickTarget = ref.read(mapPickTargetProvider);

    if (pickTarget == MapPickTarget.origin) {
      ref.read(tripPlanStateProvider.notifier).updatePlan((s) => s.copyWith(from: droppedPlace));
      ref.read(mapPickTargetProvider.notifier).setTarget(MapPickTarget.none);
      context.push('/plan');
    } else {
      ref.read(tripPlanStateProvider.notifier).updatePlan((s) => s.copyWith(to: droppedPlace));
      ref.read(storageServiceProvider).addRecentSearch(droppedPlace);
      if (pickTarget == MapPickTarget.destination) {
        ref.read(mapPickTargetProvider.notifier).setTarget(MapPickTarget.none);
        context.push('/plan');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dropped pin placed'),
            action: SnackBarAction(
              label: 'Plan Trip',
              onPressed: () => context.push('/plan'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final droppedPin = ref.watch(droppedPinProvider);
    final pickTarget = ref.watch(mapPickTargetProvider);
    final isPicking = pickTarget != MapPickTarget.none;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // 1. Full-bleed interactive Map
          ExploreMap(
            mapController: _mapController,
            userLocation: _userLocation,
            nearbyStops: _nearbyStops,
            droppedPin: droppedPin != null ? LatLng(droppedPin.lat, droppedPin.lng) : null,
            onLongPress: _onMapLongPress,
          ),

          // 2. Top-right floating glass buttons (Locate-me + Layers)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: Sp.x3, right: Sp.x4),
              child: Align(
                alignment: Alignment.topRight,
                child: MapActionButtons(
                  onLocateMe: _onLocateMe,
                  onToggleLayers: _onToggleLayers,
                ),
              ),
            ),
          ),

          // 3. Picking Mode Banner (when active)
          if (isPicking)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, 110, 0),
                child: Glass(
                  radius: Rad.md,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x2),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app_rounded, color: c.blue, size: 18),
                        const SizedBox(width: Sp.x2),
                        Expanded(
                          child: Text(
                            'Long-press on map to drop pin',
                            style: MargText.caption.copyWith(
                              color: c.label,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            ref.read(mapPickTargetProvider.notifier).setTarget(MapPickTarget.none);
                          },
                          child: Icon(Icons.close_rounded, color: c.label3, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4. Draggable Scrollable Sheet (snaps: 0.14, 0.5, 0.92)
          if (!isPicking)
            ExploreSheet(
              onSearchTap: _onSearchTap,
              onHomeTap: () => _onShortcutTap('home'),
              onWorkTap: () => _onShortcutTap('work'),
              onAddTap: () => context.push('/saved'),
              stops: _nearbyStops,
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              onRetry: _loadNearbyStops,
              onStopTap: _onStopTap,
            ),
        ],
      ),
    );
  }
}
