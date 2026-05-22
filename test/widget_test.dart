// Basic smoke test — verifies the app widget tree builds without throwing.

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_map_camera_pro/main.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const GpsMapCameraApp());
    expect(find.byType(GpsMapCameraApp), findsOneWidget);
  });
}
