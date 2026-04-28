# Building and Deploying QU Bus Driver App

## Requirements Checklist

### ✅ Completed Setup

1. **Firebase Configuration**
   - ✅ `google-services.json` in `android/app/` directory
   - ✅ Firebase plugins configured in Gradle
   - ✅ Database URL set to `asia-southeast1` region
   - ✅ Error handling to prevent crashes

2. **Android Configuration**
   - ✅ Package name: `com.nihal.qudriver`
   - ✅ Min SDK: 23 (required for Firebase)
   - ✅ All required permissions in AndroidManifest.xml
   - ✅ Google Services plugin applied

3. **App Features**
   - ✅ Location tracking
   - ✅ Mock driving simulation
   - ✅ Firebase real-time updates
   - ✅ Error handling and crash prevention

## What's Needed for the App to Work

### 1. Firebase Setup (Must be done in Firebase Console)

1. Go to https://console.firebase.google.com/
2. Select project: **qu-link**
3. **Enable Realtime Database**:
   - Go to Build → Realtime Database
   - Click "Create Database" if not exists
   - Choose region: **asia-southeast1 (Singapore)**
   - Choose "Start in test mode" for development
   - Database URL will be: `https://qu-link-default-rtdb.asia-southeast1.firebasedatabase.app`

4. **Set Database Rules** (in Realtime Database → Rules tab):
   ```json
   {
     "rules": {
       "buses": {
         ".read": true,
         ".write": true
       }
     }
   }
   ```

### 2. App Requirements

- **Android 6.0 (API 23)** or higher
- **Internet connection** for Firebase
- **Location permissions** (granted at runtime)
- **Google Play Services** (usually pre-installed)

## Building the APK

### Debug APK (for testing)

```bash
cd qu_bus_driver
flutter clean
flutter pub get
flutter build apk --debug
```

The APK will be at: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK (for distribution)

```bash
cd qu_bus_driver
flutter clean
flutter pub get
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

**Note:** Release APK uses debug signing keys (not for Play Store distribution).

### App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

The AAB will be at: `build/app/outputs/bundle/release/app-release.aab`

## Testing Before Distribution

1. Install APK on a test device
2. Verify:
   - App opens without crashing
   - Firebase connection status shows
   - Mock driving works
   - Location updates appear in Firebase Console
   - Tracker app can see the bus

## Known Issues Fixed

- ✅ Firebase initialization won't crash app (graceful error handling)
- ✅ Location permission denials handled gracefully
- ✅ Mock driving works even if Firebase fails
- ✅ All null checks in place

## Troubleshooting

### APK won't install
- Check device has Android 6.0+
- Enable "Install from unknown sources"
- Check APK isn't corrupted

### App crashes on startup
- Check Firebase is initialized (console logs)
- Verify `google-services.json` exists
- Check internet connection

### Firebase not connecting
- Verify Realtime Database is created in Firebase Console
- Check database rules allow read/write
- Verify database region is `asia-southeast1`

