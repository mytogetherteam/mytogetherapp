import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/restaurant_data.dart' show Restaurant;
import '../widgets/nearby_restaurant_list_item.dart';
import '../widgets/nearby_restaurant_list_item_skeleton.dart';
import '../widgets/map_skeleton_loader.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'restaurant_detail_page.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import '../../../../core/theme/app_map_theme.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';


class RestaurantNearbyListPage extends StatefulWidget {
  const RestaurantNearbyListPage({super.key});

  @override
  State<RestaurantNearbyListPage> createState() => _RestaurantNearbyListPageState();
}

class _RestaurantNearbyListPageState extends State<RestaurantNearbyListPage> {
  Future<List<Restaurant>>? _restaurantsFuture;
  final Map<String, bool> _localFavorites = {};
  final ScrollController _listScrollController = ScrollController();
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  Set<Marker> _markers = {};
  String? _expandedRestaurantId;
  final Map<String, GlobalKey> _itemKeys = {};
  static const LatLng _initialPosition = LatLng(13.7000, 100.5018); // Shifted north to move view "down"
  LatLng? _currentLocation;
  Set<Polyline> _polylines = {};
  bool _isRouting = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _showMap = false;

  late final Dio _dio;
  static const String _googleMapsApiKey = 'AIzaSyDeKocCUJZ7ocLBB8ZelixW2Cr1tMiwapM';

  @override
  void initState() {
    super.initState();
    _dio = Dio();
    _fetchRestaurants();
    _initLocationService();
  }

