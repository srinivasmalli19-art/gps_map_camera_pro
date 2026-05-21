// lib/screens/map_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/geocoding_helper.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import 'camera_screen.dart';

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
      backgroundColor: Colors.white,
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
            compassEnabled: false,
            mapToolbarEnabled: false,
            mapType: MapType.normal,
          ),

          // ── Top bar ──
          _buildTopBar(),

          // ── Hint bubble (no location yet) ──
          if (!_isPanelVisible) _buildHintBubble(),

          // ── Bottom panel (location selected) ──
          if (_isPanelVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _panelSlide,
                child: _buildBottomPanel(),
              ),
            ),

          // ── Zoom controls ──
          _buildZoomControls(),

          // ── Loading overlay ──
          if (_isLoadingAddress) _buildLoadingIndicator(),
        ],
      ),
    );
  }

  // ── Map callbacks ─────────────────────────────────────────

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
    } catch (_) {}
  }

  Future<void> _onMapTapped(LatLng position) async {
    setState(() {
      _selectedLocation = position;
      _isLoadingAddress = true;
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ),
      };
    });

    if (!_isPanelVisible) {
      setState(() => _isPanelVisible = true);
      _panelController.forward();
    }

    final address = await GeocodingHelper.reverseGeocode(
      position.latitude,
      position.longitude,
    );
    if (mounted) {
      setState(() {
        _selectedAddress = address;
        _isLoadingAddress = false;
      });
    }
  }

  // ── UI components ─────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: Color(0xFF333333)),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select Location',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Search or pick a location on map',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _tryGoToCurrentLocation,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.gps_fixed_rounded,
                      size: 18, color: Color(0xFF7C3AED)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHintBubble() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, 0.2),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded, color: Colors.white, size: 18),
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

  Widget _buildBottomPanel() {
    final loc = _selectedLocation;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Selected Location',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const Spacer(),
              if (_isLoadingAddress)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF7C3AED),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Coords + mini map
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loc != null) ...[
                      Text(
                        '${loc.latitude.toStringAsFixed(4)}° N,  ${loc.longitude.toStringAsFixed(4)}° E',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      _isLoadingAddress
                          ? 'Fetching address...'
                          : _selectedAddress.isEmpty
                              ? 'Tap a location on the map'
                              : _selectedAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Mini map thumbnail
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: loc != null
                      ? GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: loc,
                            zoom: 14,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('preview'),
                              position: loc,
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueViolet),
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
                        )
                      : const Icon(Icons.map_rounded,
                          color: Color(0xFF7C3AED), size: 30),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Confirm button
          GestureDetector(
            onTap: (_isLoadingAddress || loc == null) ? null : _proceedToCamera,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: (_isLoadingAddress || loc == null)
                    ? const Color(0xFF9E9E9E)
                    : const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(14),
                boxShadow: (loc != null && !_isLoadingAddress)
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Confirm Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Footer
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFF2E7D32), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Accurate & Reliable — GPS coordinates are embedded in your photo',
                    style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
                  ),
                ),
                Icon(Icons.satellite_alt_rounded,
                    color: Color(0xFF2E7D32), size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      right: 16,
      bottom: _isPanelVisible ? 380 : 100,
      child: Column(
        children: [
          _zoomBtn(Icons.add_rounded, () async {
            final z = await _mapController?.getZoomLevel() ?? 10.0;
            _mapController?.animateCamera(CameraUpdate.zoomTo(z + 1));
          }),
          const SizedBox(height: 8),
          _zoomBtn(Icons.remove_rounded, () async {
            final z = await _mapController?.getZoomLevel() ?? 10.0;
            _mapController?.animateCamera(CameraUpdate.zoomTo(z - 1));
          }),
          const SizedBox(height: 8),
          _zoomBtn(Icons.my_location_rounded, _tryGoToCurrentLocation),
        ],
      ),
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) {
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
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -0.4),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
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

  void _proceedToCamera() {
    if (_selectedLocation == null) return;
    context.read<LocationProvider>().setCustomLocation(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
          _selectedAddress.isEmpty ? 'Unknown Location' : _selectedAddress,
        );
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const CameraScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
