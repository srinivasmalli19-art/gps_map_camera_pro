// lib/providers/location_provider.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_data.dart';
import '../utils/geocoding_helper.dart';

/// Manages location state across the app using ChangeNotifier
class LocationProvider extends ChangeNotifier {
  LocationData? _locationData;
  bool _isLoading = false;
  String? _error;

  // ── Getters ──────────────────────────────────────────────
  LocationData? get locationData => _locationData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLocation => _locationData != null;

  // ── Custom Location (Map Picker) ──────────────────────────

  /// Called after user confirms a location on the map picker screen
  void setCustomLocation(double lat, double lng, String address) {
    _locationData = LocationData(
      latitude: lat,
      longitude: lng,
      address: address,
      mode: LocationMode.custom,
    );
    _error = null;
    notifyListeners();
  }

  // ── Live GPS Location ─────────────────────────────────────

  /// Requests device GPS, performs reverse geocoding, updates state
  Future<bool> fetchLiveLocation() async {
    _setLoading(true);

    try {
      // 1. Check if location service is enabled
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setError('Location services are disabled.\nPlease enable GPS in Settings.');
        return false;
      }

      // 2. Request permission if needed
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setError('Location permission denied.\nPlease allow location access.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setError(
          'Location permission permanently denied.\n'
          'Please enable it from App Settings.',
        );
        return false;
      }

      // 3. Get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );

      // 4. Reverse geocode to get human-readable address
      final address = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      _locationData = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        mode: LocationMode.live,
      );

      _isLoading = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to get location.\nPlease try again.\n($e)');
      return false;
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) =>
      GeocodingHelper.reverseGeocode(lat, lng);

  // ── Helpers ───────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    if (value) _error = null;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Resets all state (used when navigating back to home)
  void reset() {
    _locationData = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
