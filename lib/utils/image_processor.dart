// lib/utils/image_processor.dart
//
// Handles compositing the GPS info overlay onto a captured camera photo
// using dart:ui Canvas — no external image package required.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../models/location_data.dart';
import '../constants/app_constants.dart';

class ImageProcessor {
  /// Main entry point: composites GPS overlay onto camera photo and saves to gallery.
  static Future<bool> processAndSave(
    String imagePath,
    LocationData locationData,
  ) async {
    try {
      debugPrint('[ImageProcessor] Processing: $imagePath');

      // 1. Load camera image bytes
      final imageBytes = await File(imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final cameraImage = frame.image;

      // 2. Try to download static map thumbnail (optional)
      ui.Image? mapImage;
      if (AppConstants.googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY') {
        mapImage = await _downloadStaticMapImage(locationData);
      }

      // 3. Composite overlay onto image
      final finalImage =
          await _compositeOverlay(cameraImage, locationData, mapImage);

      // 4. Encode to JPEG bytes
      final byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('[ImageProcessor] Failed to encode final image');
        return false;
      }

      // 5. Save to temporary file
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${dir.path}/GPS_Photo_$timestamp.png';
      await File(outputPath).writeAsBytes(byteData.buffer.asUint8List());

      // 6. Save to device gallery
      await Gal.putImage(outputPath, album: 'GPS Map Camera Pro');

      debugPrint('[ImageProcessor] Saved to gallery: $outputPath');

      // Clean up temp files
      try {
        await File(outputPath).delete();
        await File(imagePath).delete();
      } catch (_) {}

      return true;
    } catch (e, stack) {
      debugPrint('[ImageProcessor] Error: $e\n$stack');
      return false;
    }
  }

  // ── Static Map Download ───────────────────────────────────

  static Future<ui.Image?> _downloadStaticMapImage(
      LocationData location) async {
    try {
      final url = AppConstants.staticMapUrl(
          location.latitude, location.longitude);
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 6),
      );

