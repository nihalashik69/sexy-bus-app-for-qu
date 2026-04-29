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
      
      // Female Classrooms Building (D06) - Main Hub for Routes (updated)
      BusStop(
        id: 'female_classrooms',
        name: 'D06 Female Classrooms Building (GCR)',
        description: 'D06 - Female Classrooms Building',
        location: const LatLng(25.373481982344842, 51.4857422195123),
        routes: ['blue_route', 'light_blue_route', 'dark_green_route', 'light_green_route', 'purple_route', 'black_line'],
      ),
      
      // Women's Activity Center (C05) (updated)
      BusStop(
        id: 'womens_activity_center',
        name: 'C05 Women\'s Activity Center',
        description: 'C05 - Women\'s Student Activity Center',
        location: const LatLng(25.372089099584354, 51.488961932841086),
        routes: ['blue_route', 'light_blue_route', 'dark_green_route', 'light_green_route', 'pink_route'],
      ),

      
      // Al Razi Building (H12) - Approximate location
      BusStop(
        id: 'al_razi',
        name: 'H12 Al Razi Building (College of Dental Medicine / Medicine)',
        description: 'H12 - College of Dental Medicine / Medicine',
        location: const LatLng(25.373318147272293, 51.48752343321898), // Using Women's Activity as approximate reference
        routes: ['purple_route', 'pink_route', 'black_line'],
      ),
      
      // Ibn Al Baitar Building (I06) - updated to provided coordinate
      BusStop(
        id: 'ibn_al_baitar',
        name: 'I06 College of Pharmacy (Ibn Al-Baitar)',
        description: 'I06 - College of Pharmacy / Health Sciences',
        location: const LatLng(25.380643787796444, 51.481912360606444),
        routes: ['purple_route', 'pink_route', 'black_line'],
      ),
      
      // Tamyuz Simulation Center (I08) - updated
      BusStop(
        id: 'tamyuz_center',
        name: 'I08 Tamyuz Simulation Center',
        description: 'I08 - Tamyuz Simulation Center',
        location: const LatLng(25.37988015721793, 51.482720527517),
        routes: ['orange_route', 'black_line'],
      ),
      
      // Research Complex (H10) (updated)
      BusStop(
        id: 'research_complex',
        name: 'Research Complex',
        description: 'H10 - Research Complex',
        location: const LatLng(25.379627085925716, 51.49016028066605),
        routes: ['black_line', 'brown_line'],
      ),
      
      // Information Technology Services (B03) (updated)
      BusStop(
        id: 'it_services',
        name: 'B03 Information Technology Services',
        description: 'B03 - ITS Building',
        location: const LatLng(25.37524774172289, 51.492901227889526),
        routes: ['black_line', 'white_line', 'brown_line'],
      ),
      
      // Men's Foundation Building (A06) (updated)
      BusStop(
        id: 'mens_foundation',
        name: 'A06 Men\'s Foundation Building',
        description: 'A06 - Men\'s Foundation Building',
        location: const LatLng(25.378124440299285, 51.49158060045566),
        routes: ['black_line'],
      ),
      
      // Sports Facilities Department (A07) (updated)
      BusStop(
        id: 'sports_facilities',
        name: 'A07 Sports and Events Complex',
        description: 'A07 - Sports and Events Complex',
        location: const LatLng(25.377296788397643, 51.49312032574497),
        routes: ['brown_line'],
      ),

      // --- New / variant stops added (routes left blank as requested) ---

      // College of Law - male/female variants
      BusStop(
        id: 'law_male',
        name: 'I09 College of Law (Male)',
        description: 'I09 - College of Law (Male)',
        location: const LatLng(25.376087457119596, 51.48069196590328),
        routes: [],
      ),
      BusStop(
        id: 'law_female',
        name: 'I09 College of Law (Female)',
        description: 'I09 - College of Law (Female)',
        location: const LatLng(25.374783619645747, 51.481530834481795),
        routes: [],
      ),

      // College of Education - male/female variants
      BusStop(
        id: 'education_male',
        name: 'I10 College of Education (Male)',
        description: 'I10 - College of Education (Male)',
        location: const LatLng(25.37658898975716, 51.4828877414271),
        routes: [],
      ),
      BusStop(
        id: 'education_female',
        name: 'I10 College of Education (Female)',
        description: 'I10 - College of Education (Female)',
        location: const LatLng(25.37560672476257, 51.48242239454162),
        routes: [],
      ),

      // Student Affairs - male/female variants
      BusStop(
        id: 'students_affairs_male',
        name: 'I11 Student Affairs Building (Male)',
        description: 'I11 - Student Affairs (Male)',
        location: const LatLng(25.377979388163364, 51.48388511757748),
        routes: [],
      ),
      BusStop(
        id: 'students_affairs_female',
        name: 'I11 Student Affairs Building (Female)',
        description: 'I11 - Student Affairs (Female)',
        location: const LatLng(25.376323831360903, 51.48494350153811),
        routes: [],
      ),

      // College of Nursing (new)
      BusStop(
        id: 'nursing',
        name: 'I03 College of Nursing',
        description: 'I03 - College of Nursing',
        location: const LatLng(25.378817713816293, 51.48342119215998),
        routes: [],
      ),

      // College of Pharmacy (Ibn Al-Baitar) - added as updated above; also add explicit male/female not provided (keep single entry)

      // College of Business and Economics - male/female variants
      BusStop(
        id: 'business_male',
        name: 'H08 College of Business and Economics (Male)',
        description: 'H08 - College of Business and Economics (Male)',
        location: const LatLng(25.378627213100078, 51.485784586139374),
        routes: [],
      ),
      BusStop(
        id: 'business_female',
        name: 'H08 College of Business and Economics (Female)',
        description: 'H08 - College of Business and Economics (Female)',
        location: const LatLng(25.3767535825156, 51.48698055938411),
        routes: [],
      ),

      // College of Engineering - male/female variants
      BusStop(
        id: 'engineering_male',
        name: 'H07 College of Engineering (Male)',
        description: 'H07 - College of Engineering (Male)',
        location: const LatLng(25.380083667560896, 51.48692088481661),
        routes: [],
      ),
      BusStop(
        id: 'engineering_female',
        name: 'H07 College of Engineering (Female)',
        description: 'H07 - College of Engineering (Female)',
        location: const LatLng(25.378934489421194, 51.48663916055145),
        routes: [],
      ),

      // Research Complex - already updated above (no duplicate)

      // College Of Medicine (H12) - new
      BusStop(
        id: 'college_of_medicine',
        name: 'H12 College of Medicine',
        description: 'H12 - College of Medicine',
        location: const LatLng(25.38046481732248, 51.491811717125984),
        routes: [],
      ),

      // Library - male/female variants
      BusStop(
        id: 'library_male',
        name: 'B13 Library (Male)',
        description: 'B13 - Library (Male)',
        location: const LatLng(25.377661503696263, 51.49047014057098),
        routes: [],
      ),
      BusStop(
        id: 'library_female',
        name: 'B13 Library (Female)',
        description: 'B13 - Library (Female)',
        location: const LatLng(25.37750423808213, 51.488897080467154),
        routes: [],
      ),

      // Women's Foundation (D05)
      BusStop(
        id: 'womens_foundation',
        name: 'D05 Women\'s Foundation',
        description: 'D05 - Women\'s Foundation',
        location: const LatLng(25.374760002402123, 51.48711292847968),
        routes: [],
      ),

      // Women's Food Court (D04)
      BusStop(
        id: 'womens_food_court',
        name: 'D04 Women\'s Food Court',
        description: 'D04 - Women\'s Food Court',
        location: const LatLng(25.37367115319947, 51.48777028639902),
        routes: [],
      ),

      // College of Sharia & Islamic Studies (Bldn A) (C11)
      BusStop(
        id: 'sharia_a',
        name: 'C11 College of Sharia & Islamic Studies (Bldn A)',
        description: 'C11 - College of Sharia & Islamic Studies (Building A)',
        location: const LatLng(25.374296317071014, 51.48757258895679),
        routes: [],
      ),

      // College of Sharia & Islamic Studies (Bldn B) (C07)
      BusStop(
        id: 'sharia_b',
        name: 'C07 College of Sharia & Islamic Studies (Bldn B)',
        description: 'C07 - College of Sharia & Islamic Studies (Building B)',
        location: const LatLng(25.373260616357925, 51.48825006414136),
        routes: [],
      ),

      // Information Technology Services (B03) already updated above

      // Sports Facilities and Events Department (A07) already updated above

      // Tamayuz Simulation Center (I08) already updated above

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

