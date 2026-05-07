// lib/utils/app_storage.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AppStorage {
  static const String folderName = 'GPS Map Camera Pro';

  // ── Directory ─────────────────────────────────────────────

  /// Returns (and creates if needed) the app's dedicated photo folder.
  /// Android: /storage/emulated/0/Android/data/<pkg>/files/GPS Map Camera Pro/
  /// Fallback: app documents directory
  static Future<Directory?> getAppDirectory() async {
    try {
      Directory base;
      if (Platform.isAndroid) {
        final ext = await getExternalStorageDirectory();
        base = ext ?? await getApplicationDocumentsDirectory();
      } else {
        base = await getApplicationDocumentsDirectory();
      }
      final appDir = Directory('${base.path}/$folderName');
      if (!await appDir.exists()) await appDir.create(recursive: true);
      return appDir;
    } catch (e) {
      debugPrint('[AppStorage] getAppDirectory error: $e');
      return null;
    }
  }

  // ── File Naming ───────────────────────────────────────────

  static String generateFileName() {
    final now = DateTime.now();
    final y  = now.year.toString().padLeft(4, '0');
    final mo = now.month.toString().padLeft(2, '0');
    final d  = now.day.toString().padLeft(2, '0');
    final h  = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final s  = now.second.toString().padLeft(2, '0');
    return 'GPS_$y$mo${d}_$h$mi$s.jpg';
  }

  // ── Listing ───────────────────────────────────────────────

  static Future<List<File>> listImages() async {
    try {
      final dir = await getAppDirectory();
      if (dir == null || !await dir.exists()) return [];

      final entries = await dir.list().toList();
      final images = entries.whereType<File>().where((f) {
        final lower = f.path.toLowerCase();
        return lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.png');
      }).toList();

      images.sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified));
      return images;
    } catch (e) {
      debugPrint('[AppStorage] listImages error: $e');
      return [];
    }
  }

  // ── Rename ────────────────────────────────────────────────

  static Future<File?> renameImage(File file, String newName) async {
    try {
      String name = newName.trim();
      if (!name.toLowerCase().endsWith('.jpg') &&
          !name.toLowerCase().endsWith('.jpeg') &&
          !name.toLowerCase().endsWith('.png')) {
        name = '$name.jpg';
      }
      final newPath = '${file.parent.path}/$name';
      if (await File(newPath).exists() && newPath != file.path) {
        return null; // name already taken
      }
      return await file.rename(newPath);
    } catch (e) {
      debugPrint('[AppStorage] renameImage error: $e');
      return null;
    }
  }

  // ── Delete ────────────────────────────────────────────────

  static Future<bool> deleteImage(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AppStorage] deleteImage error: $e');
      return false;
    }
  }

  // ── Permissions ───────────────────────────────────────────

  /// Requests storage/photos permission appropriate for the current
  /// Android SDK version. Returns true when granted.
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Android 13+ needs READ_MEDIA_IMAGES; below that READ_EXTERNAL_STORAGE
    final photos = await Permission.photos.status;
    if (photos.isGranted) return true;

    final storage = await Permission.storage.status;
    if (storage.isGranted) return true;

    // Request whichever is applicable
    final photosResult  = await Permission.photos.request();
    if (photosResult.isGranted) return true;

    final storageResult = await Permission.storage.request();
    return storageResult.isGranted;
  }

  // ── Helpers ───────────────────────────────────────────────

  static String basenameWithoutExt(String path) {
    final base = path.split('/').last.split('\\').last;
    final dot = base.lastIndexOf('.');
    return dot >= 0 ? base.substring(0, dot) : base;
  }

  static String basename(String path) =>
      path.split('/').last.split('\\').last;
}
