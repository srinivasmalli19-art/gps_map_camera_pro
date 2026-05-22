// lib/widgets/camera_overlay_widget.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/location_data.dart';
import '../constants/app_constants.dart';

/// Compact dark floating card — sits in the bottom-left corner of the
/// camera viewfinder. camera_screen.dart wraps it with Positioned(left, bottom).
class CameraOverlayWidget extends StatefulWidget {
  final LocationData locationData;
  final bool isLandscape;

  const CameraOverlayWidget({
    super.key,
    required this.locationData,
    required this.isLandscape,
  });

  @override
  State<CameraOverlayWidget> createState() => _CameraOverlayWidgetState();
}

class _CameraOverlayWidgetState extends State<CameraOverlayWidget> {
  late String _currentTime;
  late final Stream<String> _timeStream;

  @override
  void initState() {
    super.initState();
    _currentTime = _fmt(DateTime.now());
    _timeStream = Stream.periodic(
      const Duration(seconds: 1),
      (_) => _fmt(DateTime.now()),
    );
  }

  String _fmt(DateTime dt) => DateFormat('dd MMM yyyy  HH:mm:ss').format(dt);

  Color get _accent =>
      widget.locationData.isCustom
          ? const Color(0xFF7C3AED)
          : const Color(0xFF00BCD4);

  @override
  Widget build(BuildContext context) {
    final loc = widget.locationData;
    final mapSize = widget.isLandscape ? 52.0 : 56.0;
    final cardWidth = widget.isLandscape ? 192.0 : 204.0;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: const Color(0xE0101419),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent strip
              Container(width: 3, color: _accent),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMiniMap(size: mapSize),
                      const SizedBox(width: 8),
                      Expanded(child: _buildGpsInfo(loc)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsInfo(LocationData loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD54F),
                  letterSpacing: 0.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            _modeBadge(loc),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          loc.address.isEmpty ? 'Location selected' : loc.address,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB0BEC5),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        _coordRow('LAT', '${loc.latStr}°', const Color(0xFF4FC3F7)),
        const SizedBox(height: 2),
        _coordRow('LNG', '${loc.lngStr}°', const Color(0xFFFFB74D)),
        const SizedBox(height: 4),
        StreamBuilder<String>(
          stream: _timeStream,
          initialData: _currentTime,
          builder: (_, snap) => Text(
            snap.data ?? _currentTime,
            style: const TextStyle(
              fontSize: 8,
              color: Color(0xFF78909C),
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (loc.isCustom) ...[
          const SizedBox(height: 4),
          _customBadge(),
        ],
      ],
    );
  }

  Widget _coordRow(String label, String value, Color valueColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2A3A),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w800,
              color: Color(0xFF78909C),
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: valueColor,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _modeBadge(LocationData loc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accent.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            loc.isCustom
                ? Icons.edit_location_rounded
                : Icons.gps_fixed_rounded,
            color: _accent,
            size: 7,
          ),
          const SizedBox(width: 2),
          Text(
            loc.modeLabel.toUpperCase(),
            style: TextStyle(
              color: _accent,
              fontSize: 6,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMap({required double size}) {
    final loc = widget.locationData;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accent.withValues(alpha: 0.5), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(loc.latitude, loc.longitude),
            zoom: 14,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('overlay'),
              position: LatLng(loc.latitude, loc.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                loc.isCustom
                    ? BitmapDescriptor.hueViolet
                    : BitmapDescriptor.hueAzure,
              ),
            ),
          },
          zoomControlsEnabled: false,
          scrollGesturesEnabled: false,
          tiltGesturesEnabled: false,
          rotateGesturesEnabled: false,
          zoomGesturesEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          myLocationButtonEnabled: false,
          liteModeEnabled: true,
        ),
      ),
    );
  }

  Widget _customBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_rounded, color: Color(0xFF7C3AED), size: 8),
          SizedBox(width: 3),
          Text(
            'CUSTOM LOCATION',
            style: TextStyle(
              color: Color(0xFF7C3AED),
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
