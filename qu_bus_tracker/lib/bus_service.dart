/// BusService (mock data and simulation)
///
/// Provides an in-memory simulation of buses, routes, and stops for the
/// QU campus. `BusService` exposes methods to initialize mock data,
/// retrieve route/stop information, and stream periodic bus position
/// updates to consuming widgets. It's implemented as a singleton so the
/// same simulated state is shared app-wide.
///
/// Responsibilities:
/// - Create and expose mock `Bus`, `BusRoute`, and `BusStop` data
/// - Simulate bus movement and broadcast updates via `busStream`
/// - Provide convenience lookups (routes for destination, stops by id)
///
/// Note: This is a demo-only service. Replace it with a real backend
/// implementation (e.g. Firebase) for production usage.



import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bus_models.dart';

class BusService extends ChangeNotifier{
  static final BusService _instance = BusService._internal();
  factory BusService() => _instance;
  BusService._internal();

  final List<BusRoute> _routes = [];
  final List<Bus> _buses = []; // kept empty by default; live buses come from backend
  final List<BusStop> _stops = [];

  bool _initialized = false;

  /// Initialize route and stop data
  Future<void> initializeMockData() async {
    if (_initialized) return;
    _initialized = true;

    await _createMockStops();
    await _createMockRoutes();
  }

  Future<void> _createMockStops() async {
    _stops.addAll([
      // Metro Station (Main Hub)
      BusStop(
        id: 'metro',
        name: 'Metro Station',
        description: 'Main QU Metro Station',
        location: const LatLng(25.381821556363867, 51.493005795317956),
        routes: ['black_line', 'brown_line', 'maroon_line'],
      ),
      
      // Female Classrooms Building (D06) - Main Hub for Routes
      BusStop(
        id: 'female_classrooms',
        name: 'Female Classrooms Building (GCR)',
        description: 'D06 - Female Classrooms Building',
        location: const LatLng(25.372171648170337, 51.48486476066063),
        routes: ['blue_route', 'light_blue_route', 'dark_green_route', 'light_green_route', 'purple_route', 'black_line'],
      ),
      
      // Women's Activity Center (C05)
      BusStop(
        id: 'womens_activity_center',
        name: 'Women\'s Activity Center',
        description: 'C05 - Women\'s Student Activity Center',
        location: const LatLng(25.373318147272293, 51.48752343321898),
        routes: ['blue_route', 'light_blue_route', 'dark_green_route', 'light_green_route', 'pink_route'],
      ),
      
      // Library (B13)
      BusStop(
        id: 'library',
        name: 'Library',
        description: 'B13 - Main University Library',
        location: const LatLng(25.377533689714024, 51.49026714070395),
        routes: ['blue_route', 'black_line', 'white_line', 'brown_line'],
      ),
      
      // College of Business and Economics (H08)
      BusStop(
        id: 'business',
        name: 'College of Business and Economics',
        description: 'H08 - College of Business and Economics',
        location: const LatLng(25.378395383948423, 51.485941885442955),
        routes: ['blue_route', 'black_line', 'white_line', 'maroon_line'],
      ),
      
      // College of Engineering (H07)
      BusStop(
        id: 'engineering',
        name: 'College of Engineering',
        description: 'H07 - College of Engineering',
        location: const LatLng(25.379161874420934, 51.48791360317812),
        routes: ['light_blue_route', 'black_line', 'white_line', 'maroon_line', 'orange_route'],
      ),
      
      // College of Education (I10)
      BusStop(
        id: 'education',
        name: 'New College of Education',
        description: 'I10 - College of Education',
        location: const LatLng(25.375778325356464, 51.48285963578254),
        routes: ['dark_green_route', 'black_line', 'white_line'],
      ),
      
      // College of Law (I09)
      BusStop(
        id: 'law',
        name: 'College of Law',
        description: 'I09 - College of Law',
        location: const LatLng(25.37498601479011, 51.48144259906941),
        routes: ['light_green_route', 'black_line', 'white_line', 'orange_route'],
      ),
      
      // Al Razi Building (H12) - Approximate location
      BusStop(
        id: 'al_razi',
        name: 'Al Razi Building',
        description: 'H12 - College of Dental Medicine / Medicine',
        location: const LatLng(25.373318147272293, 51.48752343321898), // Using Women's Activity as approximate reference
        routes: ['purple_route', 'pink_route', 'black_line'],
      ),
      
      // Ibn Al Baitar Building (I06) - Approximate location
      BusStop(
        id: 'ibn_al_baitar',
        name: 'Ibn Al Baitar Building',
        description: 'I06 - College of Pharmacy / Health Sciences',
        location: const LatLng(25.37498601479011, 51.48144259906941), // Using Law as approximate reference
        routes: ['purple_route', 'pink_route', 'black_line'],
      ),
      
      // Tamyuz Simulation Center (I08) - Approximate location
      BusStop(
        id: 'tamyuz_center',
        name: 'Tamyuz Simulation Center',
        description: 'I08 - Tamyuz Simulation Center',
        location: const LatLng(25.375778325356464, 51.48285963578254), // Using Education as approximate reference
        routes: ['orange_route', 'black_line'],
      ),
      
      // Student Affairs Building (I11)
      BusStop(
        id: 'students_affairs',
        name: 'Student Affairs Building',
        description: 'I11 - Students Affairs',
        location: const LatLng(25.377069189896087, 51.48474121692091),
        routes: ['black_line', 'white_line'],
      ),
      
      // Research Complex (H10)
      BusStop(
        id: 'research_complex',
        name: 'Research Complex',
        description: 'H10 - Research Complex',
        location: const LatLng(25.379784924283847, 51.4898780698433),
        routes: ['black_line', 'brown_line'],
      ),
      
      // Information Technology Services (B03)
      BusStop(
        id: 'it_services',
        name: 'Information Technology Services',
        description: 'B03 - ITS Building',
        location: const LatLng(25.374577061639478, 51.49314222276258),
        routes: ['black_line', 'white_line', 'brown_line'],
      ),
      
      // Men's Foundation Building (A06)
      BusStop(
        id: 'mens_foundation',
        name: 'Men\'s Foundation Building',
        description: 'A06 - Men\'s Foundation Building',
        location: const LatLng(25.378368563094583, 51.49158593932738),
        routes: ['black_line'],
      ),
      
      // Sports Facilities Department (A07)
      BusStop(
        id: 'sports_facilities',
        name: 'Sports and Events Complex',
        description: 'A07 - Sports and Events Complex',
        location: const LatLng(25.377006581555843, 51.493157551764284),
        routes: ['brown_line'],
      ),
    ]);
  }

