// lib/screens/camera_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../models/location_data.dart';
import '../utils/image_processor.dart';
import '../utils/app_storage.dart';
import '../widgets/camera_overlay_widget.dart';
import 'photo_preview_screen.dart';
import 'gallery_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // ── Camera State ──────────────────────────────────────────
  List<CameraDescription>? _cameras;
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _hasCameraPermission = false;
  int _currentCameraIndex = 0;

  // ── Capture State ─────────────────────────────────────────
  bool _isCapturing = false;
  bool _showCaptureFlash = false;

  // ── Settings ──────────────────────────────────────────────
  FlashMode _flashMode = FlashMode.off;
  bool _showGrid = false;

  // ── Gallery thumbnail ─────────────────────────────────────
  String? _lastPhotoPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadLastPhoto();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _reinitCamera(ctrl.description);
    }
  }

  // ── Init ──────────────────────────────────────────────────

  Future<void> _loadLastPhoto() async {
    final images = await AppStorage.listImages();
    if (mounted && images.isNotEmpty) {
      setState(() => _lastPhotoPath = images.first.path);
    }
  }

  Future<void> _initCamera() async {
    // Request camera permission
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      if (mounted) setState(() { _hasCameraPermission = false; _isInitialized = false; });
      return;
    }

    // Request storage permission (non-blocking — still open camera if denied)
    await AppStorage.requestStoragePermission();

    if (mounted) setState(() => _hasCameraPermission = true);

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;
      await _startCamera(_cameras![_currentCameraIndex]);
    } catch (e) {
      debugPrint('[CameraScreen] Init error: $e');
    }
  }

  Future<void> _startCamera(CameraDescription description) async {
    final ctrl = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _cameraController = ctrl;

    try {
      await ctrl.initialize();
      try {
        await ctrl.setFlashMode(_flashMode);
      } catch (_) {
        // Flash not supported on this platform/camera (e.g. web, front cam)
      }
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('[CameraScreen] Start camera error: $e');
    }
  }

  Future<void> _reinitCamera(CameraDescription description) async {
    await _cameraController?.dispose();
    _cameraController = null;
    setState(() => _isInitialized = false);
    await _startCamera(description);
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    setState(() { _isInitialized = false; _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length; });
    await _cameraController?.dispose();
    _cameraController = null;
    await _startCamera(_cameras![_currentCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    final modes = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = modes[(modes.indexOf(_flashMode) + 1) % modes.length];
    setState(() => _flashMode = next);
    try { await _cameraController?.setFlashMode(next); } catch (_) {}
  }

  // ── Capture ───────────────────────────────────────────────

  Future<void> _capturePhoto() async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized || _isCapturing) return;

    final locationData = context.read<LocationProvider>().locationData;
    if (locationData == null) return;

    setState(() => _isCapturing = true);

    // White flash effect
    setState(() => _showCaptureFlash = true);
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _showCaptureFlash = false);

    try {
      final picture = await ctrl.takePicture();
      if (!mounted) return;

      // Show processing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildProcessingDialog(),
      );

      // Process image (EXIF fix + overlay + save to app folder + Gal)
      final savedPath = await ImageProcessor.processAndSave(
        picture.path,
        locationData,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close processing dialog

      if (savedPath != null) {
        // Update gallery thumbnail
        setState(() => _lastPhotoPath = savedPath);

        // Navigate to in-app preview
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) =>
                PhotoPreviewScreen(imagePath: savedPath),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 280),
          ),
        );
      } else {
        _showSnackbar('Failed to save photo — check storage permissions',
            Colors.redAccent);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackbar('Capture failed: $e', Colors.red);
      }
    }

    if (mounted) setState(() => _isCapturing = false);
  }

  void _openGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GalleryScreen()),
    ).then((_) => _loadLastPhoto());
  }

  // ── UI Helpers ────────────────────────────────────────────

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _buildProcessingDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2A3A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF4FC3F7), strokeWidth: 3),
            SizedBox(height: 20),
            Text('Processing Photo…',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Fixing orientation & burning GPS overlay',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ── Main Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locationData = context.watch<LocationProvider>().locationData;

    if (locationData == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No location data available',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),
          if (_isInitialized) CameraOverlayWidget(locationData: locationData),
          if (_showGrid) _buildGridLines(),
          if (_showCaptureFlash)
            Container(color: Colors.white.withValues(alpha: 0.7)),
          _buildTopBar(locationData),
          _buildBottomControls(),
          if (!_hasCameraPermission) _buildNoPermissionOverlay(),
        ],
      ),
    );
  }

  // ── Camera Preview ────────────────────────────────────────

  Widget _buildCameraPreview() {
    if (!_isInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4FC3F7)),
              SizedBox(height: 16),
              Text('Initializing Camera…',
                  style: TextStyle(color: Colors.white60, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize!.height,
          height: _cameraController!.value.previewSize!.width,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────

  Widget _buildTopBar(LocationData locationData) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _iconButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.pop(context)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: locationData.isCustom
                      ? const Color(0xCC6A1B9A)
                      : const Color(0xCC00695C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      locationData.isCustom
                          ? Icons.edit_location_rounded
                          : Icons.gps_fixed_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      locationData.modeLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _iconButton(icon: _flashIcon, onTap: _toggleFlash),
              const SizedBox(width: 8),
              _iconButton(
                icon: _showGrid
                    ? Icons.grid_on_rounded
                    : Icons.grid_off_rounded,
                onTap: () => setState(() => _showGrid = !_showGrid),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 20),
      ),
    );
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.off:    return Icons.flash_off_rounded;
      case FlashMode.auto:   return Icons.flash_auto_rounded;
      case FlashMode.always: return Icons.flash_on_rounded;
      default:               return Icons.flash_off_rounded;
    }
  }

  // ── Bottom Controls ───────────────────────────────────────

  Widget _buildBottomControls() {
    final hasMultipleCameras = _cameras != null && _cameras!.length > 1;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(30, 20, 30, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Left: gallery thumbnail ──
              SizedBox(
                width: 54,
                height: 54,
                child: _buildGalleryThumb(),
              ),

              // ── Center: shutter ──
              GestureDetector(
                onTap: _capturePhoto,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: _isCapturing ? 68 : 76,
                  height: _isCapturing ? 68 : 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCapturing ? Colors.grey.shade300 : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6), width: 3),
                  ),
                  child: _isCapturing
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                              color: Colors.black54, strokeWidth: 2.5),
                        )
                      : const Icon(Icons.camera_rounded,
                          color: Colors.black87, size: 34),
                ),
              ),

              // ── Right: flip (if available) or info ──
              SizedBox(
                width: 54,
                height: 54,
                child: hasMultipleCameras
                    ? _sideButton(
                        icon: Icons.flip_camera_ios_rounded,
                        label: 'Flip',
                        onTap: _switchCamera,
                      )
                    : _sideButton(
                        icon: Icons.info_outline_rounded,
                        label: 'Info',
                        onTap: _showInfoDialog,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Thumbnail of last photo, or a gallery icon if none exist yet.
  Widget _buildGalleryThumb() {
    return GestureDetector(
      onTap: _openGallery,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _lastPhotoPath != null && File(_lastPhotoPath!).existsSync()
              ? Image.file(
                  File(_lastPhotoPath!),
                  fit: BoxFit.cover,
                  width: 54,
                  height: 54,
                  cacheWidth: 108,
                  cacheHeight: 108,
                )
              : Container(
                  width: 54,
                  height: 54,
                  color: Colors.black.withValues(alpha: 0.45),
                  child: const Icon(Icons.photo_library_outlined,
                      color: Colors.white70, size: 24),
                ),
        ),
      ),
    );
  }

  Widget _sideButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    final loc = context.read<LocationProvider>().locationData;
    if (loc == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Location Info',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoTile(Icons.gps_fixed_rounded, 'Latitude',
                '${loc.latitude.toStringAsFixed(6)}°'),
            _infoTile(Icons.gps_fixed_rounded, 'Longitude',
                '${loc.longitude.toStringAsFixed(6)}°'),
            _infoTile(Icons.location_city_rounded, 'Address', loc.address),
            _infoTile(
                loc.isCustom ? Icons.edit_location : Icons.wifi_tethering,
                'Mode',
                loc.modeLabel),
            if (loc.isCustom)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  '"Custom Location Used" watermark will appear on your captured photo.',
                  style:
                      TextStyle(color: Colors.purpleAccent, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: Color(0xFF4FC3F7))),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ── Grid ──────────────────────────────────────────────────

  Widget _buildGridLines() {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GridPainter(),
        size: Size.infinite,
      ),
    );
  }

  // ── No Permission ─────────────────────────────────────────

  Widget _buildNoPermissionOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Colors.white54, size: 64),
            const SizedBox(height: 20),
            const Text('Camera Permission Required',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text(
              'Please allow camera access\nto use GPS Map Camera Pro',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FC3F7),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.settings_rounded, color: Colors.white),
              label: const Text('Open Settings',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => openAppSettings(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid Painter ──────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.8;

    for (int i = 1; i <= 2; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final center = Offset(size.width / 2, size.height / 2);
    final crossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    canvas.drawLine(
        center.translate(-12, 0), center.translate(12, 0), crossPaint);
    canvas.drawLine(
        center.translate(0, -12), center.translate(0, 12), crossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
