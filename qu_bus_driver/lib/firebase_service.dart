import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'driver_models.dart';
import 'dart:async';

class FirebaseService extends ChangeNotifier {
  DatabaseReference? _database;
  bool _isConnected = false;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;

  bool get isConnected => _isConnected && _database != null;

  Future<void> initialize() async {
    try {
      // Initialize Firebase Database instance with asia-southeast1 region
      // Database URL format: https://qu-link-default-rtdb.asia-southeast1.firebasedatabase.app/
      final database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://qu-link-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
      
      _database = database.ref();
      
      // Listen to connection state via .info/connected
      // This is the recommended way to check Firebase connection status
      final connectedRef = database.ref('.info/connected');
      _connectionSubscription = connectedRef.onValue.listen(
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

      // Test connection by reading a small value
      try {
        await _database!.child('.info/connected').once();
        debugPrint('Firebase Database initialized successfully');
      } catch (e) {
        debugPrint('Warning: Could not verify database connection: $e');
      }
    } catch (e, stackTrace) {
      debugPrint('Firebase initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      _isConnected = false;
      notifyListeners();
      // Don't rethrow - let app continue even if Firebase fails
      // User can retry later or use mock driving without Firebase
    }
  }

  Future<void> sendBusLocation(BusLocationData busData) async {
    if (_database == null) {
      debugPrint('Cannot send bus location: Firebase database not initialized');
      return;
    }
    
    try {
      final busRef = _database!.child('buses').child(busData.busId);
      
      await busRef.set({
        'busId': busData.busId,
        'driverName': busData.driverName,
        'routeId': busData.routeId,
        'latitude': busData.latitude,
        'longitude': busData.longitude,
        'timestamp': busData.timestamp.millisecondsSinceEpoch,
        'status': busData.status.toString().split('.').last,
        'lastUpdated': ServerValue.timestamp,
      });

      debugPrint('Bus location sent to Firebase: ${busData.busId}');
    } catch (e) {
      debugPrint('Error sending bus location to Firebase: $e');
    }
  }

  Future<void> updateBusStatus(String busId, BusStatus status) async {
    if (_database == null) {
      debugPrint('Cannot update bus status: Firebase database not initialized');
      return;
    }
    
    try {
      final busRef = _database!.child('buses').child(busId);
      await busRef.update({
        'status': status.toString().split('.').last,
        'lastUpdated': ServerValue.timestamp,
      });

      debugPrint('Bus status updated: $busId - $status');
    } catch (e) {
      debugPrint('Error updating bus status: $e');
    }
  }

  Future<void> removeBus(String busId) async {
    if (_database == null) {
      debugPrint('Cannot remove bus: Firebase database not initialized');
      return;
    }
    
    try {
      final busRef = _database!.child('buses').child(busId);
      await busRef.remove();
      debugPrint('Bus removed from Firebase: $busId');
    } catch (e) {
      debugPrint('Error removing bus: $e');
    }
  }

  // Get real-time stream of all buses
  Stream<Map<String, dynamic>> getBusesStream() {
    if (_database == null) {
      return Stream.value(<String, dynamic>{});
    }
    return _database!.child('buses').onValue.map((event) {
      if (event.snapshot.value != null) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return <String, dynamic>{};
    });
  }

  // Get real-time stream of specific bus
  Stream<Map<String, dynamic>?> getBusStream(String busId) {
    if (_database == null) {
      return Stream.value(null);
    }
    return _database!.child('buses').child(busId).onValue.map((event) {
      if (event.snapshot.value != null) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
