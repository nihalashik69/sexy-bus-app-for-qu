# QU Bus Tracker - Real-Time Location System

## 🚌 **System Overview**

This system consists of two Flutter apps working together to provide real-time bus tracking for Qatar University:

1. **Driver App** (`qu_bus_driver`) - Sends real-time GPS location data
2. **Student App** (`qu_bus_tracker`) - Receives and displays real-time bus locations

## 🔥 **Firebase Integration**

Both apps use **Firebase Realtime Database** for real-time communication:

- **Driver App**: Sends location updates every 3 seconds
- **Student App**: Receives live updates and displays buses on map
- **Real-time sync**: No server maintenance required
- **Offline support**: Works even with unstable connections

## 📱 **Driver App Features**

### Core Functionality:
- **GPS Location Tracking**: High-accuracy location updates
- **Route Selection**: Choose from 11 official QU bus routes
- **Real-time Broadcasting**: Sends location every 3 seconds
- **Status Management**: Start/stop tracking, update bus status
- **Firebase Integration**: Automatic data sync

### Available Routes:
- **7 Horizontal Routes**: Blue, Light Blue, Dark Green, Light Green, Purple, Pink, Orange
- **4 Metro Lines**: Black (Main Loop), White (Inner Loop), Brown (Research & Sports), Maroon (Express)

## 🎓 **Student App Features**

### Real-time Updates:
- **Live Bus Locations**: Orange markers show current bus positions
- **Driver Information**: Tap bus marker to see driver name and route
- **Connection Status**: Green/red indicator shows Firebase connection
- **Bus Count**: Shows number of active buses in real-time

### Enhanced Map Features:
- **Real-time Markers**: 
  - 🔵 Blue: Your location
  - 🔴 Red: Selected destination
  - 🟢 Green: Campus buildings
  - 🟠 Orange: Live buses (from Firebase)

## 🚀 **Setup Instructions**

### 1. Firebase Project Setup

1. Create Firebase project at [console.firebase.google.com](https://console.firebase.google.com/)
2. Enable Realtime Database
3. Set security rules (included in `firebase_database.rules.json`)
4. Get configuration files for both apps

### 2. Driver App Setup

```bash
cd qu_bus_driver
flutter pub get
```

**Android Configuration:**
- Add `google-services.json` to `android/app/`
- Update package name in `android/app/build.gradle`

**iOS Configuration:**
- Add `GoogleService-Info.plist` to `ios/Runner/`
- Update bundle ID in Xcode

### 3. Student App Setup

```bash
cd qu_bus_tracker
flutter pub get
```

**Android Configuration:**
- Add `google-services.json` to `android/app/`
- Update package name in `android/app/build.gradle`

**iOS Configuration:**
- Add `GoogleService-Info.plist` to `ios/Runner/`
- Update bundle ID in Xcode

### 4. Google Maps API Key

Both apps need Google Maps API key:

1. Get API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Maps SDK for Android/iOS
3. Update API key in:
   - `android/app/src/main/AndroidManifest.xml`
   - `ios/Runner/Info.plist`
   - `lib/maps_config.dart` (student app)

## 🧪 **Testing the System**

### 1. Start Driver App
1. Run driver app on device/emulator
2. Fill in driver name and bus ID
3. Select route
4. Tap "Start Tracking"
5. Verify Firebase connection is green

### 2. Start Student App
1. Run student app on different device/emulator
2. Check Firebase connection status (top of screen)
3. Look for orange bus markers on map
4. Tap bus markers to see driver info

### 3. Verify Real-time Updates
1. Move driver app to different location
2. Watch bus marker move on student app
3. Updates should appear within 3 seconds

## 📊 **Data Structure**

### Firebase Database Structure:
```json
{
  "buses": {
    "bus_001": {
      "busId": "bus_001",
      "driverName": "Ahmed Al-Mansouri",
      "routeId": "blue_route",
      "latitude": 25.3700,
      "longitude": 51.4831,
      "timestamp": 1703123456789,
      "status": "running",
      "lastUpdated": 1703123456789
    }
  }
}
```

## 🔧 **Configuration**

### Update Firebase Database URL:
In both apps, update `lib/firebase_service.dart`:
```dart
static const String _databaseUrl = 'https://your-project-id-default-rtdb.firebaseio.com/';
```

### Adjust Update Frequency:
In driver app `lib/driver_home_screen.dart`:
```dart
// Change from 3 seconds to desired interval
Stream.periodic(const Duration(seconds: 3))
```

## 🚨 **Troubleshooting**

### Common Issues:

1. **Firebase Connection Failed**
   - Check internet connection
   - Verify Firebase configuration files
   - Check security rules

2. **No Bus Markers on Map**
   - Ensure driver app is running and tracking
   - Check Firebase database for data
   - Verify Google Maps API key

3. **Location Permission Denied**
   - Grant location permissions in device settings
   - Check app permissions in Android/iOS settings

4. **Maps Not Loading**
   - Verify Google Maps API key
   - Check API key restrictions
   - Ensure Maps SDK is enabled

## 📈 **Performance**

- **Update Frequency**: 3 seconds (configurable)
- **Location Accuracy**: High accuracy GPS
- **Battery Usage**: Optimized for continuous tracking
- **Data Usage**: Minimal (only coordinates and metadata)
- **Scalability**: Firebase handles thousands of concurrent connections

## 🔒 **Security**

- **Firebase Rules**: Basic validation for bus data
- **Location Privacy**: Only coordinates sent, no personal data
- **Authentication**: Can be added for production use
- **Data Encryption**: Firebase handles encryption in transit

## 🚀 **Production Deployment**

1. **Update Security Rules**: Implement proper authentication
2. **Add Error Handling**: Robust error handling and retry logic
3. **Monitoring**: Set up Firebase monitoring and alerts
4. **Backup**: Configure automatic backups
5. **Testing**: Comprehensive testing with multiple devices

---

**Ready to track buses in real-time! 🚌📍**