  Future<void> _createMockRoutes() async {
    _routes.addAll([
      // OFFICIAL QU BUS ROUTES - 7 Horizontal Routes
      
      // Blue Route (المسار الأزرق)
      BusRoute(
        id: 'blue_route',
        name: 'Blue Route',
        description: 'Female Classrooms → Women\'s Activity → Library → Business',
        color: '#1976D2',
        stopIds: ['female_classrooms', 'womens_activity_center', 'library', 'business'],
        estimatedDuration: const Duration(minutes: 12),
      ),
      
      // Light Blue Route (المسار الأزرق الفاتح)
      BusRoute(
        id: 'light_blue_route',
        name: 'Light Blue Route',
        description: 'Female Classrooms → Women\'s Activity → Engineering',
        color: '#42A5F5',
        stopIds: ['female_classrooms', 'womens_activity_center', 'engineering'],
        estimatedDuration: const Duration(minutes: 10),
      ),
      
      // Dark Green Route (المسار الأخضر الغامق)
      BusRoute(
        id: 'dark_green_route',
        name: 'Dark Green Route',
        description: 'Female Classrooms → Women\'s Activity → Education',
        color: '#388E3C',
        stopIds: ['female_classrooms', 'womens_activity_center', 'education'],
        estimatedDuration: const Duration(minutes: 8),
      ),
      
      // Light Green Route (المسار الأخضر الفاتح)
      BusRoute(
        id: 'light_green_route',
        name: 'Light Green Route',
        description: 'Female Classrooms → Women\'s Activity → Law',
        color: '#66BB6A',
        stopIds: ['female_classrooms', 'womens_activity_center', 'law'],
        estimatedDuration: const Duration(minutes: 8),
      ),
      
      // Purple Route (المسار البنفسجي)
      BusRoute(
        id: 'purple_route',
        name: 'Purple Route',
        description: 'Female Classrooms → Al Razi → Ibn Al Baitar',
        color: '#7B1FA2',
        stopIds: ['female_classrooms', 'al_razi', 'ibn_al_baitar'],
        estimatedDuration: const Duration(minutes: 10),
      ),
      
      // Pink Route (المسار الوردي)
      BusRoute(
        id: 'pink_route',
        name: 'Pink Route',
        description: 'Women\'s Activity → Al Razi → Ibn Al Baitar',
        color: '#C2185B',
        stopIds: ['womens_activity_center', 'al_razi', 'ibn_al_baitar'],
        estimatedDuration: const Duration(minutes: 8),
      ),
      
      // Orange Route (المسار البرتقالي)
      BusRoute(
        id: 'orange_route',
        name: 'Orange Route',
        description: 'Tamyuz Simulation Center → Engineering → Law',
        color: '#F57C00',
        stopIds: ['tamyuz_center', 'engineering', 'law'],
        estimatedDuration: const Duration(minutes: 10),
      ),
      
      // OFFICIAL QU METRO LINES - 4 Metro Lines
      
      // Black Line (المسار الأسود) - Main Loop
      BusRoute(
        id: 'black_line',
        name: 'Black Line (Main Loop)',
        description: 'Complete campus tour - 25 minutes',
        color: '#212121',
        stopIds: [
          'metro', 'female_classrooms', 'ibn_al_baitar', 'tamyuz_center', 'law', 'education',
          'students_affairs', 'business', 'engineering', 'research_complex',
          'library', 'it_services', 'mens_foundation', 'al_razi'
        ],
        estimatedDuration: const Duration(minutes: 25),
      ),
      
      // White Line (المسار الأبيض) - Inner Loop
      BusRoute(
        id: 'white_line',
        name: 'White Line (Inner Loop)',
        description: 'Inner campus loop - 18 minutes',
        color: '#FAFAFA',
        stopIds: [
          'law', 'education', 'students_affairs', 'business',
          'engineering', 'library', 'it_services'
        ],
        estimatedDuration: const Duration(minutes: 18),
      ),
      
      // Brown Line (المسار البني) - Research & Sports
      BusRoute(
        id: 'brown_line',
        name: 'Brown Line (Research & Sports)',
        description: 'Research complex and sports facilities - 15 minutes',
        color: '#5D4037',
        stopIds: ['metro', 'research_complex', 'library', 'it_services', 'sports_facilities'],
        estimatedDuration: const Duration(minutes: 15),
      ),
      
      // Maroon Line (المسار العنابي) - Express
      BusRoute(
        id: 'maroon_line',
        name: 'Maroon Line (Express)',
        description: 'Quick express route - 8 minutes',
        color: '#8D6E63',
        stopIds: ['metro', 'business', 'engineering'],
        estimatedDuration: const Duration(minutes: 8),
      ),
    ]);
  }

  // No mock buses or simulation code. Live bus positions are expected to
  // be provided by `FirebaseBusService`. The `_buses` list remains empty
  // unless intentionally populated for testing.

  /// Get all bus routes
  List<BusRoute> getAllRoutes() {
    return List.from(_routes);
  }

  /// Get all bus stops
  List<BusStop> getAllStops() {
    return List.from(_stops);
  }

  /// Get all active buses
  List<Bus> getAllBuses() {
    return List.from(_buses);
  }

  /// Get routes that serve a specific destination
  List<BusRoute> getRoutesToDestination(String destinationName) {
    // Find the stop that matches the destination name
    final destinationStop = _stops.firstWhere(
      (stop) => stop.name.toLowerCase() == destinationName.toLowerCase(),
      orElse: () => BusStop(
        id: 'unknown',
        name: destinationName,
        description: '',
        location: const LatLng(0, 0),
        routes: [],
      ),
    );
    
    if (destinationStop.id == 'unknown') {
      return [];
    }
    
    return _routes.where((route) => 
        route.stopIds.contains(destinationStop.id)).toList();
  }

  /// Dispose resources
  @override
  void dispose() {
    // Nothing special to dispose
    super.dispose();
  }
}