  Future<void> _initLocationService() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    // 1. Immediate Last Known Position (Instant check)
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null && mounted) {
      setState(() {
        _currentLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
      });
    }

    // 2. Start streaming for real-time updates (Keep GPS warm)
    // Distance filter of 10m to avoid too many UI rebuilds
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }
    });

    // 3. One-shot high-ish accuracy fetch to refine position if stream is slow
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (_) {
      // Ignore timeout or errors here as we have the stream/lastKnown
    }
  }



  // Cached route bounds for re-centering when route already exists
  LatLngBounds? _routeBounds;

  Future<void> _onCurrentLocationTapped() async {
    if (_expandedRestaurantId == null || _restaurantsFuture == null) return;
    
    // SECOND CLICK: route already displayed — re-center camera to show full route
    if (_polylines.isNotEmpty && _routeBounds != null) {
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngBounds(
        _routeBounds!,
        80.0, // Just use a generous flat padding since map padding will handle the sheet
      ));
      return;
    }

    setState(() {
      _isRouting = true;
    });

    final rList = await _restaurantsFuture!;
    final selected = rList.cast<Restaurant?>().firstWhere(
      (element) => element?.id == _expandedRestaurantId, 
      orElse: () => null
    );
    
    if (selected == null || selected.latitude == null || selected.longitude == null) {
      setState(() { _isRouting = false; });
      return;
    }

    // USE CACHED LOCATION IF AVAILABLE (STRATEGY: INSTANT START)
    LatLng? startLoc = _currentLocation;

    // If no cached location, try a quick fetch with very short timeout
    if (startLoc == null) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 3),
          ),
        );
        startLoc = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLocation = startLoc;
        });
      } catch (e) {
        // Still no location? Fallback to last known as absolute last resort
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          startLoc = LatLng(last.latitude, last.longitude);
        }
      }
    }

    if (startLoc == null) {
      setState(() { _isRouting = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not determine your location.'))
        );
      }
      return;
    }

    // Visual feedback: move camera immediately to start point
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(startLoc.latitude - 0.003, startLoc.longitude), 15.5));

    // Using Google Maps Directions API
    final url = 'https://maps.googleapis.com/maps/api/directions/json';
    
    try {
      final response = await _dio.get(url, queryParameters: {
        'origin': '${startLoc.latitude},${startLoc.longitude}',
        'destination': '${selected.latitude},${selected.longitude}',
        'key': _googleMapsApiKey,
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && response.data['routes'] != null && response.data['routes'].isNotEmpty) {
        final String encodedPolyline = response.data['routes'][0]['overview_polyline']['points'];
        final List<LatLng> finalPoints = _decodePolyline(encodedPolyline);

        if (mounted) {
          // Build tight bounds including start and end
          final swLat = min(startLoc.latitude, selected.latitude!);
          final swLon = min(startLoc.longitude, selected.longitude!);
          final neLat = max(startLoc.latitude, selected.latitude!);
          final neLon = max(startLoc.longitude, selected.longitude!);
          final bounds = LatLngBounds(
            southwest: LatLng(swLat, swLon),
            northeast: LatLng(neLat, neLon),
          );
          _routeBounds = bounds;

          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: finalPoints,
                color: const Color(0xFFED3973),
                width: 5,
                jointType: JointType.round,
                endCap: Cap.roundCap,
                startCap: Cap.roundCap,
              )
            };
            _isRouting = false;
          });

          // Fit camera to show both endpoints. 
          // Map padding will automatically handle the bottom sheet offset.
          controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.0));
        }
      } else {
        setState(() { _isRouting = false; });
      }
    } catch (e) {
      setState(() { _isRouting = false; });
    }
  }


  void _fetchRestaurants() {
    final activeLoc = UserLocationRepository.instance.activeLocation;
    
    _restaurantsFuture = RestaurantRepository.instance.getNearbyShops(
      lat: activeLoc?.latitude ?? _initialPosition.latitude,
      lon: activeLoc?.longitude ?? _initialPosition.longitude,
    ).then((restaurants) {
      _updateMarkers(restaurants);
      
      // Smoothly transition from skeletal loader to map when map is ready
      // (handled in onMapCreated for speed)
      
      // AUTO-ZOOM to show all restaurants on load
      if (restaurants.isNotEmpty) {
        final validPoints = restaurants
            .where((r) => r.latitude != null && r.longitude != null)
            .map((r) => LatLng(r.latitude!, r.longitude!))
            .toList();
            
        if (validPoints.isNotEmpty) {
          // Slightly longer delay to ensure map is ready
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (mounted) {
              final GoogleMapController controller = await _mapController.future;

              final southwestLat = validPoints.map((p) => p.latitude).reduce(min);
              final southwestLon = validPoints.map((p) => p.longitude).reduce(min);
              final northeastLat = validPoints.map((p) => p.latitude).reduce(max);
              final northeastLon = validPoints.map((p) => p.longitude).reduce(max);
              final bounds = LatLngBounds(
                southwest: LatLng(southwestLat, southwestLon),
                northeast: LatLng(northeastLat, northeastLon),
              );

              controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
            }
          });
        }
      }
      return restaurants;
    });
  }

  /// Decodes a Google Maps encoded polyline string into a list of LatLng points.
  static List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }


  /// Creates a custom branded map pin with a fork/spoon icon and restaurant name.
  Future<BitmapDescriptor> _createCustomMarker(Restaurant restaurant, {bool selected = false}) async {
    final String nameStr = restaurant.name.length > 14 
        ? '${restaurant.name.substring(0, 12)}…' 
        : restaurant.name;
    
    final textSpan = TextSpan(
      text: nameStr,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : Colors.black87,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(PhosphorIcons.forkKnife().codePoint),
        style: TextStyle(
          fontSize: 14,
          fontFamily: PhosphorIcons.forkKnife().fontFamily,
          package: PhosphorIcons.forkKnife().fontPackage,
          color: selected ? const Color(0xFFED3973) : Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();

    const hPad = 8.0;
    const vPad = 6.0;
    const iconCircleSize = 24.0;
    const spacing = 6.0;
    const tailH = 6.0;
    const dotSize = 4.0;

    final pillW = iconCircleSize + spacing + textPainter.width + hPad * 2;
    final pillH = iconCircleSize + vPad;
    final totalH = pillH + tailH + dotSize;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, pillW, pillH),
        const Radius.circular(20),
      ),
      shadowPaint,
    );

    // Pill background
    final bgPaint = Paint()..color = selected ? const Color(0xFFED3973) : Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, pillW, pillH),
        const Radius.circular(20),
      ),
      bgPaint,
    );

    // Icon Circle
    final circlePaint = Paint()..color = selected ? Colors.white : const Color(0xFFED3973);
    canvas.drawCircle(Offset(vPad/2 + iconCircleSize/2, pillH / 2), iconCircleSize / 2, circlePaint);
    
    // Icon
    iconPainter.paint(canvas, Offset(
      vPad/2 + (iconCircleSize - iconPainter.width) / 2,
      (pillH - iconPainter.height) / 2,
    ));

    // Rating Text
    textPainter.paint(canvas, Offset(vPad/2 + iconCircleSize + spacing, (pillH - textPainter.height) / 2));

    // Tail triangle
    final tailPaint = Paint()
      ..color = selected ? const Color(0xFFED3973) : Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(pillW / 2 - 4, pillH)
      ..lineTo(pillW / 2 + 4, pillH)
      ..lineTo(pillW / 2, pillH + tailH)
      ..close();
    canvas.drawPath(path, tailPaint);

    // Bottom dot (optional, keeping for style consistency if desired, or remove if strictly matching)
    // canvas.drawCircle(Offset(pillW / 2, totalH - dotSize / 2), dotSize / 2, tailPaint);

    final pic = recorder.endRecording();
    final img = await pic.toImage(pillW.ceil(), totalH.ceil());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }


  void _updateMarkers(List<Restaurant> restaurants) {
    // Create all custom markers in parallel for speed
    Future.wait(restaurants
        .where((r) => r.latitude != null && r.longitude != null)
        .map((r) async {
          final isSelected = _expandedRestaurantId == r.id;
          final icon = await _createCustomMarker(r, selected: isSelected);
          return Marker(
            markerId: MarkerId(r.id),
            position: LatLng(r.latitude!, r.longitude!),
            icon: icon,
            onTap: () => _onMarkerTapped(r),
            anchor: const Offset(0.5, 1.0),
            zIndexInt: isSelected ? 1 : 0,
          );
        })
        .toList()
    ).then((markers) {
      if (mounted) {
        setState(() {
          _markers = markers.toSet();
        });
      }
    });
  }

  void _centerMapOnRestaurant(Restaurant r, {bool isExpandedAtTarget = false}) async {
    if (r.latitude == null || r.longitude == null) return;
    
    // Map padding automatically offsets the optical center to the visible area
    // No manual latitude offset is needed anymore.
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(r.latitude!, r.longitude!),
      16.5, // Zoom in closer on selected restaurant
    ));
  }

  void _onMarkerTapped(Restaurant r) {
    setState(() {
      if (_expandedRestaurantId == r.id) {
        _expandedRestaurantId = null;
        _polylines.clear();
        _routeBounds = null;
      } else {
        _expandedRestaurantId = r.id;
        _polylines.clear();
        _routeBounds = null;
        // The sheet is now fixed height, so we don't animate its height
      }
    });

    // Re-render markers to show selected state
    _restaurantsFuture?.then((restaurants) => _updateMarkers(restaurants));

    // Center map on marker with offset
    _centerMapOnRestaurant(r, isExpandedAtTarget: true);

    // Scroll to the item in the list
    // Use a short delay to allow the sheet's state to update smoothly
    Future.delayed(const Duration(milliseconds: 150), () {
      final key = _itemKeys[r.id];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.0, // Scroll to top
        );
      }
    });
  }

  void _navigateToDetail(Restaurant data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetailPage(
          id: data.id,
          name: data.name,
          category: data.category,
          rating: data.rating,
          distance: data.distance,
          imagePath: data.imagePath,
          logoPath: data.logoPath,
          deliveryTime: data.deliveryTime,
          status: data.status,
          latitude: data.latitude,
          longitude: data.longitude,
          popularDishes: data.popularDishes,
          recommendations: data.recommendations,
          hotDeals: data.hotDeals,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final newStatus = !(_localFavorites[restaurant.id] ?? restaurant.isFavorite);
    final messenger = ScaffoldMessenger.of(context);
    
    // Immediate local feedback
    setState(() {
      _localFavorites[restaurant.id] = newStatus;
    });

    try {
      await RestaurantRepository.instance.toggleShopFavorite(
        int.tryParse(restaurant.id) ?? 0, 
        newStatus,
      );
      // No longer refreshing the future here to prevent flickering.
      // The local state _localFavorites handles the immediate color change.
      
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Added to favorites' : 'Removed from favorites'),
            backgroundColor: const Color(0xFFED3A72),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _localFavorites[restaurant.id] = !newStatus;
        });
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Failed to update favorite. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _listScrollController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Google Maps Widget
          Positioned.fill(
            child: FutureBuilder<List<Restaurant>>(
              future: _restaurantsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const MapSkeletonLoader();
                }
                return AnimatedOpacity(
                  opacity: _showMap ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: const CameraPosition(
                      target: _initialPosition,
                      zoom: 14.0,
                    ),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).size.height * 0.52,
                      top: MediaQuery.of(context).padding.top,
                    ),
                    onMapCreated: (GoogleMapController controller) async {
                      _mapController.complete(controller);
                      // Show map immediately for speed
                      if (mounted) {
                        setState(() => _showMap = true);
                      }
                    },
                    style: AppMapTheme.defaultStyle,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    markers: _markers,
                    polylines: _polylines,
                  ),
                );
              },

            ),
          ),
          
          // Top Search Bar Area
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                // Search Box
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.magnifyingGlass(), color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'What shall we deliver?',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Route Pill Button - shown above restaurant list when a restaurant is selected
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.52 + 16,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSlide(
                offset: _expandedRestaurantId != null ? Offset.zero : const Offset(0, 1.5),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _expandedRestaurantId != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: _expandedRestaurantId == null,
                    child: GestureDetector(
                      onTap: _isRouting ? null : _onCurrentLocationTapped,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          color: _isRouting ? Colors.white : const Color(0xFFED3973),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFED3973).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isRouting)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFED3973),
                                ),
                              )
                            else
                              const Icon(
                                Icons.near_me_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _isRouting
                                  ? 'Finding route…'
                                  : (_polylines.isNotEmpty ? 'See full route' : 'Show me the way'),
                              style: GoogleFonts.poppins(
                                color: _isRouting ? const Color(0xFFED3973) : Colors.white,
                                fontSize: 13,
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
          ),

          // Fixed-height bottom sheet showing restaurant list
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.52,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 12),
                    child: Text(
                      'Restaurants Nearby',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  // Scrollable restaurant list
                  Expanded(
                    child: FutureBuilder<List<Restaurant>>(
                      future: _restaurantsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return ListView.builder(
                            itemCount: 5,
                            itemBuilder: (_, __) => const NearbyRestaurantListItemSkeleton(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cloud_off, color: Colors.red.shade300, size: 48),
                                  const SizedBox(height: 12),
                                  Text('Connection Error', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Text('Couldn\'t load restaurants.', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13), textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchRestaurants,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFED3973),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    child: Text('Retry', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Text(
                              'No restaurants found nearby.',
                              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                            ),
                          );
                        }

                        final restaurants = snapshot.data!;
                        return ListView.builder(
                          controller: _listScrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
                          itemCount: restaurants.length,
                          itemBuilder: (context, index) {
                            final data = restaurants[index];
                            final key = _itemKeys.putIfAbsent(data.id, () => GlobalKey());

                            return NearbyRestaurantListItem(
                              key: key,
                              name: data.name,
                              category: data.category,
                              rating: data.rating,
                              distance: data.distance,
                              imagePath: data.imagePath,
                              deliveryTime: data.deliveryTime,
                              status: data.status,
                              imageUrls: data.imageUrls,
                              isExpanded: _expandedRestaurantId == data.id,
                              isFavorite: _localFavorites[data.id] ?? data.isFavorite,
                              onFavoriteToggle: () => _toggleFavorite(data),
                              onTap: () {
                                setState(() {
                                  if (_expandedRestaurantId == data.id) {
                                    _expandedRestaurantId = null;
                                    _polylines.clear();
                                    _routeBounds = null;
                                  } else {
                                    _expandedRestaurantId = data.id;
                                    _polylines.clear();
                                    _routeBounds = null;

                                    if (data.latitude != null && data.longitude != null) {
                                      _centerMapOnRestaurant(data, isExpandedAtTarget: true);
                                    }

                                    // Scroll to this item in list
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      final ctx = key.currentContext;
                                      if (ctx != null) {
                                        Scrollable.ensureVisible(
                                          ctx,
                                          duration: const Duration(milliseconds: 400),
                                          curve: Curves.easeInOut,
                                          alignment: 0.0,
                                        );
                                      }
                                    });

                                    // Re-render markers to reflect selection
                                    _restaurantsFuture?.then((rs) => _updateMarkers(rs));
                                  }
                                });
                              },
                              onViewMenu: () => _navigateToDetail(data),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
