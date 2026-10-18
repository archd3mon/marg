import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/saved_item.dart';
import 'models/place.dart';

class StorageService {
  static const _kOnboardingKey = 'has_seen_onboarding';
  static const _kSavedPlacesKey = 'saved_places';
  static const _kSavedRoutesKey = 'saved_routes';
  static const _kRecentSearchesKey = 'recent_searches';
  static const _kNotifyDelaysKey = 'notify_delays';
  static const _kNotifyLeaveNowKey = 'notify_leave_now';
  static const _kNotifyServiceChangesKey = 'notify_service_changes';
  static const _kDemoAlertsKey = 'demo_alerts_enabled';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  bool get hasSeenOnboarding => _prefs.getBool(_kOnboardingKey) ?? false;
  Future<void> setHasSeenOnboarding(bool val) => _prefs.setBool(_kOnboardingKey, val);

  // Notification toggles
  bool get notifyDelays => _prefs.getBool(_kNotifyDelaysKey) ?? true;
  Future<void> setNotifyDelays(bool val) => _prefs.setBool(_kNotifyDelaysKey, val);

  bool get notifyLeaveNow => _prefs.getBool(_kNotifyLeaveNowKey) ?? true;
  Future<void> setNotifyLeaveNow(bool val) => _prefs.setBool(_kNotifyLeaveNowKey, val);

  bool get notifyServiceChanges => _prefs.getBool(_kNotifyServiceChangesKey) ?? false;
  Future<void> setNotifyServiceChanges(bool val) => _prefs.setBool(_kNotifyServiceChangesKey, val);

  // kDemoAlerts toggle - default false; forced false in release mode
  bool get demoAlertsEnabled {
    if (kReleaseMode) return false;
    const compileTimeDefault = bool.fromEnvironment('DEMO_ALERTS', defaultValue: false);
    return _prefs.getBool(_kDemoAlertsKey) ?? compileTimeDefault;
  }

  Future<void> setDemoAlertsEnabled(bool val) async {
    if (kReleaseMode) return;
    await _prefs.setBool(_kDemoAlertsKey, val);
  }

  // Saved Places
  List<SavedPlace> getSavedPlaces() {
    final raw = _prefs.getStringList(_kSavedPlacesKey);
    if (raw == null || raw.isEmpty) {
      // Default initial seeds matching reference screens
      return const [
        SavedPlace(id: 'home', name: 'Home', locationName: 'Kothrud', lat: 18.5074, lng: 73.8077, type: 'home'),
        SavedPlace(id: 'work', name: 'Work', locationName: 'Viman Nagar', lat: 18.5679, lng: 73.9143, type: 'work'),
      ];
    }
    return raw.map((str) => SavedPlace.fromJson(jsonDecode(str) as Map<String, dynamic>)).toList();
  }

  Future<void> savePlaces(List<SavedPlace> places) {
    final raw = places.map((p) => jsonEncode(p.toJson())).toList();
    return _prefs.setStringList(_kSavedPlacesKey, raw);
  }

  // Saved Routes
  List<SavedRoute> getSavedRoutes() {
    final raw = _prefs.getStringList(_kSavedRoutesKey);
    if (raw == null || raw.isEmpty) {
      return const [
        SavedRoute(
          id: 'sr1',
          title: 'Home → Work',
          fromName: 'Kothrud',
          toName: 'Viman Nagar',
          busLines: ['17', '144'],
          scheduleText: 'Mon–Fri · 8:40',
          totalTimeMins: 55,
          statusText: 'On time',
          isOnTime: true,
          sourceLat: 18.5074,
          sourceLng: 73.8077,
          destLat: 18.5679,
          destLng: 73.9143,
        ),
        SavedRoute(
          id: 'sr2',
          title: 'Home → Deccan',
          fromName: 'Kothrud',
          toName: 'Deccan',
          busLines: ['17'],
          scheduleText: 'Weekends',
          totalTimeMins: 22,
          statusText: 'Next 6 min',
          isOnTime: true,
          sourceLat: 18.5074,
          sourceLng: 73.8077,
          destLat: 18.5182,
          destLng: 73.8413,
        ),
      ];
    }
    return raw.map((str) => SavedRoute.fromJson(jsonDecode(str) as Map<String, dynamic>)).toList();
  }

  Future<void> saveRoutes(List<SavedRoute> routes) {
    final raw = routes.map((r) => jsonEncode(r.toJson())).toList();
    return _prefs.setStringList(_kSavedRoutesKey, raw);
  }

  Future<void> toggleSaveRoute(SavedRoute route) async {
    final list = getSavedRoutes().toList();
    final idx = list.indexWhere((r) => r.id == route.id || (r.fromName == route.fromName && r.toName == route.toName));
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.add(route);
    }
    await saveRoutes(list);
  }

  // Recents
  List<Place> getRecentSearches() {
    final raw = _prefs.getStringList(_kRecentSearchesKey);
    if (raw == null || raw.isEmpty) {
      return const [
        Place(id: 'rec1', name: 'Deccan Gymkhana', displayName: 'Pune', lat: 18.5182, lng: 73.8413, type: 'stop'),
        Place(id: 'rec2', name: 'Pune Station', displayName: 'Pune', lat: 18.5284, lng: 73.8744, type: 'station'),
      ];
    }
    return raw.map((str) => Place.fromJson(jsonDecode(str) as Map<String, dynamic>)).toList();
  }

  Future<void> addRecentSearch(Place place) async {
    final list = getRecentSearches().where((p) => p.name != place.name).toList();
    list.insert(0, place);
    if (list.length > 5) list.removeLast();
    final raw = list.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_kRecentSearchesKey, raw);
  }
}
