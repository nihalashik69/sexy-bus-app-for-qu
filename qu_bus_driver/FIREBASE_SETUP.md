# Firebase Setup Instructions for QU Bus Driver App

## Current Configuration

- **Firebase Project**: `qu-link`
- **Project ID**: `qu-link`
- **Android Package Name**: `com.nihal.qudriver`
- **Database URL**: Automatically detected from `google-services.json`

## 1. Verify Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `qu-link`
3. Verify the project is active and configured

## 2. Android Configuration

### Verify google-services.json

The `google-services.json` file should already be in `android/app/` directory with:
- **Package Name**: `com.nihal.qudriver` (must match `android/app/build.gradle.kts`)
- **Project ID**: `qu-link`

### Build Configuration

The app already has:
- ✅ `google-services` plugin in `android/settings.gradle.kts`
- ✅ `google-services` plugin applied in `android/app/build.gradle.kts`
- ✅ `google-services.json` in `android/app/` directory

### If you need to regenerate google-services.json:

1. In Firebase Console → Project Settings
2. Go to "Your apps" section
3. Find the Android app with package name `com.nihal.qudriver`
4. Download the latest `google-services.json`
5. Replace the file in `android/app/` directory

## 3. Enable Realtime Database

1. In Firebase Console, go to "Realtime Database"
2. If not created, click "Create Database"
3. Choose "Start in test mode" (for development)
4. Select location closest to Qatar (e.g., `asia-southeast1`)
5. Note the database URL (e.g., `https://qu-link-default-rtdb.asia-southeast1.firebasedatabase.app/`)

The database URL is automatically read from `google-services.json`, so no code changes are needed.

## 4. Firebase Initialization

The app automatically initializes Firebase:
- `main.dart` calls `Firebase.initializeApp()` on startup
- `FirebaseService.initialize()` is called when the home screen loads
- Connection status is monitored via `.info/connected`

## 5. Security Rules

The app includes `firebase_database.rules.json` with basic security rules:

```json
{
  "rules": {
    "buses": {
      "$busId": {
        ".read": true,
        ".write": true,
        ".validate": "newData.hasChildren(['busId', 'driverName', 'routeId', 'latitude', 'longitude', 'timestamp', 'status'])"
      }
    }
  }
}
```

## 6. Test the Setup

1. Run the driver app
2. Fill in driver information
3. Start tracking
4. Check Firebase Console → Realtime Database to see live data

## 6. Test the Setup

1. Clean build: `flutter clean` then `flutter pub get`
2. Run the driver app: `flutter run`
3. Check console logs for "Firebase Database initialized successfully"
4. Fill in driver information (name, bus ID, route)
5. Start tracking
6. Check Firebase Console → Realtime Database to see live data at `/buses/{busId}`

## 7. Troubleshooting

### Issue: Firebase initialization fails

**Symptoms**: App crashes on startup or "Firebase initialization error" in logs

**Solutions**:
1. Verify `google-services.json` is in `android/app/` directory
2. Check that package name in `google-services.json` matches `android/app/build.gradle.kts`
3. Ensure `google-services` plugin is applied in both:
   - `android/settings.gradle.kts` (line 24)
   - `android/app/build.gradle.kts` (line 6)
4. Clean and rebuild: `flutter clean && flutter pub get && flutter run`

### Issue: Cannot connect to Firebase Database

**Symptoms**: Connection status shows false, no data appears in Firebase

**Solutions**:
1. Verify Realtime Database is created in Firebase Console
2. Check database security rules allow read/write (should be in test mode for development)
3. Verify internet connection on device/emulator
4. Check Firebase Console → Realtime Database → Rules tab
5. Look for error messages in app console logs

### Issue: Package name mismatch

**Symptoms**: Build errors about package name or Firebase not found

**Solutions**:
1. Ensure `applicationId` in `android/app/build.gradle.kts` is `com.nihal.qudriver`
2. Ensure `namespace` in `android/app/build.gradle.kts` is `com.nihal.qudriver`
3. Ensure `package_name` in `google-services.json` is `com.nihal.qudriver`
4. All three must match exactly

### Issue: Google Services plugin not found

**Symptoms**: Build error: "Could not find plugin 'com.google.gms.google-services'"

**Solutions**:
1. Check `android/settings.gradle.kts` has the plugin:
   ```kotlin
   id("com.google.gms.google-services") version "4.4.2" apply false
   ```
2. Check `android/app/build.gradle.kts` applies the plugin:
   ```kotlin
   id("com.google.gms.google-services")
   ```
3. Sync Gradle files

## 8. Production Considerations

- Update security rules for production (implement authentication)
- Add rate limiting to prevent abuse
- Set up monitoring and alerts in Firebase Console
- Configure backup policies for Realtime Database
- Consider implementing Firebase App Check for additional security

