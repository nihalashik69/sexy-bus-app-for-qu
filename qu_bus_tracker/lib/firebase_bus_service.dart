/// Firebase-backed bus service
///
/// Connects to Firebase Realtime Database to receive live bus position
/// updates and maps remote snapshots to local `Bus` models. The service
/// exposes `liveBuses` and connection state to the UI and merges mock
/// buses as needed to improve coverage when real data is sparse.
///
/// Responsibilities:
/// - Initialize Firebase database reference and listeners
/// - Parse database events into `Bus` objects
/// - Expose connection status and a map of live buses for consumers

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bus_models.dart';
import 'dart:async';

class FirebaseBusService extends ChangeNotifier {
  late DatabaseReference _database;
  bool _isConnected = false;
  StreamSubscription<DatabaseEvent>? _busesSubscription;
  Map<String, Bus> _liveBuses = {};
  // No mock buses: live data comes from Firebase

  Map<String, Bus> get liveBuses => Map.from(_liveBuses);
  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    try {
      // Initialize Firebase Database instance with asia-southeast1 region
      // Must match the driver app's database URL
      final database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://qu-link-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
      
      _database = database.ref();
      
      // Listen to connection state via .info/connected
      final connectedRef = database.ref('.info/connected');
      connectedRef.onValue.listen(
        (event) {
          final connected = event.snapshot.value as bool? ?? false;
          _isConnected = connected;
          debugPrint('Firebase connection state: $_isConnected');
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Firebase connection error: $error');
          _isConnected = false;
          notifyListeners();
        },
      );

      // Listen to real-time bus updates
      _startListeningToBuses();
      
  // Do not create mock buses; rely on real Firebase data
      
      debugPrint('Firebase Bus Service initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('Firebase Bus Service initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      _isConnected = false;
      notifyListeners();
    }
  }

  void _startListeningToBuses() {
    _busesSubscription = _database.child('buses').onValue.listen(
      (DatabaseEvent event) {
        if (event.snapshot.value != null) {
          final Map<dynamic, dynamic> busesData = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          _updateLiveBuses(busesData);
        } else {
          _liveBuses.clear();
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('Error listening to buses: $error');
      },
    );
  }

  void _updateLiveBuses(Map<dynamic, dynamic> busesData) {
    _liveBuses.clear();
    
    busesData.forEach((busId, busData) {
      try {
        // Extract bus ID - prefer 'busId' from data, fallback to Firebase key
        final extractedBusId = busData['busId']?.toString() ?? busId.toString();
        final extractedDriverName = busData['driverName']?.toString() ?? 'Unknown Driver';
        final extractedRouteId = busData['routeId']?.toString() ?? '';
        
        // Debug log to verify data extraction
        if (extractedDriverName == 'Unknown Driver' || extractedDriverName.isEmpty) {
          debugPrint('Warning: Bus $extractedBusId has missing driver name. Data: $busData');
        }
        
        final bus = Bus(
          id: extractedBusId,
          routeId: extractedRouteId,
          driverName: extractedDriverName.isEmpty ? 'Unknown Driver' : extractedDriverName,
          capacity: 50, // Default capacity
          currentLocation: LatLng(
            (busData['latitude'] ?? 0.0).toDouble(),
            (busData['longitude'] ?? 0.0).toDouble(),
          ),
          heading: 0.0, // Default heading
          lastUpdated: DateTime.fromMillisecondsSinceEpoch(
            busData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
          ),
          status: _parseBusStatus(busData['status'] ?? 'unknown'),
          currentStopIndex: 0, // Default stop index
          estimatedArrival: DateTime.now().add(const Duration(minutes: 5)),
        );
        
        _liveBuses[extractedBusId] = bus;
        debugPrint('Parsed bus: ID=$extractedBusId, Driver=$extractedDriverName, Route=$extractedRouteId');
      } catch (e) {
        debugPrint('Error parsing bus data for $busId: $e');
      }
    });
    
    notifyListeners();
    debugPrint('Updated ${_liveBuses.length} live buses');
  }

  BusStatus _parseBusStatus(String status) {
    switch (status.toLowerCase()) {
      case 'running':
        return BusStatus.running;
      case 'stopped':
        return BusStatus.stopped;
      case 'outofservice':
        return BusStatus.outOfService;
      case 'delayed':
        return BusStatus.delayed;
      default:
        return BusStatus.unknown;
    }
  }

  // Get all active buses (real + mock)
  List<Bus> getAllActiveBuses() {
    // Only return real live buses from Firebase
    return _liveBuses.values.where((bus) => bus.status == BusStatus.running).toList();
  }

  // Create mock buses for all routes
  // No mock bus creation: disabled

  @override
  void dispose() {
    _busesSubscription?.cancel();
    super.dispose();
  }
}
