// lib/widgets/camera_overlay_widget.dart
//
// This widget is rendered as a visual overlay ON TOP of the live camera preview.
// It shows GPS info, map preview widget, and watermarks in real-time.
// (Not captured via RepaintBoundary — the actual photo overlay is
//  burned in separately by ImageProcessor using dart:ui Canvas.)

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/location_data.dart';

class CameraOverlayWidget extends StatefulWidget {
  final LocationData locationData;

  const CameraOverlayWidget({super.key, required this.locationData});

  @override
  State<CameraOverlayWidget> createState() => _CameraOverlayWidgetState();
}

class _CameraOverlayWidgetState extends State<CameraOverlayWidget> {
  late String _currentTime;
  late final Stream<String> _timeStream;

  @override
  void initState() {
    super.initState();
    _currentTime = _formatTime(DateTime.now());

    // Update time every second
    _timeStream = Stream.periodic(const Duration(seconds: 1), (_) {
      return _formatTime(DateTime.now());
    });
  }

  String _formatTime(DateTime dt) =>
      DateFormat('dd MMM yyyy   HH:mm:ss').format(dt);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Top Badge Strip ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopStrip(),
        ),

        // ── Bottom Info Panel ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomPanel(),
        ),
      ],
    );
  }

  // ── Top Mode Badge ────────────────────────────────────────

  Widget _buildTopStrip() {
    final isCustom = widget.locationData.isCustom;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
      child: Row(
        children: [
          // App name
          Text(
            'GPS Map Camera Pro',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 4),
              ],
            ),
          ),
          const Spacer(),

          // Mode label badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isCustom
                  ? const Color(0xCC6A1B9A)
                  : const Color(0xCC00695C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCustom
                    ? Colors.purple.shade200.withValues(alpha: 0.5)
                    : Colors.teal.shade200.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCustom ? Icons.edit_location_rounded : Icons.gps_fixed,
                  color: Colors.white,
                  size: 12,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.locationData.modeLabel.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Info Panel ─────────────────────────────────────

  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xF00A0A1A), Color(0xDD0A0A1A), Color(0x000A0A1A)],
          stops: [0.0, 0.85, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Accent line
          Container(
            height: 2,
            color: widget.locationData.isCustom
                ? const Color(0xFF9C27B0)
                : const Color(0xFF00897B),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── GPS Info Column ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _coordinateRow(
                          'LAT', widget.locationData.latStr,
                          Colors.lightBlueAccent),
                      const SizedBox(height: 5),
                      _coordinateRow(
                          'LNG', widget.locationData.lngStr,
                          Colors.orangeAccent),
                      const SizedBox(height: 7),
                      _addressRow(),
                      const SizedBox(height: 5),
                      _timeRow(),
                      const SizedBox(height: 7),
                      _disclaimerRow(),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // ── Map Preview ──
                _buildMapPreview(),
              ],
            ),
          ),

          // Custom Watermark Banner
          if (widget.locationData.isCustom) _buildCustomWatermark(),
        ],
      ),
    );
  }

  Widget _coordinateRow(String label, String value, Color valueColor) {
    return Row(
      children: [
        _labelChip(label),
        const SizedBox(width: 6),
        Text(
          '$value°',
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            letterSpacing: 0.5,
            shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
      ],
    );
  }

  Widget _addressRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelChip('ADDR'),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            widget.locationData.address,
            style: const TextStyle(
              color: Color(0xFFB2EBF2),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black, blurRadius: 3)],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _timeRow() {
    return Row(
      children: [
        _labelChip('TIME'),
        const SizedBox(width: 6),
        StreamBuilder<String>(
          stream: _timeStream,
          initialData: _currentTime,
          builder: (_, snap) => Text(
            snap.data ?? _currentTime,
            style: const TextStyle(
              color: Color(0xFFB2EBF2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              shadows: [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _disclaimerRow() {
    return Row(
      children: [
        const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFFFF59D), size: 12),
        const SizedBox(width: 5),
        Text(
          'For documentation purposes only',
          style: TextStyle(
            color: const Color(0xFFFFF59D).withValues(alpha: 0.9),
            fontSize: 10.5,
            fontStyle: FontStyle.italic,
            shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
      ],
    );
  }

  Widget _labelChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ── Google Maps Mini Preview ──────────────────────────────

  Widget _buildMapPreview() {
    return Column(
      children: [
        Container(
          width: 110,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.locationData.isCustom
                  ? Colors.purple.shade300
                  : Colors.teal.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.5),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  widget.locationData.latitude,
                  widget.locationData.longitude,
                ),
                zoom: 14,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('overlay_marker'),
                  position: LatLng(
                    widget.locationData.latitude,
                    widget.locationData.longitude,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    widget.locationData.isCustom
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
              liteModeEnabled: true, // Lightweight static mode
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'MAP PREVIEW',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // ── Custom Watermark Banner ───────────────────────────────

  Widget _buildCustomWatermark() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xDD4A0072), Color(0xDD6A1B9A)],
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_rounded, color: Colors.white, size: 14),
          SizedBox(width: 8),
          Text(
            'CUSTOM LOCATION USED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.warning_rounded, color: Colors.white, size: 14),
        ],
      ),
    );
  }
}
