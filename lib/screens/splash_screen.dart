// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _iconCtrl;
  late AnimationController _textCtrl;
  late AnimationController _btnCtrl;

  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _btnOpacity;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _iconCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _btnCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _iconScale   = CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut).drive(Tween(begin: 0.4, end: 1.0));
    _iconOpacity = CurvedAnimation(parent: _iconCtrl, curve: const Interval(0, 0.4)).drive(Tween(begin: 0.0, end: 1.0));
    _textOpacity = _textCtrl.drive(CurveTween(curve: Curves.easeOut)).drive(Tween(begin: 0.0, end: 1.0));
    _textSlide   = _textCtrl.drive(CurveTween(curve: Curves.easeOut)).drive(
      Tween(begin: const Offset(0, 0.3), end: Offset.zero),
    );
    _btnOpacity  = _btnCtrl.drive(Tween(begin: 0.0, end: 1.0));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 150));
    _iconCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _btnCtrl.forward();
    // No auto-navigate — user must tap "Get Started" to proceed.
  }

  Future<void> _navigate() async {
    final prefs = await SharedPreferences.getInstance();
    final seen  = prefs.getBool('onboarding_seen') ?? false;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => seen ? const HomeScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    _textCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107),
      body: Stack(
        children: [
          // Green farmland gradient at the very bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.22,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFC107), Color(0xFF6B9E3D)],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // App icon
                AnimatedBuilder(
                  animation: _iconCtrl,
                  builder: (_, child) => Opacity(
                    opacity: _iconOpacity.value,
                    child: Transform.scale(scale: _iconScale.value, child: child),
                  ),
                  child: _AppIcon(),
                ),

                const SizedBox(height: 36),

                // Title + tagline
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (_, child) => Opacity(
                    opacity: _textOpacity.value,
                    child: SlideTransition(position: _textSlide, child: child),
                  ),
                  child: _TitleSection(),
                ),

                const Spacer(flex: 3),

                // Get Started button
                AnimatedBuilder(
                  animation: _btnCtrl,
                  builder: (_, child) => Opacity(opacity: _btnOpacity.value, child: child),
                  child: _GetStartedButton(onTap: _navigate),
                ),

                const SizedBox(height: 44),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── App Icon ─────────────────────────────────────────────────────────────────

class _AppIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107),
        borderRadius: BorderRadius.circular(44),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Background green field
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(38),
                  bottomRight: Radius.circular(38),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                ),
              ),
            ),
          ),

          // Satellite icon top-left
          Positioned(
            top: 16,
            left: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.satellite_alt_rounded, size: 28, color: Color(0xFF555555)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    for (int i = 0; i < 3; i++)
                      Padding(
                        padding: EdgeInsets.only(left: i * 4.0),
                        child: Container(
                          width: 2,
                          height: 8.0 - i * 2,
                          color: const Color(0xFF777777),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Camera body (center)
          Center(
            child: Container(
              width: 100,
              height: 78,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned(
                    top: 7,
                    child: Text(
                      'SLC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  // Camera lens
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                      ),
                      border: Border.all(color: const Color(0xFF333333), width: 4),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF003566),
                      ),
                    ),
                  ),
                  // Yellow dot (flash)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC107),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // GPS pin
          const Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Icon(Icons.location_on, color: Colors.red, size: 36),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Title Section ─────────────────────────────────────────────────────────────

class _TitleSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'SLC',
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A2E),
            letterSpacing: -3,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'GPS ',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2E7D32),
                letterSpacing: 3,
              ),
            ),
            Text(
              'MAP CAMERA',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 50, height: 1.5, color: const Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Container(width: 50, height: 1.5, color: const Color(0xFF2E7D32)),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Capture. Tag. Remember.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'with accurate GPS location & map.',
          style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
        ),
      ],
    );
  }
}

// ── Get Started Button ────────────────────────────────────────────────────────

class _GetStartedButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GetStartedButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFE6A800),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              SizedBox(width: 10),
              Icon(Icons.arrow_forward_rounded, color: Color(0xFF1A1A2E), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