      if (response.statusCode == 200) {
        final codec =
            await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }
    } catch (e) {
      debugPrint('[ImageProcessor] Static map download failed: $e');
    }
    return null;
  }

  // ── Image Compositing ─────────────────────────────────────

  static Future<ui.Image> _compositeOverlay(
    ui.Image cameraImage,
    LocationData location,
    ui.Image? mapImage,
  ) async {
    final W = cameraImage.width.toDouble();
    final H = cameraImage.height.toDouble();

    // Overlay occupies bottom 28% of image
    final overlayH = H * 0.28;
    final overlayY = H - overlayH;
    final pad = W * 0.028;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, W, H));

    // ── Draw camera image ──
    canvas.drawImage(cameraImage, Offset.zero, Paint());

    // ── Draw top gradient strip (for app name / mode badge) ──
    final topGradH = H * 0.09;
    final topGradPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, topGradH),
        [const Color(0xBB000000), const Color(0x00000000)],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, W, topGradH), topGradPaint);

    // ── Draw overlay background ──
    final overlayPaint = Paint()..color = const Color(0xEE0A0A1A);
    canvas.drawRect(
        Rect.fromLTWH(0, overlayY, W, overlayH), overlayPaint);

    // ── Accent line at top of overlay ──
    final accentColor = location.isCustom
        ? const Color(0xFF9C27B0)
        : const Color(0xFF00897B);
    canvas.drawRect(
      Rect.fromLTWH(0, overlayY, W, 3),
      Paint()..color = accentColor,
    );

    // ── Draw map thumbnail (right side) ──
    double textRightBound = W - pad;
    if (mapImage != null) {
      final mapW = W * 0.27;
      final mapH = overlayH - pad * 2;
      final mapX = W - mapW - pad;
      final mapY = overlayY + pad;

      // Shadow
      canvas.drawRect(
        Rect.fromLTWH(mapX - 2, mapY - 2, mapW + 4, mapH + 4),
        Paint()..color = Colors.black.withOpacity(0.4),
      );
      // Map image
      canvas.drawImageRect(
        mapImage,
        Rect.fromLTWH(
            0, 0, mapImage.width.toDouble(), mapImage.height.toDouble()),
        Rect.fromLTWH(mapX, mapY, mapW, mapH),
        Paint(),
      );
      // Border
      canvas.drawRect(
        Rect.fromLTWH(mapX, mapY, mapW, mapH),
        Paint()
          ..color = accentColor.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      // "MAP" label
      _drawText(canvas, 'MAP', x: mapX + 5, y: mapY + 5,
          fontSize: H * 0.013, color: Colors.white, bold: true,
          maxWidth: mapW - 10);

      textRightBound = mapX - pad;
    } else {
      // Mini map placeholder box when no real map
      final boxW = W * 0.22;
      final boxH = overlayH - pad * 2.5;
      final boxX = W - boxW - pad;
      final boxY = overlayY + pad;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(boxX, boxY, boxW, boxH),
            const Radius.circular(8)),
        Paint()..color = const Color(0x44FFFFFF),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(boxX, boxY, boxW, boxH),
            const Radius.circular(8)),
        Paint()
          ..color = accentColor.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Grid lines to simulate map
      final gridPaint = Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..strokeWidth = 0.8;
      for (var i = 1; i < 4; i++) {
        final x = boxX + (boxW / 4) * i;
        canvas.drawLine(Offset(x, boxY), Offset(x, boxY + boxH), gridPaint);
        final y = boxY + (boxH / 4) * i;
        canvas.drawLine(Offset(boxX, y), Offset(boxX + boxW, y), gridPaint);
      }

      // Marker pin
      canvas.drawCircle(
          Offset(boxX + boxW / 2, boxY + boxH / 2), 6,
          Paint()..color = Colors.red);
      canvas.drawCircle(
          Offset(boxX + boxW / 2, boxY + boxH / 2), 3,
          Paint()..color = Colors.white);

      _drawText(canvas, 'MAP PREVIEW',
          x: boxX + 4, y: boxY + 4,
          fontSize: H * 0.010,
          color: Colors.white54,
          bold: false,
          maxWidth: boxW - 8);

      textRightBound = boxX - pad;
    }

    // ── Draw GPS Text Overlay ──
    final textMaxW = textRightBound - pad;
    var y = overlayY + pad;

    // Mode label
    final modeColor = location.isCustom
        ? const Color(0xFFCE93D8)
        : const Color(0xFF80CBC4);
    _drawText(canvas, '● ${location.modeLabel.toUpperCase()}',
        x: pad, y: y,
        fontSize: H * 0.018, color: modeColor, bold: true,
        maxWidth: textMaxW);
    y += H * 0.024;

    // Separator
    canvas.drawLine(
      Offset(pad, y),
      Offset(pad + textMaxW, y),
      Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..strokeWidth = 0.8,
    );
    y += H * 0.012;

    // Latitude
    _drawTwoPartText(canvas,
        label: 'LAT', value: '${location.latStr}°',
        x: pad, y: y,
        fontSize: H * 0.020, maxWidth: textMaxW, H: H);
    y += H * 0.026;

    // Longitude
    _drawTwoPartText(canvas,
        label: 'LNG', value: '${location.lngStr}°',
        x: pad, y: y,
        fontSize: H * 0.020, maxWidth: textMaxW, H: H);
    y += H * 0.026;

    // Address
    _drawTwoPartText(canvas,
        label: 'ADDR', value: location.address,
        x: pad, y: y,
        fontSize: H * 0.017, maxWidth: textMaxW, H: H,
        valueColor: const Color(0xFFB2EBF2));
    y += H * 0.023;

    // Date & Time
    final dateStr =
        DateFormat('dd MMM yyyy   HH:mm:ss').format(location.timestamp);
    _drawTwoPartText(canvas,
        label: 'TIME', value: dateStr,
        x: pad, y: y,
        fontSize: H * 0.016, maxWidth: textMaxW, H: H,
        valueColor: const Color(0xFFB2EBF2));
    y += H * 0.022;

    // Disclaimer
    _drawText(canvas, '⚠  For documentation purposes only',
        x: pad, y: y,
        fontSize: H * 0.014,
        color: const Color(0xFFFFF59D),
        bold: false,
        maxWidth: textMaxW);

    // ── App Watermark (top-right corner) ──
    _drawText(canvas, 'GPS Map Camera Pro',
        x: W - W * 0.38, y: H * 0.018,
        fontSize: H * 0.014,
        color: Colors.white.withOpacity(0.75),
        bold: false,
        maxWidth: W * 0.36);

    // ── Custom Location Watermark Banner ──
    if (location.isCustom) {
      final bannerH = H * 0.042;
      final bannerY = H - bannerH;

      // Purple banner
      canvas.drawRect(
        Rect.fromLTWH(0, bannerY, W, bannerH),
        Paint()..color = const Color(0xCC6A1B9A),
      );

      _drawText(canvas,
          '⚠  CUSTOM LOCATION USED   |   COORDINATES MAY NOT REFLECT ACTUAL POSITION',
          x: pad, y: bannerY + bannerH * 0.18,
          fontSize: H * 0.014,
          color: Colors.white,
          bold: true,
          maxWidth: W - pad * 2);
    }

    // Finish compositing
    final picture = recorder.endRecording();
    return picture.toImage(
        cameraImage.width, cameraImage.height);
  }

  // ── Text Drawing Helpers ──────────────────────────────────

  /// Draws a label (grey) + value (white) pair
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

    // Label
    _drawText(canvas, '$label  ',
        x: x, y: y,
        fontSize: fontSize * 0.82,
        color: Colors.white38,
        bold: false,
        maxWidth: labelWidth);

    // Value
    _drawText(canvas, value,
        x: x + labelWidth, y: y,
        fontSize: fontSize,
        color: valueColor,
        bold: true,
        maxWidth: maxWidth - labelWidth);
  }

  /// Core text rendering using dart:ui ParagraphBuilder
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
      fontSize: fontSize.clamp(10.0, 60.0),
      fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
      letterSpacing: 0.3,
    ));
    builder.addText(text);
    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    canvas.drawParagraph(paragraph, Offset(x, y));
  }
}
