# 📷 GPS Map Camera Pro

A production-ready Flutter Android app that captures photos with GPS location overlay data burned directly into the image.

---

## ✨ Features

| Feature | Description |
|---|---|
| **Live GPS Mode** | Real-time device GPS → lat/lng + reverse-geocoded address burned onto photo |
| **Custom Location Mode** | Tap anywhere on Google Maps to pick custom coordinates |
| **Overlay Burn** | Lat, Lng, Address, Date/Time, map thumbnail composited directly into JPEG |
| **Safety Watermark** | "CUSTOM LOCATION USED" purple banner auto-added in custom mode |
| **Disclaimer** | "For documentation purposes only" always visible |
| **Mode Label** | "Live Location" or "Custom Location" clearly shown |
| **Gallery Save** | Saves to dedicated "GPS Map Camera Pro" album |

---

## 📁 Project Structure

```
gps_map_camera_pro/
├── android/
│   ├── app/
│   │   ├── build.gradle
│   │   └── src/main/
│   │       ├── AndroidManifest.xml       ← permissions + Maps API key
│   │       ├── kotlin/com/example/...
│   │       │   └── MainActivity.kt
│   │       └── res/
│   │           └── values/
│   │               ├── styles.xml
│   │               └── strings.xml
│   ├── build.gradle
│   ├── settings.gradle
│   ├── gradle.properties
│   └── gradle/wrapper/
│       └── gradle-wrapper.properties
├── lib/
│   ├── main.dart                         ← App entry, Provider setup
│   ├── constants/
│   │   └── app_constants.dart            ← API key, color constants, map URL helper
│   ├── models/
│   │   └── location_data.dart            ← LocationData + LocationMode enum
│   ├── providers/
│   │   └── location_provider.dart        ← State: live GPS fetch, custom location
│   ├── screens/
│   │   ├── home_screen.dart              ← Mode selection cards
│   │   ├── map_picker_screen.dart        ← Google Maps tap-to-pick UI
│   │   └── camera_screen.dart            ← Camera preview + capture logic
│   ├── utils/
│   │   └── image_processor.dart          ← dart:ui canvas overlay compositor
│   └── widgets/
│       └── camera_overlay_widget.dart    ← Live viewfinder overlay widget
└── pubspec.yaml
```

---

## 🔑 Step 1 — Get a Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. Enable these APIs:
   - **Maps SDK for Android** ← required for map display
   - **Geocoding API** ← required for reverse geocoding (address from coordinates)
   - **Maps Static API** ← optional, for map thumbnail in saved photo
4. Go to **APIs & Services → Credentials → Create Credentials → API Key**
5. Copy the key

---

## 🔧 Step 2 — Add the API Key

You need to add the key in **two places**:

### Place 1 — AndroidManifest.xml
Open `android/app/src/main/AndroidManifest.xml` and replace:
```xml
android:value="YOUR_GOOGLE_MAPS_API_KEY"
```
with:
```xml
android:value="AIza...your_actual_key..."
```

### Place 2 — app_constants.dart
Open `lib/constants/app_constants.dart` and replace:
```dart
static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
```
with:
```dart
static const String googleMapsApiKey = 'AIza...your_actual_key...';
```

> **Note:** The Static Maps thumbnail in saved photos only appears when a real API key is provided. The rest of the app functions without it.

---

## ▶️ Step 3 — Run the App

