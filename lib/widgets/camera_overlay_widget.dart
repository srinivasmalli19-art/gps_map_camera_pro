// lib/widgets/camera_overlay_widget.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/location_data.dart';
import '../constants/app_constants.dart';

/// Live GPS overlay painted over the camera viewfinder.
/// Adapts its layout automatically when [isLandscape] changes.
class CameraOverlayWidget extends StatefulWidget {
  final LocationData locationData;

  /// Passed from the OrientationBuilder in CameraScreen.
  /// true  → wide landscape panel (GPS left, mini-map right)
  /// false → compact portrait panel (stacked rows, no live map)
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
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: widget.isLandscape ? _buildLandscapePanel() : _buildPortraitPanel(),
    );
  }

  // ── Shared accent colour ───────────────────────────────────

  Color get _accent =>
      widget.locationData.isCustom ? const Color(0xFF9C27B0) : const Color(0xFF00897B);

  // ══════════════════════════════════════════════════════════
  // LANDSCAPE  — wide, single row, mini-map on right
  // ══════════════════════════════════════════════════════════

  Widget _buildLandscapePanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xF2080818),
            const Color(0xE5080818),
            const Color(0x00080818),
          ],
          stops: const [0.0, 0.80, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 2, color: _accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildLandscapeGpsColumn()),
                  const VerticalDivider(color: Colors.white12, width: 14, thickness: 1),
                  _buildMiniMap(width: 90, height: 70),
                ],
              ),
            ),
          ),
          if (widget.locationData.isCustom) _buildCustomBanner(),
        ],
      ),
    );
  }

  Widget _buildLandscapeGpsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // App name + mode badge
        Row(
          children: [
            _appNameText(),
            const SizedBox(width: 8),
            _modeBadge(),
          ],
        ),
        const SizedBox(height: 5),

        // LAT + LNG + ADDRESS on one row
        Row(
          children: [
            _coordChip('LAT', '${widget.locationData.latStr}°', Colors.lightBlueAccent),
            const SizedBox(width: 8),
            _coordChip('LNG', '${widget.locationData.lngStr}°', Colors.orangeAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  _labelTag('ADDR'),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.locationData.address,
                      style: const TextStyle(
                        color: Color(0xFFB2EBF2),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // TIME + disclaimer
        Row(
          children: [
            _labelTag('TIME'),
            const SizedBox(width: 4),
            _liveTime(fontSize: 11),
            const SizedBox(width: 14),
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFF59D), size: 10),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                AppConstants.disclaimer,
                style: TextStyle(
                  color: const Color(0xFFFFF59D).withValues(alpha: 0.85),
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // PORTRAIT  — compact stacked rows, no live map widget
  // ══════════════════════════════════════════════════════════

  Widget _buildPortraitPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xF5080818),
            const Color(0xE8080818),
            const Color(0x00080818),
          ],
          stops: const [0.0, 0.85, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 2, color: _accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: App name + mode badge
                Row(
                  children: [
                    _appNameText(),
                    const SizedBox(width: 8),
                    _modeBadge(),
                  ],
                ),
                const SizedBox(height: 5),

                // Row 2: LAT + LNG side by side
                Row(
                  children: [
                    _coordChip('LAT', '${widget.locationData.latStr}°', Colors.lightBlueAccent),
                    const SizedBox(width: 12),
                    _coordChip('LNG', '${widget.locationData.lngStr}°', Colors.orangeAccent),
                  ],
                ),
                const SizedBox(height: 4),

                // Row 3: ADDRESS
                Row(
                  children: [
                    _labelTag('ADDR'),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.locationData.address,
                        style: const TextStyle(
                          color: Color(0xFFB2EBF2),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Row 4: TIME + disclaimer
                Row(
                  children: [
                    _labelTag('TIME'),
                    const SizedBox(width: 4),
                    _liveTime(fontSize: 11),
                    const SizedBox(width: 10),
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFF59D), size: 10),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        AppConstants.disclaimer,
                        style: TextStyle(
                          color: const Color(0xFFFFF59D).withValues(alpha: 0.8),
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.locationData.isCustom) _buildCustomBanner(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Shared sub-widgets
  // ══════════════════════════════════════════════════════════

  Widget _appNameText() {
    return Text(
      AppConstants.appName,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
      ),
    );
  }

  Widget _modeBadge() {
    final isCustom = widget.locationData.isCustom;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isCustom ? const Color(0xCC6A1B9A) : const Color(0xCC00695C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCustom
              ? Colors.purple.shade200.withValues(alpha: 0.5)
              : Colors.teal.shade200.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCustom ? Icons.edit_location_rounded : Icons.gps_fixed,
            color: Colors.white,
            size: 9,
          ),
          const SizedBox(width: 3),
          Text(
            widget.locationData.modeLabel.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coordChip(String label, String value, Color valueColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _labelTag(label),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            letterSpacing: 0.3,
            shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
      ],
    );
  }

  Widget _labelTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _liveTime({required double fontSize}) {
    return StreamBuilder<String>(
      stream: _timeStream,
      initialData: _currentTime,
      builder: (_, snap) => Text(
        snap.data ?? _currentTime,
        style: TextStyle(
          color: const Color(0xFFB2EBF2),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
    );
  }

  Widget _buildMiniMap({required double width, required double height}) {
    final loc = widget.locationData;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: loc.isCustom ? Colors.purple.shade300 : Colors.teal.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6.5),
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
        ),
        const SizedBox(height: 2),
        Text(
          'MAP PREVIEW',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 6.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xDD4A0072), Color(0xDD6A1B9A)]),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_rounded, color: Colors.white, size: 11),
          const SizedBox(width: 6),
          Text(
            AppConstants.customWatermark,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.warning_rounded, color: Colors.white, size: 11),
        ],
      ),
    );
  }
}
