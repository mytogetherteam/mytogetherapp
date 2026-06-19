import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/restaurant_data.dart' show Restaurant;
import '../widgets/restaurant_card.dart';
import '../widgets/nearby_restaurant_list_item_skeleton.dart';
import '../widgets/map_skeleton_loader.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'restaurant_detail_page.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_map_theme.dart';
import '../../../../core/config/google_maps_config.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';

class RestaurantNearbyListPage extends StatefulWidget {
  const RestaurantNearbyListPage({super.key});

  @override
  State<RestaurantNearbyListPage> createState() =>
      _RestaurantNearbyListPageState();
}

class _RestaurantNearbyListPageState extends State<RestaurantNearbyListPage> {
  Future<List<Restaurant>>? _restaurantsFuture;
  final Map<String, bool> _localFavorites = {};
  final ScrollController _listScrollController = ScrollController();
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  Set<Marker> _markers = {};
  String? _expandedRestaurantId;
  final Map<String, GlobalKey> _itemKeys = {};
  static const LatLng _initialPosition = LatLng(
    13.7000,
    100.5018,
  ); // Shifted north to move view "down"
  LatLng? _currentLocation;
  Set<Polyline> _polylines = {};
  bool _isRouting = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _showMap = false;
  double _currentZoom = 14.0;
  double _selectedRadius = 5.0;

  late final Dio _dio;
  String get _googleMapsApiKey => GoogleMapsConfig.apiKey;

  @override
  void initState() {
    super.initState();
    _dio = Dio();
    _fetchRestaurants();
    _initLocationService();
    UserLocationRepository.instance.addListener(_onActiveLocationChanged);
  }

  void _onActiveLocationChanged() {
    if (!mounted) return;
    _fetchRestaurants();
  }

