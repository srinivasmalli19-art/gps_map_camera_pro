// lib/constants/app_constants.dart

class AppConstants {
  static const String googleMapsApiKey =
      'AIzaSyBbT_Y4iCJrQYDiDpiLZU-PPuS6s0ZFKq0';

  static const String appName    = 'SLC GPS Map Camera Pro';
  static const String appVersion = '1.0.0';
  static const String folderName = 'SLC GPS Map Camera Pro';
  static const String filePrefix = 'SLC_GPS_';

  static const String disclaimer     = 'For documentation purposes only';
  static const String customWatermark = 'CUSTOM LOCATION USED';
  static const String liveLabel       = 'Live Location';
  static const String customLabel     = 'Custom Location';

  static const int overlayBgColor    = 0xE6000000;
  static const int customBadgeColor  = 0xFF6A1B9A;
  static const int liveBadgeColor    = 0xFF1B5E20;
  static const int watermarkColor    = 0xDD7B1FA2;
  static const int disclaimerColor   = 0xFFFFF59D;

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
