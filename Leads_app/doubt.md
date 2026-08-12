# Troubleshooting Guide: Resolving White Screen & KGP Warnings

Here is a simplified summary of what was done to fix the app startup crash (white screen) and what you need to do to complete the setup.

---

## 🛠️ What I Did (Developer Changes)

1. **Fixed Android App Permissions:**
   Added the missing internet, location, and notification permissions to your `android/app/src/main/AndroidManifest.xml` file. These are required for Firebase and Geolocator in release builds.
   
2. **Prevented GoRouter & Startup Crashes:**
   * Modified `lib/main.dart` to initialize Firebase App Check and Push Notifications asynchronously. If these services fail to connect (due to no internet or missing configs), the app will no longer freeze on startup.
   * Wrapped the GoRouter redirect logic in `lib/shared/routes/router.dart` inside a safe `try-catch` wrapper. If Firebase fails, the router will gracefully route to the login screen instead of crashing the Flutter rendering engine (which causes a permanent white screen).

3. **Added Error Diagnosing Banner:**
   Added a visible red error warning banner directly onto the `LoginScreen` (`lib/features/authentication/screens/login_screen.dart`). If Firebase initialization fails on your phone, you will now see the exact error message on your screen rather than a blank white screen, along with details on how to resolve it.

4. **KGP Legacy Compatibility Support:**
   Restored the standard Gradle configuration flags in `gradle.properties` (`android.builtInKotlin=false` and `android.newDsl=false`) so that the unmigrated third-party plugins in your project can build successfully without compilation errors.

---

## 📋 What You Need to Do (Steps to Run on Your Phone)

Because Firebase is initialized at startup, the app requires a valid native Firebase configuration to connect to your project:

1. **Download `google-services.json`:**
   * Go to your **Firebase Console** (for the project `worktrack-7a319`).
   * Select your **Android Application** (`com.example.worktrack`).
   * Download the `google-services.json` configuration file.

2. **Add `google-services.json` to the project:**
   * Paste the downloaded `google-services.json` file inside the `android/app/` directory of this project.

3. **Build the APK:**
   * Open your terminal in the project root and clean old cached items:
     ```bash
     flutter clean
     ```
   * Download dependencies:
     ```bash
     flutter pub get
     ```
   * Build the release APK:
     ```bash
     flutter build apk --release
     ```

4. **Install & Verify:**
   * Install the generated `app-release.apk` (found in `build/app/outputs/flutter-apk/`) onto your mobile device.
   * Open the app. The blue splash screen will show, followed by the login screen.
   * If there are configuration issues (e.g. incorrect SHA-1 key or missing `google-services.json`), the login screen will show a warning banner describing the exact error instead of getting stuck on a white screen.
