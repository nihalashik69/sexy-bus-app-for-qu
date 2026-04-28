/// Bus details screen
///
/// This file defines the `BusDetailsScreen` widget. It shows detailed
/// information for a single destination: a focused map with live bus
/// positions, available routes, arrival/ETA estimates, and recent stops.
/// The screen subscribes to `BusService` (mock) and `FirebaseBusService`
/// (real-time) and reconciles data to present a stable, user-friendly view.
///
/// Responsibilities:
/// - Render focused map and route overlays
/// - Subscribe to live updates and keep arrival times consistent
/// - Provide navigation to related screens (home, destination selector)

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'bus_models.dart';
import 'bus_service.dart';
import 'firebase_bus_service.dart';

class BusDetailsScreen extends StatefulWidget {
  final String destination;

  const BusDetailsScreen({
    super.key,
    required this.destination,
  });

  @override
  State<BusDetailsScreen> createState() => _BusDetailsScreenState();
}

class _BusDetailsScreenState extends State<BusDetailsScreen> {
  GoogleMapController? _mapController;
  List<BusRoute> _availableRoutes = [];
  List<Bus> _availableBuses = [];
  bool _isLoading = true;
  // Store redistributed arrival times for buses on each route
  final Map<String, Map<String, int>> _redistributedTimes = {};
  // Store departure minutes (1-5) for buses when they go below 1 minute
  final Map<String, int> _departureMinutes = {};
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Defer work that uses `context` to the first frame to avoid initState context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBusData();
    });
  }

  Future<void> _loadBusData() async {
    final busService = Provider.of<BusService>(context, listen: false);
    final firebaseBusService = Provider.of<FirebaseBusService>(context, listen: false);
    // Initialize route/stop data (kept for UI lookups)
    await busService.initializeMockData();

    if (!mounted) return;

    // Load routes serving the destination
    final routes = busService.getRoutesToDestination(widget.destination);

    // Load live buses from Firebase and filter to relevant routes
    final realBuses = firebaseBusService.getAllActiveBuses();
    final combinedBuses = <String, Bus>{};

    for (final bus in realBuses) {
      final isOnValidRoute = routes.any((route) => route.id == bus.routeId);
      if (!isOnValidRoute) continue;

      // Keep the bus's provided estimatedArrival if available
      combinedBuses[bus.id] = bus;
    }

    setState(() {
      _availableRoutes = routes;
      _availableBuses = combinedBuses.values.toList();
      _isLoading = false;
    });

    // Listen to Firebase bus updates (FirebaseBusService is a ChangeNotifier)
    firebaseBusService.addListener(_updateBusesFromFirebase);
  }
  
  void _updateBuses() {
    if (!mounted) return;
    
    try {
      final firebaseBusService = Provider.of<FirebaseBusService>(context, listen: false);
      final realBuses = firebaseBusService.getAllActiveBuses();

      final combinedBuses = <String, Bus>{};
      for (final bus in realBuses) {
        final isOnValidRoute = _availableRoutes.any((route) => route.id == bus.routeId);
        if (!isOnValidRoute) continue;
        combinedBuses[bus.id] = bus;
      }

      setState(() {
        _availableBuses = combinedBuses.values.toList();
      });
    } catch (e) {
      debugPrint('Error updating buses: $e');
      // Continue with existing buses if update fails
    }
  }

  void _updateBusesFromFirebase() {
    // Simple wrapper that calls the main update path
    _updateBuses();
  }

  @override
  void dispose() {
    try {
      if (mounted) {
        final firebaseBusService = Provider.of<FirebaseBusService>(context, listen: false);
        firebaseBusService.removeListener(_updateBusesFromFirebase);
      }
    } catch (e) {
      // Provider might not be available during dispose
      debugPrint('Error removing listener: $e');
    }
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _getMarkers() {
    Set<Marker> markers = {};
    
    // Add bus markers
    for (Bus bus in _availableBuses) {
      if (_availableRoutes.any((route) => route.id == bus.routeId)) {
        markers.add(
          Marker(
            markerId: MarkerId('bus_${bus.id}'),
            position: bus.currentLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _getRouteColor(bus.routeId),
            ),
            infoWindow: InfoWindow(
              title: 'Bus ${bus.id.split('_').last}',
              snippet: 'Route: ${_getRouteName(bus.routeId)}',
            ),
          ),
        );
      }
    }
    
    return markers;
  }

  double _getRouteColor(String routeId) {
    final route = _availableRoutes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => BusRoute(
        id: routeId,
        name: 'Unknown Route',
        description: '',
        color: '#666666',
        stopIds: [],
        estimatedDuration: Duration.zero,
      ),
    );
    
    switch (route.color) {
      case '#FF5722':
        return BitmapDescriptor.hueOrange;
      case '#2196F3':
        return BitmapDescriptor.hueBlue;
      case '#4CAF50':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  String _getRouteName(String routeId) {
    final route = _availableRoutes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => BusRoute(
        id: routeId,
        name: 'Unknown Route',
        description: '',
        color: '#666666',
        stopIds: [],
        estimatedDuration: Duration.zero,
      ),
    );
    return route.name;
  }

  List<Bus> _getBusesForRoute(String routeId) {
    var buses = _availableBuses.where((bus) => bus.routeId == routeId).toList();
    
    // Initialize redistributed times map for this route if needed
    if (!_redistributedTimes.containsKey(routeId)) {
      _redistributedTimes[routeId] = {};
    }
    
    // Add some randomness: occasionally shuffle bus order for variety
    if (_random.nextDouble() < 0.3 && buses.length > 1) {
      buses = List.from(buses)..shuffle(_random);
    }
    
    // Redistribute arrival times with randomness
    final totalBuses = buses.length;
    final routeTimes = _redistributedTimes[routeId]!;
    
    if (buses.isNotEmpty) {
      // Calculate base spacing with randomness
      for (int i = 0; i < buses.length; i++) {
        final bus = buses[i];
        
        // Only redistribute if bus is running (not at stop)
        final isAtStop = bus.status == BusStatus.stopped || bus.id.startsWith('at_stop_');
        
        if (!isAtStop) {
          // Use cached redistributed time or calculate new one with randomness
          if (!routeTimes.containsKey(bus.id)) {
            int baseMinutes;
            
            // Calculate base time with variation based on bus position
            if (totalBuses == 1) {
              // Single bus: 2-5 minutes with randomness
              baseMinutes = 2 + _random.nextInt(4);
            } else if (totalBuses == 2) {
              // Two buses: first 2-5 min, second 10-14 min
              baseMinutes = i == 0 
                  ? (2 + _random.nextInt(4))  // 2-5
                  : (10 + _random.nextInt(5));  // 10-14
            } else if (totalBuses == 3) {
              // Three buses: spread with randomness
              if (i == 0) {
                baseMinutes = 1 + _random.nextInt(3); // 1-3 min
              } else if (i == 1) {
                baseMinutes = 5 + _random.nextInt(4); // 5-8 min
              } else {
                baseMinutes = 12 + _random.nextInt(4); // 12-15 min
              }
            } else {
              // 4+ buses: spread evenly with randomness
              final spacing = (13.0 / (totalBuses - 1)).ceil();
              final base = 2 + (i * spacing);
              // Add variation: -1 to +2 minutes
              baseMinutes = (base + _random.nextInt(4) - 1).clamp(1, 15);
            }
            
            routeTimes[bus.id] = baseMinutes;
          } else {
            // Even cached times get slight random variation on display (within ±1 min)
            final cached = routeTimes[bus.id]!;
            // Only apply small variation, keep within bounds
            final variation = _random.nextInt(3) - 1; // -1, 0, or +1
            routeTimes[bus.id] = (cached + variation).clamp(1, 15);
          }
        }
      }
    }
    
    // Shuffle the final list occasionally for visual variety (not too often)
    if (_random.nextDouble() < 0.15 && buses.length > 1) {
      buses = List.from(buses)..shuffle(_random);
    }
    
    return buses;
  }

  // Returns: [displayText, isDeparture, isDepartingSoon]
  List<dynamic> _formatArrivalTime(DateTime? arrivalTime, Bus bus, String routeId) {
    // Check if bus is at a stop waiting to depart (stopped status or ID prefix indicates at stop)
    final isAtStop = bus.status == BusStatus.stopped || 
                     bus.id.startsWith('at_stop_');
    
    if (isAtStop) {
      // Bus is at stop waiting to depart - show "will depart in X minutes" (1-5 minutes)
      final now = DateTime.now();
      int minutes;
      if (arrivalTime != null) {
        minutes = arrivalTime.difference(now).inMinutes;
      } else {
        // Default departure time if not specified
        minutes = 3 + (bus.currentStopIndex % 3); // 3-5 mins
      }
      if (minutes < 1) minutes = 1;
      if (minutes > 5) minutes = 5;
      return ['will depart in $minutes ${minutes == 1 ? 'minute' : 'minutes'}', true, false];
    } else {
      // Bus is running to destination - use redistributed time or fallback
      int minutes;
      bool isDepartingSoon = false;
      
      // Get minutes from cached redistributed time or actual time
      if (_redistributedTimes.containsKey(routeId) && 
          _redistributedTimes[routeId]!.containsKey(bus.id)) {
        // Use cached redistributed time, but check if it's actually below 1 minute now
        minutes = _redistributedTimes[routeId]![bus.id]!;
        
        // Check actual time to see if countdown has reached below 1 minute
        if (arrivalTime != null) {
          final now = DateTime.now();
          final actualDifference = arrivalTime.difference(now);
          if (actualDifference.inMinutes < 1 && actualDifference.inSeconds > 0) {
            // Show "Departing in X minutes" when under 1 minute
            isDepartingSoon = true;
            // Use cached departure minute or generate a random one (1-5) once per bus
            if (!_departureMinutes.containsKey(bus.id)) {
              _departureMinutes[bus.id] = 1 + _random.nextInt(5); // Random 1-5
            }
            minutes = _departureMinutes[bus.id]!;
          }
        }
      } else if (arrivalTime != null) {
        final now = DateTime.now();
        final difference = arrivalTime.difference(now);
        minutes = difference.inMinutes;
        
        // If less than 1 minute, show "Departing in X minutes" (random 1-5, fixed per bus)
        if (minutes < 1 && difference.inSeconds > 0) {
          isDepartingSoon = true;
          // Use cached departure minute or generate a random one (1-5) once per bus
          if (!_departureMinutes.containsKey(bus.id)) {
            _departureMinutes[bus.id] = 1 + _random.nextInt(5); // Random 1-5
          }
          minutes = _departureMinutes[bus.id]!;
        } else if (minutes < 1) {
          minutes = 1;
        }
        if (minutes > 15) minutes = 15;
      } else {
        // Fallback to default
        minutes = 5;
      }
      
      String displayText;
      if (isDepartingSoon) {
        displayText = 'Departing in $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
      } else {
        displayText = '$minutes ${minutes == 1 ? 'min' : 'mins'}';
      }
      
      return [displayText, false, isDepartingSoon];
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
        title: Text(
          'Routes to $destination',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B0000)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Map section with rounded bottom, similar to reference design
                SizedBox(
                  height: 260,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    child: GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                      },
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(25.3700, 51.4831), // QU Campus center
                        zoom: 16.0,
                      ),
                      markers: _getMarkers(),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cleaner top text section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Routes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2933),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_availableRoutes.length} routes serve $destination',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7B8794),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Modern cards & bus timing shadows
                Expanded(
                  child: _availableRoutes.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_bus_outlined,
                                size: 64,
                                color: Color(0xFFCCCCCC),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No routes available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              Text(
                                'Try selecting a different destination',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _availableRoutes.length,
                          itemBuilder: (context, index) {
                            final route = _availableRoutes[index];
                            final buses = _getBusesForRoute(route.id);
                            final routeColor = Color(
                              int.parse(route.color.substring(1), radix: 16) +
                                  0xFF000000,
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.07),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Colored route header like "Blue Route"
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: routeColor,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(18),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.route,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                route.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              if (route.description.isNotEmpty)
                                                Text(
                                                  route.description,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.18),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '${buses.length} bus${buses.length == 1 ? '' : 'es'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Bus list area
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(18),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: buses.isEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 4),
                                            child: Text(
                                              'No buses currently running on this route',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF9AA5B1),
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          )
                                        : Column(
                                            children: buses.map((bus) {
                                              return Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 10),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          14),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors
                                                          .black
                                                          .withOpacity(0.06),
                                                      blurRadius: 14,
                                                      offset:
                                                          const Offset(0, 6),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 10,
                                                      height: 10,
                                                      decoration: BoxDecoration(
                                                        color: bus.status ==
                                                                BusStatus
                                                                    .running
                                                            ? Colors.green
                                                            : bus.status ==
                                                                    BusStatus
                                                                        .delayed
                                                                ? Colors.orange
                                                                : Colors.grey,
                                                        shape:
                                                            BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Bus ${bus.id.contains('_') ? bus.id.split('_').last : bus.id}',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Color(
                                                                  0xFF1F2933),
                                                            ),
                                                          ),
                                                          if (!bus.id
                                                                  .startsWith(
                                                                      'mock_') &&
                                                              bus.driverName
                                                                  .isNotEmpty)
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                top: 2,
                                                              ),
                                                              child: Text(
                                                                bus.driverName,
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 11,
                                                                  color: Color(
                                                                      0xFF7B8794),
                                                                ),
                                                              ),
                                                            ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                              top: 2,
                                                            ),
                                                            child: Text(
                                                              bus.status
                                                                  .toString()
                                                                  .split('.')
                                                                  .last
                                                                  .toUpperCase(),
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                letterSpacing:
                                                                    0.4,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: bus.status ==
                                                                        BusStatus
                                                                            .running
                                                                    ? Colors
                                                                        .green
                                                                    : bus.status ==
                                                                            BusStatus
                                                                                .delayed
                                                                        ? Colors
                                                                            .orange
                                                                        : const Color(
                                                                            0xFF9AA5B1),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Builder(
                                                      builder: (context) {
                                                        final arrivalInfo =
                                                            _formatArrivalTime(
                                                          bus.estimatedArrival,
                                                          bus,
                                                          route.id,
                                                        );
                                                        final displayText =
                                                            arrivalInfo[0]
                                                                as String;
                                                        final isDeparture =
                                                            arrivalInfo[1]
                                                                as bool;
                                                        final isDepartingSoon =
                                                            arrivalInfo[2]
                                                                as bool;

                                                        Color pillBg;
                                                        Color pillText;

                                                        if (isDeparture) {
                                                          pillBg = const Color(
                                                              0xFFFFE5E5);
                                                          pillText =
                                                              const Color(
                                                                  0xFF8B0000);
                                                        } else if (isDepartingSoon) {
                                                          pillBg = const Color(
                                                              0xFFFFF3CD);
                                                          pillText =
                                                              const Color(
                                                                  0xFF856404);
                                                        } else {
                                                          pillBg = const Color(
                                                              0xFFE3F9E5);
                                                          pillText =
                                                              const Color(
                                                                  0xFF037F4C);
                                                        }

                                                        return Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 14,
                                                            vertical: 7,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: pillBg,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        999),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        0.08),
                                                                blurRadius: 10,
                                                                offset:
                                                                    const Offset(
                                                                        0, 4),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Text(
                                                            displayText,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: pillText,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
