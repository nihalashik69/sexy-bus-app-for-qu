import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';
import 'firebase_service.dart';
import 'driver_models.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _busIdController = TextEditingController();
  final TextEditingController _routeIdController = TextEditingController();
  
  bool _isTracking = false;
  String _selectedRoute = 'blue_route';

  // Available routes for selection
  final List<Map<String, String>> _availableRoutes = [
    {'id': 'blue_route', 'name': 'Blue Route', 'description': 'Female Classrooms → Women\'s Activity → Library → Business'},
    {'id': 'light_blue_route', 'name': 'Light Blue Route', 'description': 'Female Classrooms → Women\'s Activity → Engineering'},
    {'id': 'dark_green_route', 'name': 'Dark Green Route', 'description': 'Female Classrooms → Women\'s Activity → Education'},
    {'id': 'light_green_route', 'name': 'Light Green Route', 'description': 'Female Classrooms → Women\'s Activity → Law'},
    {'id': 'purple_route', 'name': 'Purple Route', 'description': 'Female Classrooms → Al Razi → Ibn Al Baitar'},
    {'id': 'pink_route', 'name': 'Pink Route', 'description': 'Women\'s Activity → Al Razi → Ibn Al Baitar'},
    {'id': 'orange_route', 'name': 'Orange Route', 'description': 'Tamyuz Simulation Center → Engineering → Law'},
    {'id': 'black_line', 'name': 'Black Line (Main Loop)', 'description': 'Complete campus tour - 25 minutes'},
    {'id': 'white_line', 'name': 'White Line (Inner Loop)', 'description': 'Inner campus loop - 18 minutes'},
    {'id': 'brown_line', 'name': 'Brown Line (Research & Sports)', 'description': 'Research complex and sports facilities - 15 minutes'},
    {'id': 'maroon_line', 'name': 'Maroon Line (Express)', 'description': 'Quick express route - 8 minutes'},
  ];

  String _getSelectedRouteName() {
    final route = _availableRoutes.firstWhere(
      (r) => r['id'] == _selectedRoute,
      orElse: () => {'name': 'Unknown Route'},
    );
    return route['name']!;
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.initialize();
    } catch (e) {
      debugPrint('Error initializing Firebase in UI: $e');
      // Show user-friendly message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firebase connection issue. Mock driving will still work.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ].request();
  }

  Future<void> _startTracking() async {
    if (_driverNameController.text.isEmpty || _busIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in driver name and bus ID'),
          backgroundColor: Color(0xFF8B0000),
        ),
      );
      return;
    }

    try {
      final locationService = Provider.of<LocationService>(context, listen: false);
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);

      // Start location tracking (works with mock driving too)
      try {
        await locationService.startLocationTracking();
      } catch (e) {
        debugPrint('Location tracking error: $e');
        // If real GPS fails but mock driving is active, continue
        if (!locationService.isMockDriving) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location tracking failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Start sending location data
      _startLocationBroadcast();

      setState(() {
        _isTracking = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location tracking started'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error starting tracking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startLocationBroadcast() {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);

    // Send location updates every 2 seconds
    Stream.periodic(const Duration(seconds: 2)).listen((_) async {
      if (_isTracking && firebaseService.isConnected) {
        // Use current location (from mock driving if active, or real GPS)
        Position? location = locationService.currentLocation;
        
        // If mock driving is active, use mock location; otherwise get real GPS location
        if (!locationService.isMockDriving) {
          location = await locationService.getCurrentLocation();
        }
        
        if (location != null) {
          final busData = BusLocationData(
            busId: _busIdController.text,
            driverName: _driverNameController.text,
            routeId: _selectedRoute,
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: DateTime.now(),
            status: BusStatus.running,
          );

          firebaseService.sendBusLocation(busData);
        }
      }
    });
  }

  Future<void> _stopTracking() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);

    await locationService.stopLocationTracking();
    await firebaseService.removeBus(_busIdController.text);

    setState(() {
      _isTracking = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location tracking stopped'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _startMockDriving() {
    final locationService = Provider.of<LocationService>(context, listen: false);
    locationService.startMockDriving(_selectedRoute);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Started mock driving on ${_getSelectedRouteName()}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _stopMockDriving() {
    final locationService = Provider.of<LocationService>(context, listen: false);
    locationService.stopMockDriving();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stopped mock driving'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QU Bus Driver',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF8B0000),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Driver Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B0000),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _driverNameController,
                      decoration: const InputDecoration(
                        labelText: 'Driver Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person, color: Color(0xFF8B0000)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _busIdController,
                      decoration: const InputDecoration(
                        labelText: 'Bus ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_bus, color: Color(0xFF8B0000)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Route Selection Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Route',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B0000),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRoute,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.route, color: Color(0xFF8B0000)),
                      ),
                      isExpanded: true,
                      selectedItemBuilder: (BuildContext context) {
                        return _availableRoutes.map((route) {
                          return Text(
                            route['name']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          );
                        }).toList();
                      },
                      items: _availableRoutes.map((route) {
                        return DropdownMenuItem<String>(
                          value: route['id'],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                route['name']!,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                route['description']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRoute = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Location Status Card
            Consumer2<LocationService, FirebaseService>(
              builder: (context, locationService, firebaseService, child) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B0000),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusRow(
                          'Location Tracking',
                          locationService.isTracking ? 'Active' : 'Inactive',
                          locationService.isTracking ? Colors.green : Colors.red,
                        ),
                        const SizedBox(height: 8),
                        _buildStatusRow(
                          'Firebase Connection',
                          firebaseService.isConnected ? 'Connected' : 'Disconnected',
                          firebaseService.isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(height: 8),
                        _buildStatusRow(
                          'Mock Driving',
                          locationService.isMockDriving ? 'Active' : 'Inactive',
                          locationService.isMockDriving ? Colors.orange : Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        if (locationService.currentLocation != null)
                          _buildStatusRow(
                            'Current Location',
                            '${locationService.currentLocation!.latitude.toStringAsFixed(6)}, ${locationService.currentLocation!.longitude.toStringAsFixed(6)}',
                            Colors.blue,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Mock Driving Button
            Consumer<LocationService>(
              builder: (context, locationService, child) {
                return Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.directions_car, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              'Mock Driving',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Simulate driving along the selected route. Location will update automatically.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: locationService.isMockDriving
                              ? _stopMockDriving
                              : _startMockDriving,
                          icon: Icon(
                            locationService.isMockDriving ? Icons.stop : Icons.play_arrow,
                          ),
                          label: Text(
                            locationService.isMockDriving ? 'Stop Mock Driving' : 'Start Mock Driving',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: locationService.isMockDriving
                                ? Colors.red
                                : Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTracking ? null : _startTracking,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTracking ? _stopTracking : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Fill in your driver name and bus ID\n'
                      '2. Select the route you are driving\n'
                      '3. Tap "Start Tracking" to begin sending location data\n'
                      '4. Students will see your bus location in real-time\n'
                      '5. Tap "Stop Tracking" when your shift ends',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _driverNameController.dispose();
    _busIdController.dispose();
    _routeIdController.dispose();
    super.dispose();
  }
}
