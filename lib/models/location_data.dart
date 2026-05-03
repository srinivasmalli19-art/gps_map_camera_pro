// lib/models/location_data.dart

/// Represents the two modes of the app
enum LocationMode { live, custom }

/// Holds all location-related data for a capture session
class LocationData {
  final double latitude;
  final double longitude;
  final String address;
  final LocationMode mode;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.mode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Human-readable mode name shown on overlays
  String get modeLabel =>
      mode == LocationMode.live ? 'Live Location' : 'Custom Location';

  /// True when using custom/manual map selection
  bool get isCustom => mode == LocationMode.custom;

  /// Formatted lat string
  String get latStr => latitude.toStringAsFixed(6);

  /// Formatted lng string
  String get lngStr => longitude.toStringAsFixed(6);

  @override
  String toString() =>
      'LocationData(lat: $latitude, lng: $longitude, address: $address, mode: $modeLabel)';
}
