// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import 'map_picker_screen.dart';
import 'camera_screen.dart';
import 'gallery_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;
              return Column(
                children: [
                  _buildHeader(context, isLandscape),
                  Expanded(child: _buildModeCards(context, isLandscape)),
                  _buildFooter(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isLandscape ? 8 : 16, 20, isLandscape ? 6 : 10),
      child: isLandscape ? _headerLandscape() : _headerPortrait(),
    );
  }

  Widget _headerLandscape() {
    // Single compact row for landscape
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _appIcon(size: 22, padding: 9, radius: 13),
        const SizedBox(width: 12),
        const Text(
          'SLC GPS Map Camera',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        _proBadge(),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            'Capture photos with precise GPS coordinates',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _headerPortrait() {
    // Stacked layout for portrait — no overflow risk
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _appIcon(size: 24, padding: 10, radius: 14),
            const SizedBox(width: 12),
            const Text(
              'SLC GPS Map Camera',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            _proBadge(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Capture photos with precise GPS coordinates',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _appIcon({required double size, required double padding, required double radius}) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: size),
    );
  }

  Widget _proBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }

  // ── Mode cards ────────────────────────────────────────────

  Widget _buildModeCards(BuildContext context, bool isLandscape) {
    final liveCard = _ModeCard(
      icon: Icons.gps_fixed_rounded,
      title: 'Live GPS Mode',
      subtitle: 'Capture with real-time device location',
      features: const [
        'Auto-detect current GPS position',
        'Real-time coordinates',
        'Automatic reverse geocoding',
        'Instant one-tap capture',
      ],
      gradientColors: const [Color(0xFF0D7377), Color(0xFF14A085)],
      glowColor: const Color(0xFF14A085),
      badgeText: 'LIVE',
      badgeGradient: const LinearGradient(
        colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
      ),
      onTap: () => _handleLiveMode(context),
    );

    final customCard = _ModeCard(
      icon: Icons.map_rounded,
      title: 'Custom Location Mode',
      subtitle: 'Manually select any location on map',
      features: const [
        'Select any point on Google Maps',
        'Zoom, scroll & pinpoint location',
        'Confirmation before capture',
        'Custom location watermark added',
      ],
      gradientColors: const [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
      glowColor: const Color(0xFF8E24AA),
      badgeText: 'CUSTOM',
      badgeGradient: const LinearGradient(
        colors: [Color(0xFFAB47BC), Color(0xFFCE93D8)],
      ),
      onTap: () => _handleCustomMode(context),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: isLandscape
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: liveCard),
                const SizedBox(width: 14),
                Expanded(child: customCard),
              ],
            )
          : Column(
              children: [
                Expanded(child: liveCard),
                const SizedBox(height: 14),
                Expanded(child: customCard),
              ],
            ),
    );
  }

  // ── Mode handlers ─────────────────────────────────────────

  Future<void> _handleLiveMode(BuildContext context) async {
    final provider = context.read<LocationProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
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
              Text('Getting GPS Location…',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              SizedBox(height: 6),
              Text('Please wait. This may take a few seconds.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );

    final success = await provider.fetchLiveLocation();
    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (!success) {
      _showErrorDialog(context, provider.error ?? 'Unknown error occurred.');
      return;
    }

    Navigator.push(context, _buildPageRoute(const CameraScreen()));
  }

  void _handleCustomMode(BuildContext context) {
    context.read<LocationProvider>().reset();
    Navigator.push(context, _buildPageRoute(const MapPickerScreen()));
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Location Error', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FC3F7),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  PageRoute _buildPageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position:
              Tween(begin: const Offset(0.05, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  // ── Footer ────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GalleryScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_rounded,
                      color: const Color(0xFF4FC3F7).withValues(alpha: 0.9),
                      size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'My Photos',
                    style: TextStyle(
                      color: Color(0xFF4FC3F7),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: const Color(0xFF4FC3F7).withValues(alpha: 0.6),
                      size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 13, color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                'For documentation purposes only',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Mode card widget ──────────────────────────────────────────────────────────

class _ModeCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> features;
  final List<Color> gradientColors;
  final Color glowColor;
  final String badgeText;
  final Gradient badgeGradient;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.gradientColors,
    required this.glowColor,
    required this.badgeText,
    required this.badgeGradient,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: widget.badgeGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        widget.badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                const SizedBox(height: 12),

                // Feature list
                ...widget.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            feature,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Open',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            )),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
