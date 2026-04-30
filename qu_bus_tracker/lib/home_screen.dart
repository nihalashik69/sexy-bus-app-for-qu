/// Home screen with map and overlays
///
/// The primary app screen that shows the interactive map, active bus
/// markers, route filters, and UI overlays (search, details sheet).
/// Subscribes to `BusService`, `FirebaseBusService`, and
/// `LocationService` to keep map markers and ETA information up to date.
///
/// Responsibilities:
/// - Render interactive Google Map and marker icons
/// - Manage UI sheets for route/bus details and lists
/// - Handle navigation to `BusDetailsScreen` and destination picker

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'destination_selection_screen.dart';
import 'bus_details_screen.dart';
import 'bus_service.dart';
import 'bus_models.dart';
import 'firebase_bus_service.dart';
import 'location_service.dart';
import 'maps_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(25.3700, 51.4831); // QU Campus center
  bool _isLoading = true;
  String? _selectedDestination;
  String? _selectedMarkerLocation; // Location of tapped marker
  final DraggableScrollableController _detailsSheetController = DraggableScrollableController();
  final DraggableScrollableController _busesListSheetController = DraggableScrollableController();
  bool _showAllBuses = false; // Toggle to show all live buses
  final Map<String, BitmapDescriptor> _busIconCache = {}; // Cache for bus icons by route color (key: color value as string)
  BitmapDescriptor? _stopIcon; // Cached custom stop icon (blue)

  // Qatar University campus bounds
  static const LatLng _quCenter = LatLng(25.376453, 51.488121);
  static const double _quZoom = 16.0;

  // Official QU campus locations (populated from BusService)
  Map<String, LatLng> _campusLocations = {};

  @override
  void initState() {
    super.initState();
    // Listen to details sheet controller to detect when fully closed
    _detailsSheetController.addListener(() {
      if (_detailsSheetController.size <= 0.01) {
        // Sheet is fully closed, ensure marker and destination are cleared
        if (mounted) {
          setState(() {
            _selectedMarkerLocation = null;
            _selectedDestination = null;
          });
        }
      }
    });
    // Defer initialization that depends on Inherited widgets / Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Initialize bus service
    try {
      final busService = Provider.of<BusService>(context, listen: false);
      // No local mock buses required; routes/stops are initialized on demand
      await busService.initializeMockData();

      // Populate campus locations from BusService stops (so UI reflects updated stops)
      final stops = busService.getAllStops();
      if (stops.isNotEmpty) {
        final map = <String, LatLng>{};
        for (var s in stops) {
          map[s.name] = s.location;
        }
        if (mounted) {
          setState(() {
            _campusLocations = map;
          });
        }
      }
    } catch (e) {
      // If provider isn't available or initialization fails, log and continue
      debugPrint('BusService init error: $e');
    }

    // Initialize Firebase bus service
    try {
      final firebaseBusService = Provider.of<FirebaseBusService>(context, listen: false);
      await firebaseBusService.initialize();
    } catch (e) {
      debugPrint('FirebaseBusService init error: $e');
    }

    // Get current location
    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await LocationService.getCurrentLocation();
      if (location != null) {
        if (!mounted) return;
        setState(() {
          _currentLocation = location;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error getting location: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  // Zoom controls
  Future<void> _zoomIn() async {
    if (_mapController == null) return;
    try {
      await _mapController!.animateCamera(CameraUpdate.zoomIn());
    } catch (e) {
      debugPrint('Zoom in error: $e');
    }
  }

  Future<void> _zoomOut() async {
    if (_mapController == null) return;
    try {
      await _mapController!.animateCamera(CameraUpdate.zoomOut());
    } catch (e) {
      debugPrint('Zoom out error: $e');
    }
  }

  Future<void> _selectDestination() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DestinationSelectionScreen(),
      ),
    );

    if (result != null && result is Map) {
      final destination = result['destination'] as String?;
      if (destination != null && _campusLocations.containsKey(destination)) {
        setState(() {
          _selectedDestination = destination;
          // If a bus was selected, open the details sheet
          if (result['busId'] != null) {
            _selectedMarkerLocation = destination;
            // Wait for sheet to be created
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_detailsSheetController.isAttached && mounted) {
                _detailsSheetController.animateTo(
                  0.3,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        });
        
        // Animate to selected destination
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(_campusLocations[destination]!),
          );
        }
      }
    } else if (result != null && result is String) {
      // Backward compatibility: handle old string return format
      setState(() {
        _selectedDestination = result;
      });
      
      if (_mapController != null && _campusLocations.containsKey(result)) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(_campusLocations[result]!),
        );
      }
    }
  }

  Set<Marker> _getMarkers(FirebaseBusService firebaseBusService) {
    Set<Marker> markers = {};
    
    // Pre-create bus icons for all active buses (async operation, but we'll handle it)
    // Note: This will need to be handled differently since we can't await in getMarkers
    // We'll create icons on first use and cache them

    // Add current location marker
    markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Current position',
        ),
      ),
    );

    // Add destination marker if selected
    if (_selectedDestination != null && 
        _campusLocations.containsKey(_selectedDestination)) {
      markers.add(
        Marker(
          markerId: MarkerId('destination_$_selectedDestination'),
          position: _campusLocations[_selectedDestination]!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: _selectedDestination!,
            snippet: 'Your destination',
          ),
          onTap: () {
            setState(() {
              _selectedMarkerLocation = _selectedDestination!;
              _showAllBuses = false; // Hide live buses button when destination marker is tapped
            });
            // Close buses list if open
            if (_busesListSheetController.isAttached) {
              _busesListSheetController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
              );
            }
            // Open the details sheet (will be created in build if _selectedMarkerLocation is not null)
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_detailsSheetController.isAttached && mounted) {
                _detailsSheetController.animateTo(
                  0.3, // Initial height (30% of screen)
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          },
        ),
      );
    }

    // Add campus location markers
    for (String location in _campusLocations.keys) {
      if (location != _selectedDestination) {
        // Determine icon: use cached custom stop icon if available, otherwise use default hue and create the custom icon async
        BitmapDescriptor stopIcon = BitmapDescriptor.defaultMarkerWithHue(MapsConfig.campusMarkerHue);
        if (_stopIcon != null) {
          stopIcon = _stopIcon!;
        } else {
          // Create and cache stop icon asynchronously
          _createStopIcon().then((icon) {
            if (mounted) {
              setState(() {
                _stopIcon = icon;
              });
            }
          });
        }

        markers.add(
          Marker(
            markerId: MarkerId('campus_$location'),
            position: _campusLocations[location]!,
            icon: stopIcon,
            infoWindow: InfoWindow(
              title: location,
              snippet: 'Tap to select as destination',
            ),
            onTap: () {
              setState(() {
                _selectedMarkerLocation = location;
                _selectedDestination = location;
                _showAllBuses = false; // Hide live buses button when building marker is selected
              });
              // Close buses list if open
              if (_busesListSheetController.isAttached) {
                _busesListSheetController.animateTo(
                  0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              }
              // Open the details sheet (will be created in build if _selectedMarkerLocation is not null)
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_detailsSheetController.isAttached && mounted) {
                  _detailsSheetController.animateTo(
                    0.3, // Initial height (30% of screen)
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            },
          ),
        );
      }
    }

    // Add bus markers from Firebase
    for (final bus in firebaseBusService.liveBuses.values) {
      if (bus.status == BusStatus.running) {
        // Get route color for marker
        final routeColorAsColor = _getRouteColorAsColor(bus.routeId);
        final routeName = _getRouteName(bus.routeId);
        
        // Get or create bus icon (use cached if available, otherwise use default for now)
        final colorKey = routeColorAsColor.value.toString();
        BitmapDescriptor busIcon;
        if (_busIconCache.containsKey(colorKey)) {
          busIcon = _busIconCache[colorKey]!;
        } else {
          // Use default marker temporarily, icon will be cached on next rebuild
          busIcon = BitmapDescriptor.defaultMarkerWithHue(_getRouteColor(bus.routeId));
          // Asynchronously create and cache the icon
          _createBusIcon(routeColorAsColor).then((icon) {
            if (mounted) {
              setState(() {
                _busIconCache[colorKey] = icon;
              });
            }
          });
        }
        
        markers.add(
          Marker(
            markerId: MarkerId('bus_${bus.id}'),
            position: bus.currentLocation,
            icon: busIcon,
            rotation: bus.heading,
            anchor: const Offset(0.5, 0.5),
            infoWindow: InfoWindow(
              title: 'Bus ${bus.id}',
              snippet: '$routeName\nDriver: ${bus.driverName}',
            ),
            onTap: () {
              // Optionally show bus details when tapped
              debugPrint('Tapped on bus ${bus.id}');
            },
          ),
        );
      }
    }

    return markers;
  }

  // Helper methods to get route information
  double _getRouteColor(String routeId) {
    final busService = Provider.of<BusService>(context, listen: false);
    final routes = busService.getAllRoutes();
    final route = routes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => BusRoute(
        id: routeId,
        name: 'Unknown Route',
        description: '',
        color: '#666666',
        stopIds: [],
        estimatedDuration: const Duration(minutes: 0),
      ),
    );
    
    // Map hex colors to BitmapDescriptor hue values
    switch (route.color.toUpperCase()) {
      case '#1976D2': // Blue Route
        return BitmapDescriptor.hueBlue;
      case '#42A5F5': // Light Blue Route
        return BitmapDescriptor.hueCyan;
      case '#388E3C': // Dark Green Route
        return BitmapDescriptor.hueGreen;
      case '#66BB6A': // Light Green Route
        return BitmapDescriptor.hueGreen;
      case '#7B1FA2': // Purple Route
        return BitmapDescriptor.hueViolet;
      case '#C2185B': // Pink Route
        return BitmapDescriptor.hueRose;
      case '#F57C00': // Orange Route
        return BitmapDescriptor.hueOrange;
      case '#212121': // Black Line
        return BitmapDescriptor.hueRed; // Use red for black line (dark marker)
      case '#FAFAFA': // White Line
        return BitmapDescriptor.hueYellow;
      case '#5D4037': // Brown Line
        return BitmapDescriptor.hueRed;
      case '#8D6E63': // Maroon Line
        return BitmapDescriptor.hueRed;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  String _getRouteName(String routeId) {
    final busService = Provider.of<BusService>(context, listen: false);
    final routes = busService.getAllRoutes();
    final route = routes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => BusRoute(
        id: routeId,
        name: routeId,
        description: '',
        color: '#666666',
        stopIds: [],
        estimatedDuration: const Duration(minutes: 0),
      ),
    );
    return route.name;
  }

  // Helper method to get route color as Color object
  Color _getRouteColorAsColor(String routeId) {
    final busService = Provider.of<BusService>(context, listen: false);
    final routes = busService.getAllRoutes();
    final route = routes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => BusRoute(
        id: routeId,
        name: 'Unknown Route',
        description: '',
        color: '#666666',
        stopIds: [],
        estimatedDuration: const Duration(minutes: 0),
      ),
    );
    
    // Parse hex color directly
    try {
      return Color(int.parse(route.color.replaceFirst('#', '0xFF')));
    } catch (e) {
      // Fallback to a default color if parsing fails
      return const Color(0xFF666666);
    }
  }

  // Create custom bus icon bitmap (double size)
  Future<BitmapDescriptor> _createBusIcon(Color routeColor) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = 160.0; // Icon size (double)
    
    // Draw bus body (rectangle with rounded corners)
    final busPaint = Paint()
      ..color = routeColor
      ..style = PaintingStyle.fill;
    
    final busRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(20, 40, 120, 80),
      const Radius.circular(16),
    );
    canvas.drawRRect(busRect, busPaint);
    
    // Draw bus windows
    final windowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // Front window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(30, 50, 30, 24),
        const Radius.circular(6),
      ),
      windowPaint,
    );
    
    // Back window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(100, 50, 30, 24),
        const Radius.circular(6),
      ),
      windowPaint,
    );
    
    // Draw wheels
    final wheelPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(const Offset(50, 130), 12, wheelPaint);
    canvas.drawCircle(const Offset(110, 130), 12, wheelPaint);
    
    // Draw white center for wheels
    final wheelCenterPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(const Offset(50, 130), 6, wheelCenterPaint);
    canvas.drawCircle(const Offset(110, 130), 6, wheelCenterPaint);
    
    // Convert to image
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.fromBytes(uint8List);
  }

  // Create a bus-stop icon (blue pin with white bus symbol) - larger size
  Future<BitmapDescriptor> _createStopIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 128.0; // doubled

    // Draw blue pin circle
    final pinPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size/2, size/2 - 12), 32, pinPaint);

    // Draw small white bus rectangle inside the pin
    final busPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size/2 - 20, size/2 - 24, 40, 24),
        const Radius.circular(6),
      ),
      busPaint,
    );

    // Draw the pin tail (triangle)
    final tailPaint = Paint()..color = Colors.blue;
    final path = Path()
      ..moveTo(size/2 - 16, size/2 + 16)
      ..lineTo(size/2 + 16, size/2 + 16)
      ..lineTo(size/2, size - 8)
      ..close();
    canvas.drawPath(path, tailPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B0000)),
                  ),
                )
              : Consumer<FirebaseBusService>(
                  builder: (context, firebaseBusService, child) {
                    return GoogleMap(
                      mapType: MapType.hybrid,
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: const CameraPosition(
                        target: _quCenter,
                        zoom: _quZoom,
                      ),
                      markers: _getMarkers(firebaseBusService),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      onTap: (LatLng position) {
                        // Clear destination selection and close sheet when tapping on map
                        setState(() {
                          _selectedDestination = null;
                          _selectedMarkerLocation = null;
                        });
                        // Only animate if controller is attached (sheet exists)
                        if (_detailsSheetController.isAttached) {
                          _detailsSheetController.animateTo(
                            0.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          );
                        }
                      },

                    );
                  },
                ),

          // Destination Selection Button (moved to top)
          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _selectDestination,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B0000).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF8B0000),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedDestination ?? 'Where do you want to go?',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C2C2C),
                                ),
                              ),
                              if (_selectedDestination == null)
                                const Text(
                                  'Select your destination on campus',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF666666),
                                  ),
                                )
                              else
                                Text(
                                  'Destination selected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFF8B0000),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFF8B0000),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Firebase Connection Status
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Consumer<FirebaseBusService>(
              builder: (context, firebaseBusService, child) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: firebaseBusService.isConnected ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        firebaseBusService.isConnected ? Icons.wifi : Icons.wifi_off,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        firebaseBusService.isConnected 
                            ? 'Live Bus Tracking Active (${firebaseBusService.liveBuses.length} buses)'
                            : 'Connecting to Live Bus Data...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Show All Live Buses Button (bottom center) - ALWAYS visible
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: _showAllBuses ? const Color(0xFF8B0000) : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      setState(() {
                        _showAllBuses = !_showAllBuses;
                      });
                      // Animate sheet up/down
                      if (_showAllBuses) {
                        _busesListSheetController.animateTo(
                          0.4, // 40% of screen height
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      } else {
                        _busesListSheetController.animateTo(
                          0.0, // Hide sheet
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showAllBuses ? Icons.visibility_off : Icons.directions_bus,
                            color: _showAllBuses ? Colors.white : const Color(0xFF8B0000),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _showAllBuses ? 'Hide Live Buses' : 'Show All Live Buses',
                            style: TextStyle(
                              color: _showAllBuses ? Colors.white : const Color(0xFF8B0000),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Draggable Details Sheet (slides up when marker is tapped) - layered above button
          if (_selectedMarkerLocation != null)
            DraggableScrollableSheet(
              controller: _detailsSheetController,
              initialChildSize: 0.3, // 30% of screen height initially
              minChildSize: 0.0, // Allow full close
              maxChildSize: 0.95, // Maximum 95% (almost fullscreen)
              snap: true,
              snapSizes: const [0.0, 0.3, 0.6, 0.95], // Snap points including 0.0 for full close
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.directions_bus,
                              color: Color(0xFF8B0000),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Routes to $_selectedMarkerLocation',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C2C2C),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFF8B0000)),
                              onPressed: () {
                                // IMMEDIATELY clear ALL state - this must happen first
                                _selectedMarkerLocation = null;
                                _selectedDestination = null;
                                
                                // Force setState to rebuild UI immediately
                                setState(() {
                                  // State already cleared above for immediate effect
                                });
                                
                                // Close the sheet with animation
                                if (_detailsSheetController.isAttached) {
                                  _detailsSheetController.animateTo(
                                    0.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeIn,
                                  );
                                }
                                
                                // Ensure state is still cleared after rebuild
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    _selectedMarkerLocation = null;
                                    _selectedDestination = null;
                                    setState(() {
                                      // Force rebuild
                                    });
                                  }
                                });
                                
                                // Final check after animation
                                Future.delayed(const Duration(milliseconds: 350), () {
                                  if (mounted) {
                                    _selectedMarkerLocation = null;
                                    _selectedDestination = null;
                                    setState(() {
                                      // Final cleanup
                                    });
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Quick info
                              const Text(
                                'Bus Route 1: 5 min • Bus Route 2: 8 min',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Full details button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BusDetailsScreen(
                                          destination: _selectedMarkerLocation!,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B0000),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'View Full Details',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Additional route information can go here
                              Text(
                                'Location: $_selectedMarkerLocation',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Zoom controls (+ / -)
          Positioned(
            top: 170,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, color: Color(0xFF8B0000)),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, color: Color(0xFF8B0000)),
                ),
              ],
            ),
          ),

          // Live Buses List Sheet (slides up from bottom)
          DraggableScrollableSheet(
            controller: _busesListSheetController,
            initialChildSize: 0.0, // Hidden initially
            minChildSize: 0.0,
            maxChildSize: 0.75, // Maximum 75% of screen
            snap: true,
            snapSizes: const [0.4, 0.75], // Snap points
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16), // Make sheet narrower
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle (larger and more prominent)
                      GestureDetector(
                        onTap: () {
                          // Toggle between snap sizes when handle is tapped
                          if (_busesListSheetController.isAttached) {
                            final currentSize = _busesListSheetController.size;
                            if (currentSize < 0.6) {
                              _busesListSheetController.animateTo(
                                0.75,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            } else {
                              _busesListSheetController.animateTo(
                                0.4,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeIn,
                              );
                            }
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 8),
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.directions_bus,
                            color: Color(0xFF8B0000),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Consumer<FirebaseBusService>(
                              builder: (context, firebaseBusService, child) {
                                final allBuses = firebaseBusService.getAllActiveBuses();
                                return Text(
                                  'Live Buses (${allBuses.length})',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C2C2C),
                                  ),
                                );
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF8B0000)),
                            onPressed: () {
                              setState(() {
                                _showAllBuses = false;
                              });
                              _busesListSheetController.animateTo(
                                0.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeIn,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Bus list
                    Expanded(
                      child: Consumer<FirebaseBusService>(
                        builder: (context, firebaseBusService, child) {
                          final allBuses = firebaseBusService.getAllActiveBuses();
                          
                          if (allBuses.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.directions_bus_outlined,
                                    size: 64,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No buses currently active',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Check back soon!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          // Get route names from BusService
                          final busService = Provider.of<BusService>(context, listen: false);
                          final allRoutes = busService.getAllRoutes();
                          
                          return ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: allBuses.length,
                            itemBuilder: (context, index) {
                              final bus = allBuses[index];
                              final route = allRoutes.firstWhere(
                                (r) => r.id == bus.routeId,
                                orElse: () => BusRoute(
                                  id: bus.routeId,
                                  name: bus.routeId,
                                  description: '',
                                  color: '#000000',
                                  stopIds: [],
                                  estimatedDuration: const Duration(minutes: 0),
                                ),
                              );
                              
                              // Parse route color
                              Color routeColor;
                              try {
                                routeColor = Color(int.parse(route.color.replaceFirst('#', '0xFF')));
                              } catch (e) {
                                routeColor = Colors.grey;
                              }
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    // Could navigate to bus details or center map on bus
                                  },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      child: Row(
                                        children: [
                                          // Route color indicator
                                          Container(
                                            width: 4,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: routeColor,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Bus icon
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                                Icons.directions_bus,
                                                color: Colors.green[700],
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Bus info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        route.name,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF2C2C2C),
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                    // No mock label — only live buses provided by backend
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Driver: ${bus.driverName}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  'Status: ${bus.status.toString().split('.').last}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[500],
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Status indicator
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Icon(
                                                Icons.circle,
                                                size: 10,
                                                color: bus.status == BusStatus.running 
                                                    ? Colors.green 
                                                    : Colors.grey,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${(bus.estimatedArrival?.difference(DateTime.now()).inMinutes ?? 5).abs()} min',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _detailsSheetController.dispose();
    _busesListSheetController.dispose();
    super.dispose();
  }
}

