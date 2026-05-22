// lib/utils/image_processor.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../models/location_data.dart';
import '../constants/app_constants.dart';
import 'app_storage.dart';

class ImageProcessor {
  /// Corrects EXIF orientation, composites the GPS overlay, saves to the app
  /// folder and pushes to the system gallery (Pictures/SLC GPS Map Camera Pro/).
  ///
  /// Returns the saved file path on success, null on failure.
  static Future<String?> processAndSave(
    String imagePath,
    LocationData locationData, {
    ui.Image? overlaySnapshot,
  }) async {
    try {
      debugPrint('[ImageProcessor] Processing: $imagePath');

      final appDir = await AppStorage.getAppDirectory();
      if (appDir == null) {
        debugPrint('[ImageProcessor] Could not obtain app directory');
        return null;
      }

      // ── Step 1: Fix EXIF orientation ─────────────────────
      // Primary: flutter_exif_rotation (native, handles all EXIF tags).
      // Fallback: image package bakeOrientation (pure-Dart).
      Uint8List correctedBytes;
      String rotatedFilePath = imagePath;
      try {
        final File rotated =
            await FlutterExifRotation.rotateImage(path: imagePath);
        rotatedFilePath = rotated.path;
        correctedBytes = await rotated.readAsBytes();
        debugPrint('[ImageProcessor] EXIF fixed via flutter_exif_rotation');
      } catch (e) {
        debugPrint('[ImageProcessor] flutter_exif_rotation failed ($e), using bakeOrientation');
        final rawBytes = await File(imagePath).readAsBytes();
        img.Image? decoded = img.decodeJpg(rawBytes);
        if (decoded == null) {
          debugPrint('[ImageProcessor] Failed to decode JPEG');
          return null;
        }
        decoded = img.bakeOrientation(decoded);
        correctedBytes =
            Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
      }

      // ── Step 2: Decode corrected bytes for dart:ui compositing ───────
      final codec = await ui.instantiateImageCodec(correctedBytes);
      final frame = await codec.getNextFrame();
      final cameraImage = frame.image;

      // ── Step 3: Download static map thumbnail (only without snapshot) ───
      ui.Image? mapImage;
      if (overlaySnapshot == null &&
          AppConstants.googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY') {
        mapImage = await _downloadStaticMapImage(locationData);
      }

      // ── Step 4: Composite GPS overlay onto the image ──────────────────
      // When overlaySnapshot is supplied we stamp the exact live-preview widget
      // bitmap onto the photo (WYSIWYG). Otherwise fall back to the canvas-drawn
      // overlay (older behaviour, used when snapshot capture fails).
      final finalImage = overlaySnapshot != null
          ? await _compositeWithSnapshot(cameraImage, overlaySnapshot)
          : await _compositeOverlay(cameraImage, locationData, mapImage);

      // ── Step 5: Encode to JPEG bytes ──────────────────────────────────
      final byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('[ImageProcessor] Failed to encode final image');
        return null;
      }
      final finalBytes = byteData.buffer.asUint8List();

      // ── Step 6: Write to temp file (for Gal) ─────────────────────────
      final tmpDir  = await getTemporaryDirectory();
      final tmpPath = '${tmpDir.path}/${AppStorage.generateFileName()}';
      await File(tmpPath).writeAsBytes(finalBytes);

      // ── Step 7: Copy to app folder ────────────────────────────────────
      final savedPath = '${appDir.path}/${AppStorage.generateFileName()}';
      await File(tmpPath).copy(savedPath);

      // ── Step 8: Push to system gallery ───────────────────────────────
      try {
        await Gal.putImage(tmpPath, album: AppStorage.folderName);
      } catch (e) {
        debugPrint('[ImageProcessor] Gal.putImage failed (non-fatal): $e');
      }

      // ── Step 9: Clean up temp files ───────────────────────────────────
      try {
        await File(tmpPath).delete();
        await File(imagePath).delete();
        if (rotatedFilePath != imagePath) {
          await File(rotatedFilePath).delete();
        }
      } catch (_) {}

      debugPrint('[ImageProcessor] Saved to: $savedPath');
      return savedPath;
    } catch (e, stack) {
      debugPrint('[ImageProcessor] Error: $e\n$stack');
      return null;
    }
  }

  // ── Static map download ───────────────────────────────────

  static Future<ui.Image?> _downloadStaticMapImage(
      LocationData location) async {
    try {
      final url =
          AppConstants.staticMapUrl(location.latitude, location.longitude);
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }
    } catch (e) {
      debugPrint('[ImageProcessor] Static map download failed: $e');
    }
    return null;
  }

  // ── WYSIWYG snapshot compositor ──────────────────────────
  // Scales the captured overlay widget bitmap to the photo width and stamps
  // it at the bottom of the photo. Because the bitmap IS the live preview,
  // the final image looks identical to what the user saw on-screen.

  static Future<ui.Image> _compositeWithSnapshot(
    ui.Image cameraImage,
    ui.Image overlaySnapshot,
  ) async {
    final W = cameraImage.width.toDouble();
    final H = cameraImage.height.toDouble();
    final snapshotW = overlaySnapshot.width.toDouble();
    final snapshotH = overlaySnapshot.height.toDouble();

    // Scale snapshot proportionally so its width matches the photo width.
    final scale   = W / snapshotW;
    final scaledH = snapshotH * scale;
    final overlayY = H - scaledH;

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder, Rect.fromLTWH(0, 0, W, H));

    canvas.drawImage(cameraImage, Offset.zero, Paint());

    // Subtle top gradient so the close / flash buttons stay readable
    final topGradH = H * 0.07;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, topGradH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, topGradH),
          [const Color(0x88000000), const Color(0x00000000)],
        ),
    );

    // Stamp the overlay snapshot — high-quality downscale/upscale
    canvas.drawImageRect(
      overlaySnapshot,
      Rect.fromLTWH(0, 0, snapshotW, snapshotH),
      Rect.fromLTWH(0, overlayY, W, scaledH),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    return picture.toImage(cameraImage.width, cameraImage.height);
  }

  // ── GPS overlay compositor ────────────────────────────────
  // After EXIF correction the image has the correct orientation, so
  // W > H means the photo was taken in landscape and H > W means portrait.
  // The overlay layout adapts accordingly.

  static Future<ui.Image> _compositeOverlay(
    ui.Image cameraImage,
    LocationData location,
    ui.Image? mapImage,
  ) async {
    final W = cameraImage.width.toDouble();
    final H = cameraImage.height.toDouble();
    final isPortrait = H > W;

    // Overlay dimensions — proportionally smaller fraction for portrait
    // because H is larger (e.g., 3264 px vs 2448 px in landscape).
    final double overlayH = isPortrait ? H * 0.20 : H * 0.28;
    final double overlayY = H - overlayH;
    final double pad      = W * 0.028;

    // Font scale: keep text visually similar size regardless of orientation
    final double fScale = isPortrait ? 0.75 : 1.0;

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder, Rect.fromLTWH(0, 0, W, H));

    canvas.drawImage(cameraImage, Offset.zero, Paint());

    // Top gradient strip
    final topGradH = H * 0.07;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, topGradH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, topGradH),
          [const Color(0xBB000000), const Color(0x00000000)],
        ),
    );

    // Overlay background
    canvas.drawRect(
      Rect.fromLTWH(0, overlayY, W, overlayH),
      Paint()..color = const Color(0xEE0A0A1A),
    );

    // Accent line
    final accentColor =
        location.isCustom ? const Color(0xFF9C27B0) : const Color(0xFF00897B);
    canvas.drawRect(
      Rect.fromLTWH(0, overlayY, W, 3),
      Paint()..color = accentColor,
    );

    double textRightBound = W - pad;

    if (mapImage != null) {
      final mapW = W * (isPortrait ? 0.30 : 0.27);
      final mapH = overlayH - pad * 2;
      final mapX = W - mapW - pad;
      final mapY = overlayY + pad;

      // Map border shadow
      canvas.drawRect(
        Rect.fromLTWH(mapX - 2, mapY - 2, mapW + 4, mapH + 4),
        Paint()..color = Colors.black.withValues(alpha: 0.4),
      );
      canvas.drawImageRect(
        mapImage,
        Rect.fromLTWH(0, 0, mapImage.width.toDouble(), mapImage.height.toDouble()),
        Rect.fromLTWH(mapX, mapY, mapW, mapH),
        Paint(),
      );
      canvas.drawRect(
        Rect.fromLTWH(mapX, mapY, mapW, mapH),
        Paint()
          ..color = accentColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _drawText(canvas, 'MAP',
          x: mapX + 5, y: mapY + 5,
          fontSize: H * 0.013 * fScale, color: Colors.white,
          bold: true, maxWidth: mapW - 10);
      textRightBound = mapX - pad;
    } else {
      // Placeholder map grid when no API image
      final boxW = W * (isPortrait ? 0.28 : 0.22);
      final boxH = overlayH - pad * 2.5;
      final boxX = W - boxW - pad;
      final boxY = overlayY + pad;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(boxX, boxY, boxW, boxH), const Radius.circular(8)),
        Paint()..color = const Color(0x44FFFFFF),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(boxX, boxY, boxW, boxH), const Radius.circular(8)),
        Paint()
          ..color = accentColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 0.8;
      for (var i = 1; i < 4; i++) {
        canvas.drawLine(Offset(boxX + boxW / 4 * i, boxY),
            Offset(boxX + boxW / 4 * i, boxY + boxH), gridPaint);
        canvas.drawLine(Offset(boxX, boxY + boxH / 4 * i),
            Offset(boxX + boxW, boxY + boxH / 4 * i), gridPaint);
      }
      canvas.drawCircle(
          Offset(boxX + boxW / 2, boxY + boxH / 2), 6, Paint()..color = Colors.red);
      canvas.drawCircle(
          Offset(boxX + boxW / 2, boxY + boxH / 2), 3, Paint()..color = Colors.white);
      _drawText(canvas, 'MAP PREVIEW',
          x: boxX + 4, y: boxY + 4,
          fontSize: H * 0.010 * fScale, color: Colors.white54,
          bold: false, maxWidth: boxW - 8);
      textRightBound = boxX - pad;
    }

    // ── GPS text ──────────────────────────────────────────
    final textMaxW = textRightBound - pad;
    var y = overlayY + pad;

    final modeColor = location.isCustom
        ? const Color(0xFFCE93D8)
        : const Color(0xFF80CBC4);

    _drawText(canvas, '● ${location.modeLabel.toUpperCase()}',
        x: pad, y: y,
        fontSize: H * 0.018 * fScale, color: modeColor,
        bold: true, maxWidth: textMaxW);
    y += H * 0.024 * fScale;

    canvas.drawLine(
      Offset(pad, y),
      Offset(pad + textMaxW, y),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..strokeWidth = 0.8,
    );
    y += H * 0.012 * fScale;

    _drawTwoPartText(canvas,
        label: 'LAT', value: '${location.latStr}°',
        x: pad, y: y,
        fontSize: H * 0.020 * fScale, maxWidth: textMaxW, H: H);
    y += H * 0.026 * fScale;

    _drawTwoPartText(canvas,
        label: 'LNG', value: '${location.lngStr}°',
        x: pad, y: y,
        fontSize: H * 0.020 * fScale, maxWidth: textMaxW, H: H);
    y += H * 0.026 * fScale;

    _drawTwoPartText(canvas,
        label: 'ADDR', value: location.address,
        x: pad, y: y,
        fontSize: H * 0.017 * fScale, maxWidth: textMaxW, H: H,
        valueColor: const Color(0xFFB2EBF2));
    y += H * 0.023 * fScale;

    final dateStr =
        DateFormat('dd MMM yyyy   HH:mm:ss').format(location.timestamp);
    _drawTwoPartText(canvas,
        label: 'TIME', value: dateStr,
        x: pad, y: y,
        fontSize: H * 0.016 * fScale, maxWidth: textMaxW, H: H,
        valueColor: const Color(0xFFB2EBF2));
    y += H * 0.022 * fScale;

    _drawText(canvas, '⚠  For documentation purposes only',
        x: pad, y: y,
        fontSize: H * 0.014 * fScale, color: const Color(0xFFFFF59D),
        bold: false, maxWidth: textMaxW);

    // App watermark (top-right)
    _drawText(canvas, AppConstants.appName,
        x: W - W * 0.40, y: H * 0.018,
        fontSize: H * 0.014 * fScale,
        color: Colors.white.withValues(alpha: 0.75),
        bold: false, maxWidth: W * 0.38);

    // Custom location banner (very bottom strip)
    if (location.isCustom) {
      final bannerH = H * 0.040;
      final bannerY = H - bannerH;
      canvas.drawRect(
        Rect.fromLTWH(0, bannerY, W, bannerH),
        Paint()..color = const Color(0xCC6A1B9A),
      );
      _drawText(canvas,
          '⚠  CUSTOM LOCATION USED   |   COORDINATES MAY NOT REFLECT ACTUAL POSITION',
          x: pad, y: bannerY + bannerH * 0.15,
          fontSize: H * 0.013 * fScale, color: Colors.white,
          bold: true, maxWidth: W - pad * 2);
    }

    final picture = recorder.endRecording();
    return picture.toImage(cameraImage.width, cameraImage.height);
  }

  // ── Text helpers ──────────────────────────────────────────

  static void _drawTwoPartText(
    Canvas canvas, {
    required String label,
    required String value,
    required double x,
    required double y,
    required double fontSize,
    required double maxWidth,
    required double H,
    Color valueColor = Colors.white,
  }) {
    final labelWidth = fontSize * (label.length + 1) * 0.72;
    _drawText(canvas, '$label  ',
        x: x, y: y,
        fontSize: fontSize * 0.82, color: Colors.white38,
        bold: false, maxWidth: labelWidth);
    _drawText(canvas, value,
        x: x + labelWidth, y: y,
        fontSize: fontSize, color: valueColor,
        bold: true, maxWidth: maxWidth - labelWidth);
  }

  static void _drawText(
    Canvas canvas,
    String text, {
    required double x,
    required double y,
    required double fontSize,
    required Color color,
    required bool bold,
    required double maxWidth,
  }) {
    if (text.isEmpty || maxWidth <= 0) return;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      ),
    );
    builder.pushStyle(ui.TextStyle(
      color: color,
      fontSize: fontSize.clamp(10.0, 80.0),
      fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
      letterSpacing: 0.3,
    ));
    builder.addText(text);
    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    canvas.drawParagraph(paragraph, Offset(x, y));
  }
}