### Prerequisites
- Flutter SDK 3.10+ installed ([flutter.dev](https://flutter.dev/docs/get-started/install))
- Android Studio or VS Code with Flutter plugin
- Android device or emulator with **API Level 21+** (Android 5.0+)
- For GPS testing: a **physical device** is recommended (emulator GPS is simulated)

### Commands

```bash
# 1. Navigate to project root
cd gps_map_camera_pro

# 2. Install dependencies
flutter pub get

# 3. Check your device is connected
flutter devices

# 4. Run on device
flutter run

# 5. Build a release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 📱 App Flow

### Live GPS Mode
```
Home Screen
  └─► Tap "Live GPS Mode"
        └─► Loading dialog (fetching GPS + address)
              └─► Camera Screen
                    └─► Tap shutter
                          └─► Processing dialog
                                └─► Saved to gallery ✓
```

### Custom Location Mode
```
Home Screen
  └─► Tap "Custom Location Mode"
        └─► Map Picker Screen
              └─► Tap on map → marker + info panel
                    └─► "Use This Location" → confirmation dialog
                          └─► YES → Camera Screen
                                      └─► Tap shutter
                                            └─► Saved to gallery ✓
                                                (with CUSTOM LOCATION watermark)
```

---

## 🛡️ Permissions

The app requests at runtime:
- `ACCESS_FINE_LOCATION` — precise GPS
- `CAMERA` — camera access
- `READ_MEDIA_IMAGES` / `WRITE_EXTERNAL_STORAGE` — saving photos to gallery

If permissions are denied, the app shows a settings button to open system settings.

---

## 📸 Photo Overlay Layout

```
┌─────────────────────────────┐
│  GPS MAP CAMERA PRO  [MODE] │  ← top gradient strip
│                             │
│     (camera photo)          │
│                             │
├─────────────────────────────┤
│ ─────── teal/purple line ── │  ← accent (teal = live, purple = custom)
│ LAT  : 17.3850°N            │
│ LNG  : 78.4867°E            │  ← GPS overlay panel
│ ADDR : Hyderabad, TG, India │
│ TIME : 03 May 2026 14:32:05 │
│ [map thumbnail]   For doc.. │
├─────────────────────────────┤
│  ⚠ CUSTOM LOCATION USED ⚠  │  ← only in Custom Mode
└─────────────────────────────┘
```

---

## ⚙️ Technical Notes

### Image Processing
Photos are composited using **`dart:ui` Canvas** — no heavy image processing packages needed. The pipeline:
1. Camera captures raw JPEG via `camera` package
2. `image_processor.dart` loads it as `ui.Image`
3. Overlay elements drawn via `Canvas.drawImage`, `drawRect`, `ParagraphBuilder`
4. Optional: Static Maps API fetches a small map thumbnail over HTTP
5. Final image encoded to PNG/JPEG bytes
6. Saved to gallery via `gal` package

### Why Not RepaintBoundary for Overlay?
Flutter's `camera` package renders the viewfinder via a native Android `Texture` widget, which cannot be captured by `RepaintBoundary`. The live preview overlay (`CameraOverlayWidget`) is a separate Flutter widget stack for display only. The actual overlay burn happens in `image_processor.dart` using the raw camera file.

### State Management
Uses **Provider** pattern with a single `LocationProvider`. Camera state is managed locally in `CameraScreen` using `StatefulWidget`.

---

## 🐛 Troubleshooting

| Problem | Solution |
|---|---|
| Map shows grey tiles | API key missing or Maps SDK not enabled |
| "MissingPluginException" | Run `flutter clean && flutter pub get` |
| Address shows "Unknown" | Geocoding API not enabled in Cloud Console |
| Camera black screen on emulator | Use a physical device; emulators often lack camera support |
| Photo not saved to gallery | Check storage permission was granted |
| Build fails with minSdk error | Ensure `minSdkVersion 21` in `android/app/build.gradle` |

---

## 📦 Dependencies

| Package | Version | Purpose |
|---|---|---|
| `google_maps_flutter` | ^2.5.3 | Interactive maps |
| `geolocator` | ^10.1.0 | GPS coordinates |
| `geocoding` | ^2.1.1 | Reverse geocoding |
| `camera` | ^0.10.5+5 | Camera access |
| `permission_handler` | ^11.1.0 | Runtime permissions |
| `provider` | ^6.1.1 | State management |
| `gal` | ^2.3.0 | Save to gallery |
| `intl` | ^0.19.0 | Date formatting |
| `http` | ^1.2.0 | Static Maps API |
| `path_provider` | ^2.1.2 | Temp file paths |

---

## 📄 License

MIT License — free for personal and commercial use.
