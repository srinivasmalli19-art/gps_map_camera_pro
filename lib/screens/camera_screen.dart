// lib/screens/camera_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../models/location_data.dart';
import '../utils/image_processor.dart';
import '../utils/app_storage.dart';
import '../widgets/camera_overlay_widget.dart';
import 'gallery_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // ── Camera ────────────────────────────────────────────────
  List<CameraDescription>? _cameras;
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _hasCameraPermission = false;
  int _currentCameraIndex = 0;

  // ── Capture ───────────────────────────────────────────────
  bool _isCapturing = false;
  bool _showCaptureFlash = false;
  bool _processingDialogOpen = false;

  // ── EXIF orientation — plain field, never triggers setState ──
  // WHY: calling setState() every time the camera fires a value-change
  // event (which happens on every orientation tick) rebuilds the entire
  // widget tree and causes the preview to flash. We only need this value
  // at the moment of capture, so we read it directly without rebuilding.
  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;

  // ── Pinch-to-zoom ─────────────────────────────────────────
  double _currentZoom  = 1.0;
  double _baseZoom     = 1.0; // zoom level at start of each pinch gesture
  double _minZoom      = 1.0;
  double _maxZoom      = 8.0;
  bool   _showZoomBadge = false;
  Timer? _zoomBadgeTimer;

  // ── Settings ──────────────────────────────────────────────
  FlashMode _flashMode = FlashMode.off;
  bool _showGrid = false;

  // ── Gallery thumbnail ─────────────────────────────────────
  String? _lastPhotoPath;

  static const double _landscapeOverlayH = 100.0;
  static const double _portraitOverlayH  = 120.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadLastPhoto();
  }

  @override
  void dispose() {
    _zoomBadgeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.removeListener(_onCameraValueChanged);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.removeListener(_onCameraValueChanged);
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _reinitCamera(ctrl.description);
    }
  }

  // ── Orientation tracking — NO setState ───────────────────
  // Simply cache the orientation for use at capture time.
  // This avoids a full widget-tree rebuild on every camera event.
  void _onCameraValueChanged() {
    if (!mounted) return;
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    _deviceOrientation = ctrl.value.deviceOrientation;
  }

  // ── Camera lifecycle ──────────────────────────────────────

  Future<void> _loadLastPhoto() async {
    final images = await AppStorage.listImages();
    if (mounted && images.isNotEmpty) {
      setState(() => _lastPhotoPath = images.first.path);
    }
  }

  Future<void> _initCamera() async {
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      if (mounted) {
        setState(() {
          _hasCameraPermission = false;
          _isInitialized = false;
        });
      }
      return;
    }
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
      ctrl.addListener(_onCameraValueChanged);
      try { await ctrl.setFlashMode(_flashMode); } catch (_) {}

      // Fetch zoom range for this camera
      try {
        _minZoom    = await ctrl.getMinZoomLevel();
        _maxZoom    = await ctrl.getMaxZoomLevel();
        _currentZoom = 1.0;
      } catch (_) {}

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('[CameraScreen] Start camera error: $e');
    }
  }

  Future<void> _reinitCamera(CameraDescription description) async {
    _cameraController?.removeListener(_onCameraValueChanged);
    await _cameraController?.dispose();
    _cameraController = null;
    if (mounted) setState(() => _isInitialized = false);
    await _startCamera(description);
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _cameraController?.removeListener(_onCameraValueChanged);
    setState(() {
      _isInitialized = false;
      _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;
    });
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

  // ── Pinch-to-zoom ─────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    // Only handle true pinch — ignore single-finger pan
    if (details.pointerCount < 2) return;
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    final newZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    if ((newZoom - _currentZoom).abs() < 0.01) return;

    _currentZoom = newZoom;
    try { await ctrl.setZoomLevel(newZoom); } catch (_) {}

    // Show badge, then hide after 2 s of inactivity
    _zoomBadgeTimer?.cancel();
    setState(() => _showZoomBadge = true);
    _zoomBadgeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showZoomBadge = false);
    });
  }

  // ── Capture — auto-save, no navigation ───────────────────

  Future<void> _capturePhoto() async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized || _isCapturing) return;

    final locationData = context.read<LocationProvider>().locationData;
    if (locationData == null) return;

    setState(() { _isCapturing = true; _showCaptureFlash = true; });
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _showCaptureFlash = false);

    try {
      // Lock EXIF to the current physical orientation before capture
      try { await ctrl.lockCaptureOrientation(_deviceOrientation); } catch (_) {}
      final picture = await ctrl.takePicture();
      try { await ctrl.unlockCaptureOrientation(); } catch (_) {}

      if (!mounted) return;
      _showProcessingOverlay();

      final savedPath = await ImageProcessor.processAndSave(
        picture.path,
        locationData,
      );

      if (!mounted) return;
      _hideProcessingOverlay();

      if (savedPath != null) {
        setState(() => _lastPhotoPath = savedPath);
        _showSnackbar('Saved to gallery ✓', const Color(0xFF43A047));
      } else {
        _showSnackbar('Save failed — check storage permissions', Colors.redAccent);
      }
    } catch (e) {
      if (mounted) {
        _hideProcessingOverlay();
        _showSnackbar('Capture error: $e', Colors.red);
      }
    }
    if (mounted) setState(() => _isCapturing = false);
  }

  void _showProcessingOverlay() {
    if (_processingDialogOpen || !mounted) return;
    _processingDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2A3A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4FC3F7), strokeWidth: 3),
              SizedBox(height: 16),
              Text('Saving…',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Adding GPS overlay',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  void _hideProcessingOverlay() {
    if (!_processingDialogOpen || !mounted) return;
    _processingDialogOpen = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _openGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GalleryScreen()),
    ).then((_) => _loadLastPhoto());
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locationData = context.watch<LocationProvider>().locationData;

    if (locationData == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('No location data', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          final overlayH = isLandscape ? _landscapeOverlayH : _portraitOverlayH;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Layer 1: Camera preview with pinch-to-zoom
              GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: _buildCameraPreview(),
              ),

              // Layer 2: GPS overlay
              if (_isInitialized)
                CameraOverlayWidget(
                  locationData: locationData,
                  isLandscape: isLandscape,
                ),

              // Layer 3: Rule-of-thirds grid
              if (_showGrid) _buildGridLines(),

              // Layer 4: Shutter flash
              if (_showCaptureFlash)
                const ColoredBox(color: Color(0xA8FFFFFF)),

              // Layer 5: Zoom badge (fades out 2 s after last pinch)
              if (_isInitialized) _buildZoomBadge(),

              // Layer 6: Top bar
              _buildTopBar(locationData, isLandscape),

              // Layer 7: Capture controls (layout differs by orientation)
              if (isLandscape)
                _buildLandscapeControls(overlayH)
              else
                _buildPortraitControls(overlayH),

              // Layer 8: No-permission wall
              if (!_hasCameraPermission) _buildNoPermissionOverlay(),
            ],
          );
        },
      ),
    );
  }

  // ── Camera preview ────────────────────────────────────────
  //
  // WHY previewSize.height as width / previewSize.width as height:
  //
  // The camera sensor reports dimensions in its native landscape orientation
  // (e.g. 1920 × 1080). CameraPreview applies an internal rotation transform
  // to match the device orientation, so the "effective" display size is the
  // sensor dimensions flipped. Using (height × width) gives FittedBox a
  // portrait-first bounding box that remains CONSTANT across portrait and
  // landscape mode — meaning the layout never changes during rotation, which
  // eliminates the one-frame layout gap that causes the preview to flash.
  //
  // CameraPreview handles the rest: it rotates the video surface to be
  // upright in both portrait and landscape automatically.

  Widget _buildCameraPreview() {
    if (!_isInitialized || _cameraController == null) {
      return const ColoredBox(color: Colors.black);
    }
    final ps = _cameraController!.value.previewSize!;

    // RepaintBoundary isolates the GPU texture repaint from all overlay repaints.
    // Without it, every UI setState (flash, snackbar, zoom badge …) forces the
    // camera texture to re-composite even though it hasn't changed.
    return RepaintBoundary(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width:  ps.height, // flipped intentionally — see note above
            height: ps.width,
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }

  // ── Zoom badge ────────────────────────────────────────────

  Widget _buildZoomBadge() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _showZoomBadge ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Align(
            alignment: const Alignment(0, -0.15), // slightly above centre
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Text(
                '${_currentZoom.toStringAsFixed(1)}×',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────

  Widget _buildTopBar(LocationData locationData, bool isLandscape) {
    return Positioned(
      top: 0,
      left: 0,
      right: isLandscape ? 88 : 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _iconButton(Icons.close_rounded, () => Navigator.pop(context)),
              const SizedBox(width: 10),
              _gpsModeBadge(locationData),
              const Spacer(),
              _iconButton(_flashIcon, _toggleFlash),
              const SizedBox(width: 8),
              _iconButton(
                _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                () => setState(() => _showGrid = !_showGrid),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Landscape controls — right column ─────────────────────

  Widget _buildLandscapeControls(double overlayH) {
    final hasMultiple = (_cameras?.length ?? 0) > 1;
    return Positioned(
      right: 0, top: 0, bottom: overlayH,
      child: SafeArea(
        child: Container(
          width: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [Colors.black.withValues(alpha: 0.60), Colors.transparent],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _galleryThumb(),
              const SizedBox(height: 14),
              _shutterButton(),
              const SizedBox(height: 14),
              hasMultiple
                  ? _sideButton(Icons.flip_camera_ios_rounded, 'Flip', _switchCamera)
                  : _sideButton(Icons.info_outline_rounded, 'Info', _showInfoDialog),
            ],
          ),
        ),
      ),
    );
  }

  // ── Portrait controls — bottom row ────────────────────────

  Widget _buildPortraitControls(double overlayH) {
    final hasMultiple = (_cameras?.length ?? 0) > 1;
    return Positioned(
      left: 0, right: 0, bottom: overlayH,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.50), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _galleryThumb(),
            _shutterButton(),
            hasMultiple
                ? _sideButton(Icons.flip_camera_ios_rounded, 'Flip', _switchCamera)
                : _sideButton(Icons.info_outline_rounded, 'Info', _showInfoDialog),
          ],
        ),
      ),
    );
  }

  // ── Shared control widgets ────────────────────────────────

  Widget _shutterButton() {
    return GestureDetector(
      onTap: _capturePhoto,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: _isCapturing ? 62 : 70,
        height: _isCapturing ? 62 : 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isCapturing ? Colors.grey.shade300 : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
        ),
        child: _isCapturing
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 2.5),
              )
            : const Icon(Icons.camera_rounded, color: Colors.black87, size: 30),
      ),
    );
  }

  Widget _galleryThumb() {
    return GestureDetector(
      onTap: _openGallery,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _lastPhotoPath != null && File(_lastPhotoPath!).existsSync()
              ? Image.file(File(_lastPhotoPath!),
                  fit: BoxFit.cover, width: 52, height: 52,
                  cacheWidth: 104, cacheHeight: 104)
              : Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: const Icon(Icons.photo_library_outlined,
                      color: Colors.white70, size: 22),
                ),
        ),
      ),
    );
  }

  Widget _sideButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }

  Widget _gpsModeBadge(LocationData loc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: loc.isCustom ? const Color(0xCC6A1B9A) : const Color(0xCC00695C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            loc.isCustom ? Icons.edit_location_rounded : Icons.gps_fixed_rounded,
            color: Colors.white, size: 12,
          ),
          const SizedBox(width: 4),
          Text(loc.modeLabel,
              style: const TextStyle(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
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

  void _showInfoDialog() {
    final loc = context.read<LocationProvider>().locationData;
    if (loc == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Location Info',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow(Icons.gps_fixed_rounded,     'Latitude',  '${loc.latitude.toStringAsFixed(6)}°'),
            _infoRow(Icons.gps_fixed_rounded,     'Longitude', '${loc.longitude.toStringAsFixed(6)}°'),
            _infoRow(Icons.location_city_rounded, 'Address',   loc.address),
            _infoRow(Icons.my_location_rounded,   'Mode',      loc.modeLabel),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF4FC3F7))),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 15),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildGridLines() {
    return IgnorePointer(
      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
    );
  }

  Widget _buildNoPermissionOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 56),
            const SizedBox(height: 16),
            const Text('Camera Permission Required',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Allow camera access to use GPS Map Camera Pro',
                style: TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FC3F7),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.settings_rounded, color: Colors.white),
              label: const Text('Open Settings',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: openAppSettings,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid painter ──────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.8;
    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(Offset(size.width * i / 3, 0),
          Offset(size.width * i / 3, size.height), paint);
      canvas.drawLine(Offset(0, size.height * i / 3),
          Offset(size.width, size.height * i / 3), paint);
    }
    final center = Offset(size.width / 2, size.height / 2);
    final cp = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    canvas.drawLine(center.translate(-12, 0), center.translate(12, 0), cp);
    canvas.drawLine(center.translate(0, -12), center.translate(0, 12), cp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
