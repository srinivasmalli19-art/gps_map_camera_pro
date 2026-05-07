// lib/screens/map_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/geocoding_helper.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import 'camera_screen.dart';

/// Map Picker Screen — Custom Location Mode (Step 2–5)
/// Allows the user to tap anywhere on Google Maps, see location info,
/// confirm the selection, and proceed to the camera.
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _isLoadingAddress = false;
  bool _isPanelVisible = false;
  Set<Marker> _markers = {};

  // Default camera position — center of India
  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 4.5,
  );

  late AnimationController _panelController;
  late Animation<Offset> _panelSlide;

  @override
  void initState() {
    super.initState();
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _panelController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ──
          GoogleMap(
            initialCameraPosition: _defaultCamera,
            onMapCreated: _onMapCreated,
            onTap: _onMapTapped,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            mapType: MapType.normal,
          ),

          // ── Top Bar ──
          _buildTopBar(),

          // ── Hint Bubble (shown when no location selected) ──
          if (!_isPanelVisible) _buildHintBubble(),

          // ── Location Info Panel ──
          if (_isPanelVisible)
            SlideTransition(
              position: _panelSlide,
              child: _buildInfoPanel(),
            ),

          // ── Zoom Controls ──
          _buildZoomControls(),

          // ── Loading Indicator ──
          if (_isLoadingAddress) _buildLoadingIndicator(),
        ],
      ),
      floatingActionButton: _selectedLocation != null
          ? FloatingActionButton.extended(
              onPressed: _showConfirmDialog,
              backgroundColor: const Color(0xFF6A1B9A),
              elevation: 6,
              icon: const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white),
              label: const Text(
                'Use This Location',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            )
          : null,
    );
  }

  // ── Map Callbacks ─────────────────────────────────────────

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _tryGoToCurrentLocation();
  }

  Future<void> _tryGoToCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 13,
            ),
          ),
        );
      }
    } catch (_) {
      // Silently fail — user can navigate manually
    }
  }

  Future<void> _onMapTapped(LatLng position) async {
    setState(() {
      _selectedLocation = position;
      _isLoadingAddress = true;
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: 'Selected Location',
            snippet:
                '${position.latitude.toStringAsFixed(4)}°, ${position.longitude.toStringAsFixed(4)}°',
          ),
        ),
      };
    });

    if (!_isPanelVisible) {
      _isPanelVisible = true;
      _panelController.forward();
    }

    // Reverse geocode
    final address = await GeocodingHelper.reverseGeocode(
      position.latitude,
      position.longitude,
    );
    setState(() => _selectedAddress = address);

    setState(() => _isLoadingAddress = false);

    // Show marker info window
    _mapController
        ?.showMarkerInfoWindow(const MarkerId('selected_location'));
  }

  // ── UI Components ─────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Color(0xFF333333)),
                  ),
                ),
                const SizedBox(width: 12),

                // Title
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Location on Map',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        'Tap anywhere to place a marker',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Custom badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_location_alt_rounded,
                          color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'CUSTOM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHintBubble() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            margin: const EdgeInsets.only(top: 80),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Tap on the map to select a location',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Positioned(
      bottom: 90,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Panel header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.location_pin,
                      color: Colors.red.shade600, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Selected Location',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                if (_isLoadingAddress)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'CONFIRMED',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Location data rows
            _infoRow(
              icon: Icons.my_location_rounded,
              label: 'Latitude',
              value: _selectedLocation != null
                  ? '${_selectedLocation!.latitude.toStringAsFixed(6)}°'
                  : '—',
              color: const Color(0xFF1565C0),
            ),
            const SizedBox(height: 10),
            _infoRow(
              icon: Icons.my_location_rounded,
              label: 'Longitude',
              value: _selectedLocation != null
                  ? '${_selectedLocation!.longitude.toStringAsFixed(6)}°'
                  : '—',
              color: const Color(0xFFE65100),
            ),
            const SizedBox(height: 10),
            _infoRow(
              icon: Icons.location_city_rounded,
              label: 'Address',
              value: _isLoadingAddress
                  ? 'Getting address...'
                  : _selectedAddress.isEmpty
                      ? '—'
                      : _selectedAddress,
              color: const Color(0xFF2E7D32),
            ),

            const SizedBox(height: 14),

            // Warning banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"Custom Location Used" watermark will be embedded in your photo.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 1),
            SizedBox(
              width: MediaQuery.of(context).size.width - 140,
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF1A1A2E),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      right: 16,
      bottom: _isPanelVisible ? 340 : 120,
      child: Column(
        children: [
          _zoomButton(
            icon: Icons.add_rounded,
            onTap: () async {
              final zoom = await _mapController?.getZoomLevel() ?? 10.0;
              _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    _selectedLocation ??
                        const LatLng(20.5937, 78.9629),
                    zoom + 1,
                  ));
            },
          ),
          const SizedBox(height: 8),
          _zoomButton(
            icon: Icons.remove_rounded,
            onTap: () async {
              final zoom = await _mapController?.getZoomLevel() ?? 10.0;
              _mapController?.animateCamera(
                  CameraUpdate.zoomTo(zoom - 1));
            },
          ),
          const SizedBox(height: 8),
          _zoomButton(
            icon: Icons.my_location_rounded,
            onTap: _tryGoToCurrentLocation,
          ),
        ],
      ),
    );
  }

  Widget _zoomButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF333333)),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -0.4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child:
                      CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Getting address...',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Confirmation Dialog ───────────────────────────────────

  void _showConfirmDialog() {
    if (_selectedLocation == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A3A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Use These Coordinates?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Location summary card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogRow(
                      'Latitude',
                      '${_selectedLocation!.latitude.toStringAsFixed(6)}°'),
                  const SizedBox(height: 8),
                  _dialogRow(
                      'Longitude',
                      '${_selectedLocation!.longitude.toStringAsFixed(6)}°'),
                  const SizedBox(height: 8),
                  _dialogRow('Address',
                      _selectedAddress.isEmpty ? '—' : _selectedAddress),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded,
                      color: Colors.purpleAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                            color: Colors.white70, fontSize: 11.5),
                        children: [
                          TextSpan(
                              text: '"Custom Location Used" ',
                              style: TextStyle(
                                  color: Colors.purpleAccent,
                                  fontWeight: FontWeight.bold)),
                          TextSpan(
                              text:
                                  'watermark will be burned into the photo.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // NO — re-select
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white30),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'No, Re-select',
              style: TextStyle(color: Colors.white70),
            ),
          ),

          // YES — proceed to camera
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _proceedToCamera();
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 16),
                SizedBox(width: 6),
                Text('Yes, Proceed',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:  ',
          style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _proceedToCamera() {
    // Set custom location in provider and navigate to camera
    context.read<LocationProvider>().setCustomLocation(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
          _selectedAddress.isEmpty ? 'Unknown Location' : _selectedAddress,
        );

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const CameraScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
