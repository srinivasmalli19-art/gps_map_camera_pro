// lib/widgets/camera_overlay_widget.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/location_data.dart';
import '../constants/app_constants.dart';

/// White card GPS overlay — sits at the bottom of the camera viewfinder.
/// Returns the panel widget directly (no internal Positioned);
/// camera_screen.dart wraps it with Positioned.
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

  @override
  Widget build(BuildContext context) {
    return widget.isLandscape ? _buildLandscapePanel() : _buildPortraitPanel();
  }

  Color get _accent =>
      widget.locationData.isCustom
          ? const Color(0xFF7C3AED)
          : const Color(0xFF2E7D32);

  // ── Portrait — white card ────────────────────────────────

  Widget _buildPortraitPanel() {
    final loc = widget.locationData;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mini map
              _buildMiniMap(size: 80),
              const SizedBox(width: 12),
              // GPS info
              Expanded(child: _buildGpsInfo(loc)),
            ],
          ),
          if (loc.isCustom) _buildCustomBanner(),
        ],
      ),
    );
  }

  // ── Landscape — wide white card ──────────────────────────

  Widget _buildLandscapePanel() {
    final loc = widget.locationData;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildMiniMap(size: 70),
              const SizedBox(width: 14),
              Expanded(child: _buildGpsInfo(loc)),
            ],
          ),
          if (loc.isCustom) _buildCustomBanner(),
        ],
      ),
    );
  }

  // ── Shared sub-widgets ───────────────────────────────────

  Widget _buildGpsInfo(LocationData loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // App name + mode badge row
        Row(
          children: [
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 6),
            _modeBadge(loc),
          ],
        ),
        const SizedBox(height: 4),

        // Address
        Text(
          loc.address.isEmpty ? 'Location selected' : loc.address,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),

        // Coordinates row
        Row(
          children: [
            _coordText('LAT', '${loc.latStr}°', Colors.blue.shade700),
            const SizedBox(width: 12),
            _coordText('LNG', '${loc.lngStr}°', Colors.orange.shade700),
          ],
        ),
        const SizedBox(height: 3),

        // Time
        StreamBuilder<String>(
          stream: _timeStream,
          initialData: _currentTime,
          builder: (_, snap) => Text(
            snap.data ?? _currentTime,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6B7280),
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _coordText(String label, String value, Color valueColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: valueColor,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _modeBadge(LocationData loc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            loc.isCustom
                ? Icons.edit_location_rounded
                : Icons.gps_fixed_rounded,
            color: _accent,
            size: 8,
          ),
          const SizedBox(width: 3),
          Text(
            loc.modeLabel.toUpperCase(),
            style: TextStyle(
              color: _accent,
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accent.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.5),
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

  Widget _buildCustomBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_rounded, color: Color(0xFF7C3AED), size: 11),
          SizedBox(width: 6),
          Text(
            AppConstants.customWatermark,
            style: TextStyle(
              color: Color(0xFF7C3AED),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(width: 6),
          Icon(Icons.warning_rounded, color: Color(0xFF7C3AED), size: 11),
        ],
      ),
    );
  }
}
