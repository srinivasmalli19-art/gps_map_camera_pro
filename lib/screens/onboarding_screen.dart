// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      titleParts: [
        _TitlePart('Capture.', Color(0xFF1A1A2E)),
        _TitlePart('\nTag. ', Color(0xFF2E7D32)),
        _TitlePart('Remember.', Color(0xFFF59E0B)),
      ],
      subtitle: 'Photos with accurate GPS\nlocation & map.',
      chips: ['Accurate GPS Data', 'Live Tracking', 'Smart Watermark'],
      illustration: _OnboardingIllustration.camera,
    ),
    _OnboardingPage(
      titleParts: [
        _TitlePart('Track. ', Color(0xFF2E7D32)),
        _TitlePart('\nLocate. ', Color(0xFF1A1A2E)),
        _TitlePart('Stamp.', Color(0xFFF59E0B)),
      ],
      subtitle: 'Real-time GPS coordinates\nburned into every photo.',
      chips: ['Auto GPS Lock', 'Satellite Link', 'Reverse Geocode'],
      illustration: _OnboardingIllustration.gps,
    ),
    _OnboardingPage(
      titleParts: [
        _TitlePart('Share. ', Color(0xFF1A1A2E)),
        _TitlePart('\nProve. ', Color(0xFF2E7D32)),
        _TitlePart('Document.', Color(0xFFF59E0B)),
      ],
      subtitle: 'Professional GPS watermarks\nfor field documentation.',
      chips: ['Map Overlay', 'Date & Time', 'Custom Location'],
      illustration: _OnboardingIllustration.map,
    ),
  ];

  void _goToNext() {
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const HomeScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E8),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _finish,
                    child: const Row(
                      children: [
                        Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF555555),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            color: Color(0xFF555555), size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i].build(context),
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFCCCCCC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Next / Get Started button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: GestureDetector(
                onTap: _goToNext,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Color(0xFF1A1A2E), size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data structures ────────────────────────────────────────────────────────────

enum _OnboardingIllustration { camera, gps, map }

class _TitlePart {
  final String text;
  final Color color;
  const _TitlePart(this.text, this.color);
}

class _OnboardingPage {
  final List<_TitlePart> titleParts;
  final String subtitle;
  final List<String> chips;
  final _OnboardingIllustration illustration;

  const _OnboardingPage({
    required this.titleParts,
    required this.subtitle,
    required this.chips,
    required this.illustration,
  });

  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Title
          RichText(
            text: TextSpan(
              children: titleParts.map((p) => TextSpan(
                text: p.text,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: p.color,
                  height: 1.15,
                ),
              )).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF555555),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          // Feature chips
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: chips.map((chip) => _FeatureChip(label: chip)).toList(),
          ),

          const SizedBox(height: 24),

          // Illustration
          Expanded(child: _IllustrationWidget(type: illustration)),
        ],
      ),
    );
  }
}

// ── Feature chip ──────────────────────────────────────────────────────────────

class _FeatureChip extends StatelessWidget {
  final String label;
  const _FeatureChip({required this.label});

  static const _icons = {
    'Accurate GPS Data': Icons.gps_fixed_rounded,
    'Live Tracking': Icons.wifi_tethering_rounded,
    'Smart Watermark': Icons.photo_filter_rounded,
    'Auto GPS Lock': Icons.lock_rounded,
    'Satellite Link': Icons.satellite_alt_rounded,
    'Reverse Geocode': Icons.location_city_rounded,
    'Map Overlay': Icons.map_rounded,
    'Date & Time': Icons.access_time_rounded,
    'Custom Location': Icons.edit_location_alt_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icons[label] ?? Icons.check_circle_rounded,
            size: 14,
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Illustration ──────────────────────────────────────────────────────────────

class _IllustrationWidget extends StatelessWidget {
  final _OnboardingIllustration type;
  const _IllustrationWidget({required this.type});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 280,
        height: 240,
        child: _buildIllustration(),
      ),
    );
  }

  Widget _buildIllustration() {
    switch (type) {
      case _OnboardingIllustration.camera:
        return _CameraIllustration();
      case _OnboardingIllustration.gps:
        return _GpsIllustration();
      case _OnboardingIllustration.map:
        return _MapIllustration();
    }
  }
}

class _CameraIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Map background
        Container(
          width: 260,
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBBDEFB), width: 2),
          ),
          child: CustomPaint(painter: _MapGridPainter()),
        ),
        // Camera + pin
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned(
                    top: 8,
                    child: Text(
                      'SLC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.location_on, color: Colors.red, size: 40),
          ],
        ),
      ],
    );
  }
}

class _GpsIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Concentric circles
        for (int i = 3; i >= 1; i--)
          Container(
            width: 80.0 * i,
            height: 80.0 * i,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.15 * i),
                width: 1.5,
              ),
            ),
          ),
        // GPS pin
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gps_fixed_rounded,
                  color: Colors.white, size: 30),
            ),
            Container(
              width: 3,
              height: 20,
              color: const Color(0xFF2E7D32),
            ),
            Container(
              width: 16,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        // Satellite
        const Positioned(
          top: 20,
          right: 20,
          child: Icon(Icons.satellite_alt_rounded,
              color: Color(0xFF555555), size: 36),
        ),
      ],
    );
  }
}

class _MapIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            CustomPaint(
              painter: _MapGridPainter(),
              child: const SizedBox(width: 260, height: 200),
            ),
            // Route line
            CustomPaint(
              painter: _RoutePainter(),
              child: const SizedBox(width: 260, height: 200),
            ),
            // Pin
            const Positioned(
              top: 60,
              left: 100,
              child: Icon(Icons.location_on, color: Colors.red, size: 40),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom painters ───────────────────────────────────────────────────────────

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBBDEFB).withValues(alpha: 0.6)
      ..strokeWidth = 1.0;
    for (int i = 1; i < 5; i++) {
      canvas.drawLine(Offset(size.width * i / 5, 0),
          Offset(size.width * i / 5, size.height), paint);
      canvas.drawLine(Offset(0, size.height * i / 5),
          Offset(size.width, size.height * i / 5), paint);
    }
    final road = Paint()
      ..color = const Color(0xFFFFC107).withValues(alpha: 0.5)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, 100), Offset(size.width, 100), road);
    canvas.drawLine(Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height), road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(20, size.height - 20)
      ..quadraticBezierTo(80, 60, 120, 80);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
