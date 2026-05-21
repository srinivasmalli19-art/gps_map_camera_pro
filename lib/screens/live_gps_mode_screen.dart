// lib/screens/live_gps_mode_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import 'camera_screen.dart';

class LiveGpsModeScreen extends StatefulWidget {
  const LiveGpsModeScreen({super.key});

  @override
  State<LiveGpsModeScreen> createState() => _LiveGpsModeScreenState();
}

class _LiveGpsModeScreenState extends State<LiveGpsModeScreen> {
  bool _loading = false;

  Future<void> _openCamera() async {
    setState(() => _loading = true);
    final provider = context.read<LocationProvider>();
    final ok = await provider.fetchLiveLocation();
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      _showError(provider.error ?? 'Could not get GPS location.');
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const CameraScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('GPS Error', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationProvider>().locationData;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: Color(0xFF333333)),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Live GPS Mode',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF2E7D32)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.help_outline_rounded,
                        size: 18, color: Color(0xFF2E7D32)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Satellite illustration
                    _SatelliteIllustration(),

                    const SizedBox(height: 24),

                    // GPS status chip
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.gps_fixed_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'GPS Connected',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  loc != null
                                      ? 'Lat ${loc.latitude.toStringAsFixed(4)}° • Long ${loc.longitude.toStringAsFixed(4)}°'
                                      : 'Ready to detect your location',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF555555),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.gps_not_fixed_rounded,
                              color: Color(0xFF2E7D32), size: 20),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Features list
                    _featureRow(
                      icon: Icons.my_location_rounded,
                      color: const Color(0xFF2E7D32),
                      title: 'Auto-detect current GPS position',
                      subtitle: 'Get exact location automatically',
                    ),
                    _featureRow(
                      icon: Icons.location_on_rounded,
                      color: const Color(0xFF2E7D32),
                      title: 'Real-time coordinates',
                      subtitle: 'View live latitude & longitude',
                    ),
                    _featureRow(
                      icon: Icons.code_rounded,
                      color: const Color(0xFF2E7D32),
                      title: 'Automatic reverse geocoding',
                      subtitle: 'Get address for current location',
                    ),
                    _featureRow(
                      icon: Icons.camera_alt_rounded,
                      color: const Color(0xFF2E7D32),
                      title: 'Instant one-tap capture',
                      subtitle: 'Capture photo with location & map',
                    ),

                    const SizedBox(height: 24),

                    // Current location card (if available)
                    if (loc != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Location',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2E7D32),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _coordRow(Icons.gps_fixed_rounded,
                                          'Lat ${loc.latitude.toStringAsFixed(4)}° N'),
                                      const SizedBox(height: 4),
                                      _coordRow(Icons.gps_fixed_rounded,
                                          'Long ${loc.longitude.toStringAsFixed(4)}° E'),
                                      const SizedBox(height: 4),
                                      _coordRow(Icons.gps_not_fixed_rounded,
                                          'Accuracy: 2.1 m'),
                                    ],
                                  ),
                                ),
                                // Mini map preview
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFA5D6A7)),
                                  ),
                                  child: const Icon(Icons.map_rounded,
                                      color: Color(0xFF2E7D32), size: 32),
                                ),
                              ],
                            ),
                            if (loc.address.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                loc.address,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF555555)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Open Camera button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: GestureDetector(
                onTap: _loading ? null : _openCamera,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _loading
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Open Camera',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
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

  Widget _featureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _coordRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333))),
      ],
    );
  }
}

// ── Satellite illustration ────────────────────────────────────────────────────

class _SatelliteIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circles
          for (int i = 3; i >= 1; i--)
            Container(
              width: 50.0 * i,
              height: 50.0 * i,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7D32).withValues(alpha: 0.04 * i),
                border: Border.all(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
          // Center GPS pin
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.gps_fixed_rounded,
                color: Colors.white, size: 28),
          ),
          // Satellite 1
          Positioned(
            top: 10,
            right: 30,
            child: Transform.rotate(
              angle: -0.5,
              child: const Icon(Icons.satellite_alt_rounded,
                  color: Color(0xFF555555), size: 34),
            ),
          ),
          // Satellite 2
          Positioned(
            top: 30,
            left: 20,
            child: Transform.rotate(
              angle: 0.3,
              child: const Icon(Icons.satellite_alt_rounded,
                  color: Color(0xFF777777), size: 26),
            ),
          ),
          // Dotted signal lines
          Positioned(
            top: 28,
            right: 52,
            child: Column(
              children: [
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Container(
                      width: 2,
                      height: 6,
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
