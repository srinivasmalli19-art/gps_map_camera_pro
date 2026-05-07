import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// Resolves a lat/lng to a human-readable address string.
///
/// Strategy:
///   1. Places Nearby Search (radius 50 m) → registered business / landmark name
///   2. Geocoding                           → locality / area string
///   3. Combine as "Place Name, Area"
///      If no named place is found, returns just the area address.
class GeocodingHelper {
  static Future<String> reverseGeocode(double lat, double lng) async {
    // Start both lookups in parallel so they don't block each other.
    final placeFuture = _findNearestPlaceName(lat, lng);
    final addressFuture = _getAreaAddress(lat, lng);

    final placeName = await placeFuture;
    final areaAddress = await addressFuture;

    if (placeName != null && placeName.isNotEmpty) {
      return '$placeName, $areaAddress';
    }
    return areaAddress;
  }

  // ── Places Nearby Search ───────────────────────────────────
  // Finds the closest registered establishment/landmark within 50 m.
  // Returns null when tapping on a road, field, or any unlisted location.

  static Future<String?> _findNearestPlaceName(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng'
        '&radius=50'
        '&key=${AppConstants.googleMapsApiKey}',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        // ZERO_RESULTS is normal — means no named place nearby.
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            return results[0]['name'] as String?;
          }
        }
      }
    } catch (e) {
      debugPrint('Places nearby search error: $e');
    }
    return null;
  }

  // ── Area / Locality Address ───────────────────────────────
  // Uses native geocoding plugin on Android/iOS for accuracy,
  // falls back to Geocoding REST API on web (plugin doesn't support web).

  static Future<String> _getAreaAddress(double lat, double lng) async {
    if (!kIsWeb) {
      try {
        final placemarks = await placemarkFromCoordinates(
          lat,
          lng,
          localeIdentifier: 'en_IN',
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if (p.subLocality?.isNotEmpty == true) p.subLocality!,
            if (p.locality?.isNotEmpty == true) p.locality!,
            if (p.subAdministrativeArea?.isNotEmpty == true)
              p.subAdministrativeArea!,
            if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
          ];
          if (parts.isNotEmpty) return parts.take(3).join(', ');
        }
      } catch (e) {
        debugPrint('Geocoding plugin error: $e — falling back to REST');
      }
    }
    return _geocodingRestApi(lat, lng);
  }

  // ── Geocoding REST API ────────────────────────────────────
  // Extracts sublocality / locality / district / state from Google's
  // Geocoding API response. Works on all platforms including web.

  static Future<String> _geocodingRestApi(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng'
        '&key=${AppConstants.googleMapsApiKey}'
        '&language=en',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final results = data['results'] as List;

          const wantedTypes = {
            'sublocality_level_1',
            'locality',
            'administrative_area_level_2',
            'administrative_area_level_1',
          };

          // Walk through results until we find locality-level components.
          for (final result in results) {
            final components = result['address_components'] as List;
            final parts = <String>[];
            for (final comp in components) {
              final types = (comp['types'] as List).cast<String>().toSet();
              if (types.intersection(wantedTypes).isNotEmpty) {
                parts.add(comp['long_name'] as String);
              }
            }
            if (parts.isNotEmpty) return parts.take(3).join(', ');
          }

          // Last resort: use the formatted_address of the first result.
          final formatted =
              results.isNotEmpty ? results[0]['formatted_address'] as String? : null;
          if (formatted != null && formatted.isNotEmpty) return formatted;
        }
      }
    } catch (e) {
      debugPrint('REST geocoding error: $e');
    }
    return 'Unknown Location';
  }
}
