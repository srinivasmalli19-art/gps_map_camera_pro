// lib/constants/app_constants.dart

/// Central configuration constants for GPS Map Camera Pro
class AppConstants {
  // ──────────────────────────────────────────────────────────
  // ★  SETUP REQUIRED: Replace this with your actual API key
  //    Enable: Maps SDK for Android, Geocoding API,
  //            and optionally Static Maps API in Google Cloud Console
  // ──────────────────────────────────────────────────────────
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // App metadata
  static const String appName = 'GPS Map Camera Pro';
  static const String appVersion = '1.0.0';

  // Overlay text constants
  static const String disclaimer = 'For documentation purposes only';
  static const String customWatermark = 'CUSTOM LOCATION USED';
  static const String liveLabel = 'Live Location';
  static const String customLabel = 'Custom Location';

  // Overlay visual constants (ARGB)
  static const int overlayBgColor = 0xE6000000; // 90% black
  static const int customBadgeColor = 0xFF6A1B9A; // Deep purple
  static const int liveBadgeColor = 0xFF1B5E20; // Deep green
  static const int watermarkColor = 0xDD7B1FA2; // Purple
  static const int disclaimerColor = 0xFFFFF59D; // Yellow 200

  // Static Maps URL template (optional — needs Static Maps API enabled)
  static String staticMapUrl(double lat, double lng) =>
      'https://maps.googleapis.com/maps/api/staticmap'
      '?center=$lat,$lng'
      '&zoom=14'
      '&size=300x200'
      '&scale=2'
      '&markers=color:red%7C$lat,$lng'
      '&style=feature:poi%7Cvisibility:off'
      '&key=$googleMapsApiKey';
}
