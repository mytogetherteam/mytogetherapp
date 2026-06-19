import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/theme/app_map_theme.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/location/location_search_service.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_display_util.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../auth/data/session_location_store.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../widgets/map_picker_address_panel.dart';

/// Full-screen map for picking a delivery location by moving the map under a
/// fixed center pin. Returns a [PlaceResult] when the user confirms.
class LocationMapPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;

  const LocationMapPickerPage({
    super.key,
    this.initialLat,
    this.initialLon,
  });

  @override
  State<LocationMapPickerPage> createState() => _LocationMapPickerPageState();
}

class _LocationMapPickerPageState extends State<LocationMapPickerPage> {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _addressController = TextEditingController();
  Timer? _geocodeDebounce;
  int _geocodeGeneration = 0;

  LatLng? _selectedPosition;
  LatLng? _cameraTarget;
  LatLng? _lastGeocodedPosition;
  PlaceResult? _selectedPlace;
  bool _isGeocoding = false;
  bool _isLoadingInitial = true;
  bool _mapReady = false;
  bool _isMapMoving = false;
  bool _addressTouched = false;
  String? _addressError;

  static const _pinLift = 36.0;
  static const _idleDebounce = Duration(milliseconds: 500);
  /// Ignore idle/geocode churn until the pin moves at least this far.
  static const _minGeocodeDistanceMeters = 20.0;

  @override
  void initState() {
    super.initState();
    _resolveInitialPosition();
  }

  Future<void> _resolveInitialPosition() async {
    double? lat;
    double? lon;

    try {
      final pos = await LocationService().getCurrentPosition(
        requestPermissionIfDenied: true,
        forceRefresh: true,
        highAccuracy: true,
      );
      if (LocationService().hasRealPosition) {
        lat = pos.latitude;
        lon = pos.longitude;
      }
    } catch (_) {}

    lat ??= widget.initialLat;
    lon ??= widget.initialLon;

    if (lat == null || lon == null) {
      try {
        final coords =
            await UserLocationRepository.instance.resolveActiveCoordinates();
        lat = coords.lat;
        lon = coords.lon;
      } catch (_) {
        lat = LocationService.defaultLat;
        lon = LocationService.defaultLon;
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedPosition = LatLng(lat!, lon!);
      _cameraTarget = LatLng(lat, lon);
      _isLoadingInitial = false;
    });
    _hydrateAddressField(lat, lon);
  }

  Future<void> _hydrateAddressField(double lat, double lon) async {
    final stored = await SessionLocationStore.addressNear(lat, lon);
    if (!mounted) return;
    if (stored != null && stored.isNotEmpty && !_addressTouched) {
      _addressController.text = stored;
    }
  }