  Future<void> _initLocationService() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    // Rely on LocationService singleton for permissions (handled at startup)
    // or just check briefly without requesting to avoid double prompts.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // 1. Immediate last known position (mobile only — not supported on web).
    if (!kIsWeb) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
        });
      }
    }

    // 2. Start streaming for real-time updates (Keep GPS warm)
    // Distance filter of 10m to avoid too many UI rebuilds
    _positionStreamSubscription =
        Geolocator.getPositionStream(
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

  Future<void> _launchExternalMaps(double sLat, double sLng, double dLat, double dLng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&origin=$sLat,$sLng&destination=$dLat,$dLng&travelmode=driving';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('nearby.location_failed'))),
        );
      }
    }
  }

  // Cached route bounds for re-centering when route already exists
  LatLngBounds? _routeBounds;

  Future<void> _onCurrentLocationTapped() async {
    if (_expandedRestaurantId == null || _restaurantsFuture == null) return;

    // SECOND CLICK: route already displayed — re-center camera to show full route
    if (_polylines.isNotEmpty && _routeBounds != null) {
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          _routeBounds!,
          80.0, // Just use a generous flat padding since map padding will handle the sheet
        ),
      );
      return;
    }

    setState(() {
      _isRouting = true;
    });

    final rList = await _restaurantsFuture!;
    final selected = rList.cast<Restaurant?>().firstWhere(
      (element) => element?.id == _expandedRestaurantId,
      orElse: () => null,
    );

    if (selected == null ||
        selected.latitude == null ||
        selected.longitude == null) {
      setState(() {
        _isRouting = false;
      });
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
        if (!kIsWeb) {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) {
            startLoc = LatLng(last.latitude, last.longitude);
          }
        }
      }
    }

    if (startLoc == null) {
      setState(() {
        _isRouting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('nearby.location_failed'))),
        );
      }
      return;
    }

    // Visual feedback: move camera immediately to start point
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(startLoc.latitude - 0.003, startLoc.longitude),
        15.5,
      ),
    );

    // Using Google Maps Directions API
    final url = 'https://maps.googleapis.com/maps/api/directions/json';

    try {
      final response = await _dio
          .get(
            url,
            queryParameters: {
              'origin': '${startLoc.latitude},${startLoc.longitude}',
              'destination': '${selected.latitude},${selected.longitude}',
              'key': _googleMapsApiKey,
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 &&
          response.data['routes'] != null &&
          response.data['routes'].isNotEmpty) {
        final String encodedPolyline =
            response.data['routes'][0]['overview_polyline']['points'];
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
                color: AppColors.primary,
                width: 5,
                jointType: JointType.round,
                endCap: Cap.roundCap,
                startCap: Cap.roundCap,
              ),
            };
            _isRouting = false;
          });

          // Fit camera to show both endpoints.
          // Map padding will automatically handle the bottom sheet offset.
          controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.0));
        }
      } else {
        setState(() {
          _isRouting = false;
        });
        _launchExternalMaps(startLoc.latitude, startLoc.longitude, selected.latitude!, selected.longitude!);
      }
    } catch (e) {
      setState(() {
        _isRouting = false;
      });
      _launchExternalMaps(startLoc.latitude, startLoc.longitude, selected.latitude!, selected.longitude!);
    }
  }

  void _fetchRestaurants() {
    _restaurantsFuture = _loadRestaurants();
  }

  Future<List<Restaurant>> _loadRestaurants() async {
    // Shared resolver keeps the origin consistent with the home nearby rail
    // and the food search (saved active location → device GPS → default).
    final coords =
        await UserLocationRepository.instance.resolveActiveCoordinates();

    final restaurants = await RestaurantRepository.instance.getNearbyShops(
      lat: coords.lat,
      lon: coords.lon,
      radius: _selectedRadius,
    );

    _updateMarkers(restaurants);

    final validPoints = restaurants
        .where((r) => r.latitude != null && r.longitude != null)
        .map((r) => LatLng(r.latitude!, r.longitude!))
        .toList();

    // Move the camera to reflect where we actually searched: fit all results
    // when present, otherwise center on the queried origin (instead of the
    // hardcoded initial Bangkok view, which made an empty list look wrong).
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final GoogleMapController controller = await _mapController.future;

      if (validPoints.length == 1) {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(validPoints.first, 15.0),
        );
      } else if (validPoints.isNotEmpty) {
        final bounds = LatLngBounds(
          southwest: LatLng(
            validPoints.map((p) => p.latitude).reduce(min),
            validPoints.map((p) => p.longitude).reduce(min),
          ),
          northeast: LatLng(
            validPoints.map((p) => p.latitude).reduce(max),
            validPoints.map((p) => p.longitude).reduce(max),
          ),
        );
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
      } else {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(coords.lat, coords.lon), 13.0),
        );
      }
    });

    return restaurants;
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
  Future<BitmapDescriptor> _createCustomMarker(
    Restaurant restaurant, {
    bool selected = false,
    required double zoom,
    required int index,
  }) async {
    // To prevent map clutter, we only show text for the selected marker.
    bool showText = selected;

    final String nameStr = restaurant.name.length > 14
        ? '${restaurant.name.substring(0, 12)}…'
        : restaurant.name;

    final double fontSize = 9.5;

    final textSpan = TextSpan(
      text: nameStr,
      style: GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: selected ? Colors.white : AppColors.primary,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    if (showText) {
      textPainter.layout();
    }

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(PhosphorIcons.forkKnife.codePoint),
        style: TextStyle(
          fontSize: showText ? 14 : 12,
          fontFamily: PhosphorIcons.forkKnife.fontFamily,
          package: PhosphorIcons.forkKnife.fontPackage,
          color: selected ? AppColors.primary : Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();

    const hPad = 8.0;
    const vPad = 6.0;
    final iconCircleSize = showText ? 24.0 : 18.0;
    const spacing = 6.0;
    const tailH = 6.0;
    const dotSize = 4.0;

    final pillW = showText
        ? (iconCircleSize + spacing + textPainter.width + hPad * 2)
        : iconCircleSize + (selected ? (hPad * 2) : 0);
    final pillH = iconCircleSize + vPad;
    final totalH = pillH + tailH + dotSize;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Scale by 3x for sharp high-DPI text on devices
    const double pixelRatio = 3.0;
    canvas.scale(pixelRatio, pixelRatio);

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    if (selected || showText) {
      if (selected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(2, 2, pillW, pillH),
            const Radius.circular(20),
          ),
          shadowPaint,
        );
      } else {
        canvas.drawCircle(
          Offset(vPad / 2 + iconCircleSize / 2 + 1, pillH / 2 + 2),
          iconCircleSize / 2,
          shadowPaint,
        );
      }
    } else {
      // Small icon shadow
      canvas.drawCircle(
        Offset(iconCircleSize / 2 + 1, iconCircleSize / 2 + 1),
        iconCircleSize / 2,
        shadowPaint,
      );
    }

    // Pill background
    final bgPaint = Paint()
      ..color = selected
          ? AppColors.primary
          : (showText ? Colors.transparent : AppColors.primary);
    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, pillW, pillH),
          const Radius.circular(20),
        ),
        bgPaint,
      );
    }

    // Icon Circle
    if (showText || selected) {
      final circlePaint = Paint()
        ..color = selected ? Colors.white : AppColors.primary;
      canvas.drawCircle(
        Offset(vPad / 2 + iconCircleSize / 2, pillH / 2),
        iconCircleSize / 2,
        circlePaint,
      );

      // Icon inside circle
      iconPainter.paint(
        canvas,
        Offset(
          vPad / 2 + (iconCircleSize - iconPainter.width) / 2,
          (pillH - iconPainter.height) / 2,
        ),
      );
    } else {
      // Just drawn small standalone circle
      canvas.drawCircle(
        Offset(iconCircleSize / 2, iconCircleSize / 2),
        iconCircleSize / 2,
        bgPaint,
      );
      iconPainter.paint(
        canvas,
        Offset(
          (iconCircleSize - iconPainter.width) / 2,
          (iconCircleSize - iconPainter.height) / 2,
        ),
      );
    }

    // Text
    if (showText) {
      final textOffset = Offset(
        vPad / 2 + iconCircleSize + spacing,
        (pillH - textPainter.height) / 2,
      );
      textPainter.paint(canvas, textOffset);
    }

    // Tail triangle
    if (selected) {
      final tailPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(pillW / 2 - 4, pillH)
        ..lineTo(pillW / 2 + 4, pillH)
        ..lineTo(pillW / 2, pillH + tailH)
        ..close();
      canvas.drawPath(path, tailPaint);
    }

    final pic = recorder.endRecording();
    // width/height passed to BitmapDescriptor.bytes needs to match the canvas size
    final finalW = showText || selected ? pillW : iconCircleSize;
    final finalH = showText || selected ? totalH : iconCircleSize;

    final img = await pic.toImage(
      (finalW * pixelRatio).ceil(),
      (finalH * pixelRatio).ceil(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      data!.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
      width: finalW,
      height: finalH,
    );
  }

  void _updateMarkers(List<Restaurant> restaurants) {
    // Create all custom markers in parallel for speed
    Future.wait(
      restaurants
          .where((r) => r.latitude != null && r.longitude != null)
          .toList()
          .asMap()
          .entries
          .map((entry) async {
            final int index = entry.key;
            final Restaurant r = entry.value;
            final isSelected = _expandedRestaurantId == r.id;

            // Optimization: if zoomed in (>=15), we could filter markers by visible map region.
            // But for now, returning all markers and relying on progressive disclosure in _createCustomMarker

            final icon = await _createCustomMarker(
              r,
              selected: isSelected,
              zoom: _currentZoom,
              index: index,
            );
            return Marker(
              markerId: MarkerId(r.id),
              position: LatLng(r.latitude!, r.longitude!),
              icon: icon,
              onTap: () => _onMarkerTapped(r),
              anchor: const Offset(0.5, 1.0),
              zIndexInt: isSelected ? 1 : 0,
            );
          })
          .toList(),
    ).then((markers) {
      if (mounted) {
        setState(() {
          _markers = markers.toSet();
        });
      }
    });
  }

  void _centerMapOnRestaurant(
    Restaurant r, {
    bool isExpandedAtTarget = false,
  }) async {
    if (r.latitude == null || r.longitude == null) return;

    // Map padding automatically offsets the optical center to the visible area
    // No manual latitude offset is needed anymore.
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(r.latitude!, r.longitude!),
        16.5, // Zoom in closer on selected restaurant
      ),
    );
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
          isFavorite: _localFavorites[data.id] ?? data.isFavorite,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final newStatus =
        !(_localFavorites[restaurant.id] ?? restaurant.isFavorite);
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
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _localFavorites[restaurant.id] = !newStatus;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.tr('common.favorite_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    UserLocationRepository.instance.removeListener(_onActiveLocationChanged);
    _positionStreamSubscription?.cancel();
    _listScrollController.dispose();
    super.dispose();
  }

  void _onCameraMove(CameraPosition position) {
    // Only update state if crossing a threshold OR just store it
    _currentZoom = position.zoom;
  }

  Future<void> _onCameraIdle() async {
    await _mapController.future;
    if (_restaurantsFuture != null) {
      final restaurants = await _restaurantsFuture!;
      _updateMarkers(restaurants);
    }
  }
  void _showRangeFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Distance Range',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...[1.0, 3.0, 5.0, 10.0, 20.0, 30.0, 50.0, 100.0].map((radius) {
                        final isSelected = _selectedRadius == radius;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                          title: Text(
                            '${radius.toInt()} KM',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? AppColors.primary : Colors.black87,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(PhosphorIcons.checkCircleFill, color: AppColors.primary)
                              : const SizedBox.shrink(),
                          onTap: () {
                            Navigator.pop(context);
                            if (_selectedRadius != radius) {
                              setState(() {
                                _selectedRadius = radius;
                              });
                              _fetchRestaurants();
                            }
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.52;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Google Maps Widget — constrained to the area ABOVE the bottom sheet
          // (with a small overlap behind its rounded corners). Keeping the map
          // platform view out from under the list prevents list-scroll gestures
          // from leaking into the map (which made it pan/zoom while scrolling).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: sheetHeight - 40,
            child: Stack(
              children: [
                GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: const CameraPosition(
                    target: _initialPosition,
                    zoom: 14.0,
                  ),
                  padding: EdgeInsets.only(
                    bottom: 56,
                    top: MediaQuery.of(context).padding.top,
                  ),
                  onMapCreated: (GoogleMapController controller) async {
                    if (!_mapController.isCompleted) {
                      _mapController.complete(controller);
                    }
                    // Show map immediately for speed
                    if (mounted) {
                      setState(() => _showMap = true);
                    }
                  },
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  style: AppMapTheme.defaultStyle,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  markers: _markers,
                  polylines: _polylines,
                ),
                // Show lazy loading skeleton while map native view is initializing
                if (!_showMap)
                  const Positioned.fill(
                    child: MapSkeletonLoader(),
                  ),
              ],
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
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.black,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Spacer(),
                // KM Range Filter Modal Pill
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _showRangeFilterModal,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIcons.faders,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Up to ${_selectedRadius.toInt()} KM',
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
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
              ],
            ),
          ),

          // Route Pill Button - shown above restaurant list when a restaurant is selected
          Positioned(
            bottom: sheetHeight + 16,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSlide(
                offset: _expandedRestaurantId != null
                    ? Offset.zero
                    : const Offset(0, 1.5),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _expandedRestaurantId != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: _expandedRestaurantId == null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Button 1: Explore
                        GestureDetector(
                          onTap: () async {
                            if (_restaurantsFuture != null && _expandedRestaurantId != null) {
                              final restaurants = await _restaurantsFuture!;
                              final selected = restaurants.cast<Restaurant?>().firstWhere(
                                (r) => r?.id == _expandedRestaurantId,
                                orElse: () => null,
                              );
                              if (selected != null) {
                                _navigateToDetail(selected);
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  PhosphorIcons.storefront,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Explore',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Button 2: Show me the way
                        GestureDetector(
                          onTap: _isRouting ? null : _onCurrentLocationTapped,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: _isRouting ? Colors.white : null,
                              gradient: _isRouting
                                  ? null
                                  : AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isRouting)
                                  const CustomLoadingIndicator(size: 16)
                                else
                                  const Icon(
                                    Icons.near_me_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  _isRouting
                                      ? context.tr('nearby.finding_route')
                                      : (_polylines.isNotEmpty
                                            ? context.tr('nearby.see_full_route')
                                            : context.tr('nearby.show_me_the_way')),
                                  style: GoogleFonts.poppins(
                                    color: _isRouting
                                        ? AppColors.primary
                                        : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
            height: sheetHeight,
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
                    padding: const EdgeInsets.only(
                      top: 20,
                      left: 24,
                      right: 24,
                      bottom: 12,
                    ),
                    child: Text(
                      context.tr('home.restaurants_nearby'),
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ListView.builder(
                            padding: const EdgeInsets.only(top: 10),
                            itemCount: 3,
                            itemBuilder: (_, _) =>
                                const NearbyRestaurantListItemSkeleton(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cloud_off,
                                    color: Colors.red.shade300,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('nearby.connection_error'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.tr('nearby.load_failed'),
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  PrimaryGradientButton(
                                    onPressed: _fetchRestaurants,
                                    height: 42,
                                    width: 100,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Text(
                                      context.tr('common.retry'),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Text(
                              context.tr('nearby.no_nearby'),
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        final restaurants = snapshot.data!;
                        return ListView.builder(
                          controller: _listScrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).padding.bottom + 40,
                          ),
                          itemCount: restaurants.length,
                          itemBuilder: (context, index) {
                            final data = restaurants[index];
                            final key = _itemKeys.putIfAbsent(
                              data.id,
                              () => GlobalKey(),
                            );

                            return RestaurantCard(
                              key: key,
                              name: data.name,
                              category: data.category,
                              rating: data.rating,
                              reviewCount: data.reviewCount,
                              distance: data.distance,
                              imagePath: data.imagePath,
                              logoPath: data.logoPath,
                              deliveryTime: data.deliveryTime,
                              deliveryFee: data.deliveryFee,
                              originalDeliveryFee: data.originalDeliveryFee,
                              deliveryEnabled: data.deliveryEnabled,
                              operatingHours: data.operatingHours,
                              status: data.status,
                              shopId: data.id,
                              isFavorite:
                                  _localFavorites[data.id] ?? data.isFavorite,
                              onFavoriteToggle: () => _toggleFavorite(data),
                              onTap: () {
                                if (_expandedRestaurantId == data.id) {
                                  // Already selected: navigate to detail
                                  _navigateToDetail(data);
                                } else {
                                  // Not selected: select and zoom on map
                                  setState(() {
                                    _expandedRestaurantId = data.id;
                                    _centerMapOnRestaurant(
                                      data,
                                      isExpandedAtTarget: true,
                                    );
                                    _updateMarkers(restaurants);
                                  });
                                }
                              },
                              width: double.infinity,
                              margin: const EdgeInsets.only(
                                bottom: 24,
                                left: 20,
                                right: 20,
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
          ),
        ],
      ),
    );
  }
}
