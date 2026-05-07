// lib/screens/gallery_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/app_storage.dart';
import 'photo_preview_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<File> _images = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _loading = true);
    final images = await AppStorage.listImages();
    if (mounted) setState(() { _images = images; _loading = false; });
  }

  Future<void> _openPhoto(File file) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoPreviewScreen(imagePath: file.path),
      ),
    );
    if (result == 'deleted' || result == 'renamed') {
      await _loadImages();
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar()],
        body: _buildBody(),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFF0D1117),
      expandedHeight: 100,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Photos',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
            if (_images.isNotEmpty)
              Text(
                '${_images.length} photo${_images.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11),
              ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          onPressed: _loadImages,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
      );
    }

    if (_images.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: const Color(0xFF4FC3F7),
      backgroundColor: const Color(0xFF1E2A3A),
      onRefresh: _loadImages,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: _images.length,
        itemBuilder: (_, i) => _buildThumbnail(_images[i]),
      ),
    );
  }

  Widget _buildThumbnail(File file) {
    return GestureDetector(
      onTap: () => _openPhoto(file),
      child: Hero(
        tag: file.path,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2232),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              file,
              fit: BoxFit.cover,
              cacheWidth: 300,
              cacheHeight: 300,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image,
                    color: Colors.white30, size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2232),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF4FC3F7).withValues(alpha: 0.3),
                  width: 2),
            ),
            child: const Icon(Icons.photo_library_outlined,
                color: Color(0xFF4FC3F7), size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Photos Yet',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            'Photos you capture with GPS Map Camera Pro\nwill appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45), fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FC3F7),
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.camera_alt_rounded,
                color: Colors.white),
            label: const Text('Take a Photo',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
