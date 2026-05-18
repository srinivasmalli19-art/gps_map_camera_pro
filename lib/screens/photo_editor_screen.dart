// lib/screens/photo_editor_screen.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import '../utils/app_storage.dart';

enum _FilterType { none, grayscale, sepia, vivid, cool }

/// Full-screen photo editor with brightness/contrast/saturation sliders,
/// rotation, preset filters, and crop (via image_cropper / uCrop on Android).
/// Returns the new saved file path on save, null if cancelled.
class PhotoEditorScreen extends StatefulWidget {
  final String imagePath;
  const PhotoEditorScreen({super.key, required this.imagePath});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  late String _currentPath;

  // Sliders: each is in range [-0.5, 0.5], 0 = no change
  double _brightness = 0.0;
  double _contrast   = 0.0;
  double _saturation = 0.0;

  // Rotation in degrees (accumulates; 0 / 90 / 180 / 270)
  int _rotationDeg = 0;

  _FilterType _filter = _FilterType.none;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.imagePath;
  }

  // ── Color filter helpers ──────────────────────────────────

  /// Returns the base preset filter matrix (null = identity / skip layer).
  ColorFilter? get _baseFilter {
    switch (_filter) {
      case _FilterType.grayscale:
        return const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]);
      case _FilterType.sepia:
        return const ColorFilter.matrix([
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0,     0,     0,     1, 0,
        ]);
      case _FilterType.vivid:
        // Warmer + boosted saturation
        return ColorFilter.matrix(_buildMatrix(s: 1.35, tintR: 12, tintB: -8));
      case _FilterType.cool:
        // Cooler blue tint
        return ColorFilter.matrix(_buildMatrix(s: 1.1, tintR: -12, tintB: 25));
      case _FilterType.none:
        return null;
    }
  }

  /// Returns the user-adjustment matrix (brightness + contrast + saturation).
  ColorFilter? get _adjustmentFilter {
    if (_brightness == 0 && _contrast == 0 && _saturation == 0) return null;
    return ColorFilter.matrix(_buildMatrix(
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
    ));
  }

  /// Composes saturation × contrast × brightness into one 4×5 matrix.
  /// [brightness] ∈ [-0.5, 0.5]; [contrast] ∈ [-0.5, 0.5];
  /// [saturation] ∈ [-0.5, 0.5]; [s] is a raw scale override;
  /// tints add constant values (0–255) to R/B channels.
  List<double> _buildMatrix({
    double brightness = 0.0,
    double contrast   = 0.0,
    double saturation = 0.0,
    double s          = -1,  // raw saturation scale (-1 = use saturation param)
    double tintR      = 0.0,
    double tintB      = 0.0,
  }) {
    final sat = (s >= 0) ? s : (1.0 + saturation * 2.0).clamp(0.0, 3.0);
    final c   = (1.0 + contrast   * 2.0).clamp(0.0, 3.0);
    final bt  = brightness * 255.0;

    const lr = 0.213;
    const lg = 0.715;
    const lb = 0.072;

    final rr = c * (sat + lr * (1 - sat));
    final rg = c * (lg * (1 - sat));
    final rb = c * (lb * (1 - sat));
    final gr = c * (lr * (1 - sat));
    final gg = c * (sat + lg * (1 - sat));
    final gb = c * (lb * (1 - sat));
    final br2 = c * (lr * (1 - sat));
    final bg  = c * (lg * (1 - sat));
    final bb  = c * (sat + lb * (1 - sat));

    final tr = (1 - c) * 128.0 + bt + tintR;
    final tg = (1 - c) * 128.0 + bt;
    final tb = (1 - c) * 128.0 + bt + tintB;

    return [
      rr,  rg,  rb,  0, tr,
      gr,  gg,  gb,  0, tg,
      br2, bg,  bb,  0, tb,
      0,   0,   0,   1, 0,
    ];
  }

  // ── Preview ───────────────────────────────────────────────

  Widget _buildPreview() {
    Widget image = Image.file(
      File(_currentPath),
      key: ValueKey(_currentPath),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white30, size: 64),
      ),
    );

    if (_rotationDeg != 0) {
      image = Transform.rotate(
        angle: _rotationDeg * math.pi / 180,
        child: image,
      );
    }

    final base = _baseFilter;
    if (base != null) image = ColorFiltered(colorFilter: base, child: image);

    final adj = _adjustmentFilter;
    if (adj != null) image = ColorFiltered(colorFilter: adj, child: image);

    return Container(
      color: const Color(0xFF0D0D0D),
      child: Center(child: image),
    );
  }

  // ── Crop ──────────────────────────────────────────────────

  Future<void> _cropImage() async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _currentPath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 95,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: const Color(0xFF1E2A3A),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop Photo'),
        ],
      );
      if (cropped != null && mounted) {
        setState(() => _currentPath = cropped.path);
      }
    } catch (e) {
      _snack('Crop failed: $e', Colors.red);
    }
  }

  // ── Save ──────────────────────────────────────────────────

  Future<void> _saveEdits() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final rawBytes = await File(_currentPath).readAsBytes();
      img.Image? image = img.decodeJpg(rawBytes);
      if (image == null) {
        _snack('Could not decode image', Colors.red);
        return;
      }

      // 1. Rotation
      if (_rotationDeg != 0) {
        image = img.copyRotate(image, angle: _rotationDeg.toDouble());
      }

      // 2. Base filter
      switch (_filter) {
        case _FilterType.grayscale:
          image = img.grayscale(image);
          break;
        case _FilterType.sepia:
          image = img.sepia(image);
          break;
        case _FilterType.vivid:
          image = img.adjustColor(image, saturation: 0.35);
          break;
        case _FilterType.cool:
          image = img.adjustColor(image, saturation: 0.1);
          break;
        case _FilterType.none:
          break;
      }

      // 3. User adjustments (convert [-0.5, 0.5] to image-pkg [-1, 1])
      if (_brightness != 0 || _contrast != 0 || _saturation != 0) {
        image = img.adjustColor(
          image,
          brightness: _brightness * 2,
          contrast:   _contrast   * 2,
          saturation: _saturation * 2,
        );
      }

      // 4. Save to app folder
      final appDir = await AppStorage.getAppDirectory();
      if (appDir == null) {
        _snack('Cannot access storage', Colors.red);
        return;
      }
      final newPath = '${appDir.path}/${AppStorage.generateFileName()}';
      await File(newPath).writeAsBytes(img.encodeJpg(image, quality: 95));

      if (mounted) Navigator.pop(context, newPath);
    } catch (e) {
      debugPrint('[PhotoEditor] $e');
      _snack('Save failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Reset ─────────────────────────────────────────────────

  void _resetAll() => setState(() {
        _brightness  = 0;
        _contrast    = 0;
        _saturation  = 0;
        _rotationDeg = 0;
        _filter      = _FilterType.none;
        _currentPath = widget.imagePath;
      });

  // ── Helpers ───────────────────────────────────────────────

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(child: _buildPreview()),
          _buildControlsPanel(),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            _iconBtn(Icons.close_rounded, () => Navigator.pop(context)),
            const Expanded(
              child: Text(
                'Edit Photo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _isSaving
                ? const SizedBox(
                    width: 56,
                    height: 36,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                          color: Color(0xFF4FC3F7), strokeWidth: 2.5),
                    ),
                  )
                : GestureDetector(
                    onTap: _saveEdits,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4FC3F7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // ── Controls panel ────────────────────────────────────────

  Widget _buildControlsPanel() {
    return Container(
      color: const Color(0xFF0D1117),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(color: Color(0xFF1A2232), height: 1),
            _buildFilterRow(),
            const Divider(color: Color(0xFF1A2232), height: 1),
            _buildSlider(
              'Brightness', _brightness, Icons.brightness_6_rounded,
              const Color(0xFFFFD54F),
              (v) => setState(() => _brightness = v),
            ),
            _buildSlider(
              'Contrast', _contrast, Icons.contrast_rounded,
              const Color(0xFF80CBC4),
              (v) => setState(() => _contrast = v),
            ),
            _buildSlider(
              'Saturation', _saturation, Icons.palette_rounded,
              const Color(0xFFCE93D8),
              (v) => setState(() => _saturation = v),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  // ── Filter row ────────────────────────────────────────────

  Widget _buildFilterRow() {
    final items = [
      (_FilterType.none,      'Normal',    Icons.filter_none_rounded),
      (_FilterType.grayscale, 'B&W',       Icons.filter_b_and_w_rounded),
      (_FilterType.sepia,     'Sepia',     Icons.photo_filter_rounded),
      (_FilterType.vivid,     'Vivid',     Icons.wb_sunny_rounded),
      (_FilterType.cool,      'Cool',      Icons.ac_unit_rounded),
    ];

    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (type, label, icon) = items[i];
          final sel = _filter == type;
          return GestureDetector(
            onTap: () => setState(() => _filter = type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? const Color(0xFF4FC3F7).withValues(alpha: 0.18)
                    : const Color(0xFF1A2232),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel
                      ? const Color(0xFF4FC3F7)
                      : Colors.white.withValues(alpha: 0.1),
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      color: sel
                          ? const Color(0xFF4FC3F7)
                          : Colors.white38,
                      size: 14),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: sel
                          ? const Color(0xFF4FC3F7)
                          : Colors.white38,
                      fontSize: 12,
                      fontWeight:
                          sel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Slider row ────────────────────────────────────────────

  Widget _buildSlider(
    String label,
    double value,
    IconData icon,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    final pct = (value * 200).round();
    final sign = value > 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          SizedBox(
            width: 74,
            child: Text(
              label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.2),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.15),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value,
                min: -0.5,
                max: 0.5,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$sign$pct%',
              style: TextStyle(
                color: value == 0 ? Colors.white24 : color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom actions ────────────────────────────────────────

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionChip(Icons.rotate_left_rounded, 'Rotate L',
              const Color(0xFFFFB74D), () {
            setState(() => _rotationDeg = (_rotationDeg - 90 + 360) % 360);
          }),
          _actionChip(Icons.rotate_right_rounded, 'Rotate R',
              const Color(0xFFFFB74D), () {
            setState(() => _rotationDeg = (_rotationDeg + 90) % 360);
          }),
          _actionChip(
              Icons.crop_rounded, 'Crop', const Color(0xFF4FC3F7), _cropImage),
          _actionChip(Icons.restart_alt_rounded, 'Reset', Colors.redAccent,
              _resetAll),
        ],
      ),
    );
  }

  Widget _actionChip(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