  void _applyGeocodedAddress(String? rawAddress) {
    final readable = LocationDisplayUtil.readableAddress(rawAddress);
    if (readable == null || _addressTouched) return;
    _addressController.text = readable;
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  void _onCameraMoveStarted() {
    _geocodeDebounce?.cancel();
    _addressTouched = false;
    if (!_isMapMoving && mounted) {
      setState(() => _isMapMoving = true);
    }
  }

  void _onCameraMove(CameraPosition position) {
    _cameraTarget = position.target;
  }

  void _onCameraIdle() {
    if (!mounted) return;
    if (_isMapMoving) {
      setState(() => _isMapMoving = false);
    }
    _scheduleGeocodeAfterIdle();
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _toRad(double deg) => deg * math.pi / 180;

  bool _shouldGeocode(LatLng target) {
    if (_lastGeocodedPosition == null) return true;
    return _distanceMeters(_lastGeocodedPosition!, target) >=
        _minGeocodeDistanceMeters;
  }

  void _scheduleGeocodeAfterIdle({bool force = false}) {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(_idleDebounce, () {
      _reverseGeocodeCenter(force: force);
    });
  }

  Future<void> _reverseGeocodeCenter({bool force = false}) async {
    if (!_mapReady || _isMapMoving) return;

    final target = _cameraTarget ?? _selectedPosition;
    if (target == null || !mounted || _isMapMoving) return;

    if (!force && !_shouldGeocode(target)) return;

    final generation = ++_geocodeGeneration;

    if (mounted) {
      setState(() {
        _isGeocoding = true;
        _selectedPosition = target;
      });
    }

    final place = await LocationSearchService.instance.reverseGeocode(
      target.latitude,
      target.longitude,
    );

    if (!mounted || generation != _geocodeGeneration || _isMapMoving) return;

    setState(() {
      _isGeocoding = false;
      _lastGeocodedPosition = target;
      if (place != null) {
        _selectedPlace = place;
        _applyGeocodedAddress(place.displayName);
      }
    });
  }

  Future<void> _goToMyLocation() async {
    try {
      LocationService().clearCache();
      final pos = await LocationService().getCurrentPosition(
        requestPermissionIfDenied: true,
        forceRefresh: true,
        highAccuracy: true,
      );
      if (!LocationService().hasRealPosition) {
        if (!mounted) return;
        if (!kIsWeb) {
          await LocationService().openAppSettings();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('location.unavailable'))),
        );
        return;
      }
      final target = LatLng(pos.latitude, pos.longitude);
      final controller = await _mapController.future;
      await controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
      if (mounted) {
        setState(() {
          _selectedPosition = target;
          _cameraTarget = target;
          _lastGeocodedPosition = null;
          _selectedPlace = null;
          _addressTouched = false;
        });
        _scheduleGeocodeAfterIdle(force: true);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('location.unavailable'))),
      );
    }
  }

  Future<void> _confirm() async {
    if (_isMapMoving || _selectedPosition == null) return;

    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() {
        _addressError = context.tr('location.street_address_required');
      });
      return;
    }

    final pos = _selectedPosition!;
    var place = _selectedPlace;

    if (place == null) {
      setState(() => _isGeocoding = true);
      place = await LocationSearchService.instance.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );
      if (mounted) setState(() => _isGeocoding = false);
    }

    if (!mounted) return;

    await SessionLocationStore.save(
      latitude: pos.latitude,
      longitude: pos.longitude,
      address: address,
    );

    if (!mounted) return;

    Navigator.pop(
      context,
      PlaceResult(
        placeId: place?.placeId ?? '',
        name: place?.name ?? context.tr('location.current'),
        displayName: address,
        lat: pos.latitude,
        lon: pos.longitude,
        type: place?.type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('location.map_picker_title'),
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoadingInitial || _selectedPosition == null
          ? const Center(child: CustomLoadingIndicator(size: 32))
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _selectedPosition!,
                          zoom: 16,
                        ),
                        padding: const EdgeInsets.only(bottom: _pinLift),
                        myLocationEnabled: !kIsWeb,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        style: AppMapTheme.defaultStyle,
                        onMapCreated: (controller) {
                          if (!_mapController.isCompleted) {
                            _mapController.complete(controller);
                          }
                          _cameraTarget = _selectedPosition;
                          if (mounted) setState(() => _mapReady = true);
                          _scheduleGeocodeAfterIdle(force: true);
                        },
                        onCameraMoveStarted: _onCameraMoveStarted,
                        onCameraMove: _onCameraMove,
                        onCameraIdle: _onCameraIdle,
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: _pinLift),
                          child: Icon(
                            PhosphorIconsFill.mapPin,
                            size: 44,
                            color: AppColors.primary,
                            shadows: const [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.white,
                          elevation: 4,
                          onPressed: _goToMyLocation,
                          child: Icon(
                            PhosphorIcons.crosshairSimple,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                MapPickerAddressPanel(
                  addressController: _addressController,
                  isGeocoding: _isGeocoding,
                  isMapMoving: _isMapMoving,
                  isSaving: false,
                  canConfirmBase: _selectedPosition != null,
                  addressError: _addressError,
                  onAddressChanged: () {
                    setState(() {
                      _addressTouched = true;
                      if (_addressController.text.trim().isNotEmpty) {
                        _addressError = null;
                      }
                    });
                  },
                  onConfirm: _confirm,
                ),
              ],
            ),
    );
  }
}
