import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math' as math;

class LocationService extends ChangeNotifier {
  Position? _currentLocation;
  bool _isTracking = false;
  bool _isMockDriving = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _mockLocationTimer;

  Position? get currentLocation => _currentLocation;
  bool get isTracking => _isTracking;
  bool get isMockDriving => _isMockDriving;

  Future<bool> _checkPermissions() async {
    final status = await Permission.location.status;
    if (status.isDenied) {
      final result = await Permission.location.request();
      return result.isGranted;
    }
    return status.isGranted;
  }

  Future<void> startLocationTracking() async {
    if (_isTracking) return;

    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    // Set location settings for high accuracy
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _isTracking = true;
    notifyListeners();

    // Start listening to position changes
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _currentLocation = position;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Location tracking error: $error');
        _isTracking = false;
        notifyListeners();
      },
    );
  }

  Future<void> stopLocationTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
    notifyListeners();
  }

  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await _checkPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _currentLocation = position;
      notifyListeners();
      return position;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  double? getDistanceFromPoint(double lat, double lng) {
    if (_currentLocation == null) return null;
    
    return Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      lat,
      lng,
    );
  }

  // Route stop coordinates (QU campus coordinates) - Matches tracker app accurate locations
  static const Map<String, Map<String, double>> _routeStops = {
    'METRO': {'lat': 25.381821556363867, 'lng': 51.493005795317956},
    'D06': {'lat': 25.372171648170337, 'lng': 51.48486476066063},
    'C05': {'lat': 25.373318147272293, 'lng': 51.48752343321898},
    'B13': {'lat': 25.377533689714024, 'lng': 51.49026714070395},
    'H08': {'lat': 25.378395383948423, 'lng': 51.485941885442955},
    'H07': {'lat': 25.379161874420934, 'lng': 51.48791360317812},
    'I10': {'lat': 25.375778325356464, 'lng': 51.48285963578254},
    'I09': {'lat': 25.37498601479011, 'lng': 51.48144259906941},
    'I06': {'lat': 25.373318147272293, 'lng': 51.48752343321898}, // Approximate location
    'I08': {'lat': 25.375778325356464, 'lng': 51.48285963578254}, // Approximate location
    'I11': {'lat': 25.377069189896087, 'lng': 51.48474121692091},
    'H10': {'lat': 25.379784924283847, 'lng': 51.4898780698433},
    'B03': {'lat': 25.374577061639478, 'lng': 51.49314222276258},
    'A06': {'lat': 25.378368563094583, 'lng': 51.49158593932738},
    'A07': {'lat': 25.377006581555843, 'lng': 51.493157551764284},
  };

  // Route definitions with stop sequences
  static const Map<String, List<String>> _routes = {
    'blue_route': ['D06', 'C05', 'B13', 'H08'],
    'light_blue_route': ['D06', 'C05', 'H07'],
    'dark_green_route': ['D06', 'C05', 'I10'],
    'light_green_route': ['D06', 'C05', 'I09'],
    'purple_route': ['D06', 'I06'],
    'pink_route': ['C05', 'I06'],
    'orange_route': ['I08', 'H07', 'I09'],
    'black_line': [
      'METRO', 'D06', 'I06', 'I08', 'I09', 'I10',
      'I11', 'H08', 'H07', 'H10',
      'B13', 'B03', 'A06'
    ],
    'white_line': [
      'I09', 'I10', 'I11', 'H08',
      'H07', 'B13', 'B03'
    ],
    'brown_line': ['METRO', 'H10', 'B13', 'B03', 'A07'],
    'maroon_line': ['METRO', 'H08', 'H07'],
  };

  int _currentRouteIndex = 0;
  int _currentSegmentIndex = 0;
  double _segmentProgress = 0.0;
  List<String>? _currentRouteStops;

  void startMockDriving(String routeId) {
    if (_isMockDriving) return;

    final route = _routes[routeId];
    if (route == null || route.isEmpty) {
      debugPrint('Route not found: $routeId');
      return;
    }

    _currentRouteStops = List.from(route);
    _currentRouteIndex = 0;
    _currentSegmentIndex = 0;
    _segmentProgress = 0.0;

    // Set initial position to first stop
    final firstStop = _routeStops[_currentRouteStops![0]];
    if (firstStop != null) {
      _currentLocation = Position(
        latitude: firstStop['lat']!,
        longitude: firstStop['lng']!,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
      notifyListeners();
      debugPrint('Mock driving: Starting at ${_currentRouteStops![0]} (${firstStop['lat']}, ${firstStop['lng']})');
    }

    _isMockDriving = true;
    notifyListeners();

    // Update location every 1 second for smoother movement (still sends to Firebase every 2 seconds)
    _mockLocationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateMockLocation();
    });

    debugPrint('Started mock driving on route: $routeId with ${_currentRouteStops!.length} stops');
  }

  void _updateMockLocation() {
    if (_currentRouteStops == null || _currentRouteStops!.isEmpty) return;

    final routeSize = _currentRouteStops!.length;
    
    // Get current and next stop
    final currentStopId = _currentRouteStops![_currentSegmentIndex];
    final nextStopId = _currentRouteStops![(_currentSegmentIndex + 1) % routeSize];
    
    final currentStop = _routeStops[currentStopId];
    final nextStop = _routeStops[nextStopId];
    
    if (currentStop == null || nextStop == null) {
      debugPrint('Mock driving: Missing stop data for $currentStopId or $nextStopId');
      return;
    }

    // Calculate total distance to next stop
    final double totalDistance = _calculateDistance(
      currentStop['lat']!,
      currentStop['lng']!,
      nextStop['lat']!,
      nextStop['lng']!,
    );
    
    if (totalDistance == 0) {
      // Already at this stop, move to next
      _segmentProgress = 0.0;
      _currentSegmentIndex = (_currentSegmentIndex + 1) % routeSize;
      debugPrint('Mock driving: Skipping to next stop (distance is 0)');
      return;
    }

    // Speed: ~40 km/h = 11.11 m/s, update every 1 second = ~11.11 meters per update
    // This makes movement more visible and faster
    const double distancePerUpdate = 11.11; // meters per second
    
    _segmentProgress += distancePerUpdate;
    final progressRatio = (_segmentProgress / totalDistance).clamp(0.0, 1.0);

    if (progressRatio >= 1.0) {
      // Reached next stop, move to next segment
      _segmentProgress = 0.0;
      final previousStop = currentStopId;
      _currentSegmentIndex = (_currentSegmentIndex + 1) % routeSize;
      
      debugPrint('Mock driving: Reached stop $nextStopId (was at $previousStop). Moving to next segment.');
      
      // If completed full loop, we'll continue from the start
      if (_currentSegmentIndex >= routeSize) {
        _currentSegmentIndex = 0;
        debugPrint('Mock driving: Completed route loop, starting again from first stop');
      }
      
      // Use exact stop coordinates when reaching a stop
      _currentLocation = Position(
        latitude: nextStop['lat']!,
        longitude: nextStop['lng']!,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: _calculateHeading(
          currentStop['lat']!,
          currentStop['lng']!,
          nextStop['lat']!,
          nextStop['lng']!,
        ),
        speed: 11.11, // ~40 km/h in m/s
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    } else {
      // Interpolate between stops - smooth movement
      final lat = currentStop['lat']! + (nextStop['lat']! - currentStop['lat']!) * progressRatio;
      final lng = currentStop['lng']! + (nextStop['lng']! - currentStop['lng']!) * progressRatio;
      
      _currentLocation = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: _calculateHeading(
          currentStop['lat']!,
          currentStop['lng']!,
          nextStop['lat']!,
          nextStop['lng']!,
        ),
        speed: 11.11,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
      
      // Log progress occasionally (every 25% progress or at start)
      final progressPercent = (progressRatio * 100).round();
      if (progressPercent % 25 == 0 || progressRatio < 0.05) {
        debugPrint('Mock driving: $progressPercent% to $nextStopId (${totalDistance.toStringAsFixed(0)}m away, segment ${_currentSegmentIndex + 1}/$routeSize)');
      }
    }

    notifyListeners();
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  double _calculateHeading(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * math.pi / 180;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;

    final y = math.sin(dLng) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLng);

    final heading = math.atan2(y, x) * 180 / math.pi;
    return (heading + 360) % 360;
  }

  void stopMockDriving() {
    _mockLocationTimer?.cancel();
    _mockLocationTimer = null;
    _isMockDriving = false;
    _currentRouteStops = null;
    _currentSegmentIndex = 0;
    _segmentProgress = 0.0;
    notifyListeners();
    debugPrint('Stopped mock driving');
  }

  @override
  void dispose() {
    stopLocationTracking();
    stopMockDriving();
    super.dispose();
  }
}
