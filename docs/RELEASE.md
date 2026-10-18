# Marg — Production Release Guide

This document describes the end-to-end production build and Google Play Console release process for Marg (Pune PMPML Bus Planner).

---

## 1. Prerequisites

- **Flutter**: 3.24+ (Stable channel)
- **Android SDK**: API 34+ (targetSdk 34, minSdk 26)
- **Java JDK**: Version 17 (JBR bundled with Android Studio or OpenJDK 17)
- **Android Studio / Command-line Tools** with `keytool` and `adb`

---

## 2. Release Signing & Keystore Setup

Android requires all App Bundles (`.aab`) and APKs to be cryptographically signed with an upload key before distribution.

### Step 2.1: Generate the Upload Keystore
Run the following command to generate your upload keystore:
```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias marg-upload-key \
  -storepass <YOUR_SECURE_PASSWORD> \
  -keypass <YOUR_SECURE_PASSWORD> \
  -dname "CN=Marg Transit, OU=Mobile, O=Marg, L=Pune, ST=Maharashtra, C=IN"
```
Place `upload-keystore.jks` in `pump/mobile/android/`.

> **Security Warning**:
> Never commit `upload-keystore.jks` or `key.properties` to version control. Both are already listed in `.gitignore`. Store the keystore and passwords securely in your team password vault.

### Step 2.2: Configure `key.properties`
Create `pump/mobile/android/key.properties` (or copy from `key.properties.example`):
```properties
keyAlias=marg-upload-key
keyPassword=<YOUR_KEY_PASSWORD>
storeFile=upload-keystore.jks
storePassword=<YOUR_STORE_PASSWORD>
```

The build system in `pump/mobile/android/app/build.gradle.kts` automatically loads `key.properties` when building release artifacts. If `key.properties` is absent, it safely falls back to the debug signing configuration so continuous integration and local builds succeed.

---

## 3. Versioning

Update the version number in `pump/mobile/pubspec.yaml` before every release:
```yaml
version: 1.0.0+1
```
- **Version Name** (`1.0.0`): User-visible semantic version (Major.Minor.Patch).
- **Version Code** (`1`): Positive integer incremented with every Play Console upload. Google Play rejects uploads with version codes less than or equal to existing releases.

You can also override version parameters during build:
```bash
flutter build appbundle --release --build-name=1.0.1 --build-number=2
```

---

## 4. Building Release Artifacts

Navigate to `pump/mobile`:
```bash
cd pump/mobile
flutter clean
flutter pub get
```

### 4.1: Production Android App Bundle (.aab)
Google Play requires `.aab` for all new app releases:
```bash
flutter build appbundle --release \
  --dart-define=API_BASE=https://<your-backend-host>/api/v1
```
Output artifact:
`pump/mobile/build/app/outputs/bundle/release/app-release.aab`

### 4.2: Universal Release APK (for Local Device Smoke Testing)
To test the release build directly on physical Android test devices or emulators:
```bash
flutter build apk --release \
  --dart-define=API_BASE=https://<your-backend-host>/api/v1
```
Output artifact:
`pump/mobile/build/app/outputs/flutter-apk/app-release.apk`

Install and verify on a connected device:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 5. Google Play Console Release Steps

### Step 5.1: Create App & Store Listing
1. Log in to [Google Play Console](https://play.google.com/console).
2. Click **Create app**:
   - **App name**: `Marg: Pune Bus Planner`
   - **Default language**: English (India)
   - **App or game**: App
   - **Free or paid**: Free
   - Accept Declarations and click **Create app**.

### Step 5.2: Store Presence & Metadata
Under **Grow** > **Store presence** > **Main store listing**:
- **Short description** (max 80 chars):
  `Pune PMPML bus route planner with fast schedules, transfers, and calm alerts.`
- **Full description** (max 4000 chars):
  `Marg is the Apple-quality public transit planner designed specifically for Pune's PMPML bus network.\n\nKey features:\n• Ranked route search: Fastest, fewest transfers, or least walking\n• Clear timetable navigation with scheduled arrival times\n• Stop-by-stop route explorer with live haversine proximity\n• Saved frequent locations (Home & Work) and favorite lines\n• Custom delay reminders and local service alerts\n• Dark mode and TalkBack accessibility support\n\nBuilt with clean typography, high contrast, and offline-first resilience.`
- **App icon**: 512 x 512 px PNG (located at `pump/mobile/assets/icon/app_icon_512.png`).
- **Feature graphic**: 1024 x 500 px JPEG or 24-bit PNG.
- **Phone screenshots**: Light and Dark screenshots from `proof/` (minimum 4 screenshots).

### Step 5.3: App Content & Declarations
Under **Policy and programs** > **App content**:
1. **Privacy Policy**: Provide URL explaining that user coordinates are used only locally on-device for stop proximity and route ranking.
2. **Ads**: Select "No, my app does not contain ads".
3. **App Access**: All functionality is available without login credentials.
4. **Target Audience**: 13 and older.
5. **Data Safety**:
   - Data collection: Approximate and precise location.
   - Purpose: App functionality (transit route planning).
   - Data sharing: Not shared with third parties.
   - Encryption: Encrypted in transit (HTTPS/TLS).
6. **Government Apps**: Marg is an independent transit companion and not an official government entity.

### Step 5.4: Play App Signing
1. Under **Release** > **Setup** > **App signing**, opt in to **Play App Signing**.
2. Select **Use Google-generated key** or upload your export certificate.

### Step 5.5: Internal Testing & Closed Beta
1. Go to **Release** > **Testing** > **Internal testing**.
2. Click **Create new release**.
3. Upload `app-release.aab` from `pump/mobile/build/app/outputs/bundle/release/`.
4. Enter release notes (e.g., `Initial release of Marg v1.0.0: PMPML transit routing`).
5. Add internal email testers and share the join URL.
6. Verify smoke test checklist (see Section 6).

### Step 5.6: Production Rollout
1. Promote the approved test release to **Production**.
2. Configure **Staged Rollout** (recommended: 20% on Day 1, 50% on Day 2, 100% on Day 3).
3. Monitor Google Play Android Vitals for crash rates and ANR metrics.

---

## 6. Pre-Flight Verification Checklist

Before publishing any production build:
- [x] Adaptive icon foreground & background render correctly on Android 8+ launchers.
- [x] Android 12+ splash screen (`SplashScreen` API) transitions smoothly to Welcome/Explore.
- [x] Location permission prompt contains clear, upfront rationale before requesting.
- [x] Schedule progress is honestly labelled **Scheduled** (never fake "LIVE GPS").
- [x] Cold-start 503 retry and offline states render appropriate skeletons and retry CTAs.
- [x] `flutter analyze` reports zero errors or warnings.
- [x] Automated test suite passes (`flutter test`).
- [x] Release bundle is signed with production upload key.
