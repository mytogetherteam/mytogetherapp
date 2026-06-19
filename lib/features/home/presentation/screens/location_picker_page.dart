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

import '../../../../core/config/google_maps_config.dart';
import '../../../../core/location/location_search_service.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../auth/data/models/user_location_model.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../widgets/location_details_sheet.dart';

/// Unified map + search + pin screen for adding a delivery location.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  Timer? _geocodeDebounce;
  Timer? _searchDebounce;
  int _geocodeGeneration = 0;

  LatLng? _selectedPosition;
  LatLng? _cameraTarget;
  LatLng? _lastGeocodedPosition;
  PlaceResult? _selectedPlace;
  List<PlaceResult> _searchResults = [];
  bool _isGeocoding = false;
  bool _isSearching = false;
  bool _isLoadingInitial = true;
  bool _isSaving = false;
  bool _mapReady = false;
  bool _isMapMoving = false;
  bool _showSearchResults = false;

  static const _pinLift = 36.0;
  static const _idleDebounce = Duration(milliseconds: 500);
  static const _minGeocodeDistanceMeters = 20.0;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus && _searchController.text.trim().isEmpty) {
        setState(() => _showSearchResults = false);
      }
    });
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _resolveInitialPosition();
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
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
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final target = _cameraTarget ?? _selectedPosition;
      final results = await LocationSearchService.instance.searchPlaces(
        trimmed,
        lat: target?.latitude,
        lon: target?.longitude,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _selectSearchResult(PlaceResult place) async {
    _searchFocus.unfocus();
    setState(() {
      _showSearchResults = false;
      _searchResults = [];
      _isGeocoding = true;
    });

    PlaceResult resolved = place;
    if (place.lat == 0 && place.lon == 0) {
      final details =
          await LocationSearchService.instance.getPlaceDetails(place);
      if (details != null) resolved = details;
    }

    if (resolved.lat == 0 && resolved.lon == 0) {
      if (mounted) setState(() => _isGeocoding = false);
      return;
    }

    final target = LatLng(resolved.lat, resolved.lon);
    final controller = await _mapController.future;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));

    if (!mounted) return;
    setState(() {
      _selectedPosition = target;
      _cameraTarget = target;
      _lastGeocodedPosition = target;
      _selectedPlace = resolved;
      _isGeocoding = false;
    });
    _searchController.text = resolved.name;
  }

  void _onCameraMoveStarted() {
    _geocodeDebounce?.cancel();
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
        if (!kIsWeb) await LocationService().openAppSettings();
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

  Future<PlaceResult?> _resolveConfirmedPlace() async {
    if (_selectedPosition == null) return null;

    var place = _selectedPlace;
    final pos = _selectedPosition!;

    if (place == null || place.displayName.isEmpty) {
      place = await LocationSearchService.instance.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );
    }

    if (place != null && place.lat != 0 && place.lon != 0) {
      return place;
    }

    return PlaceResult(
      placeId: '',
      name: '',
      displayName:
          '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
      lat: pos.latitude,
      lon: pos.longitude,
    );
  }

  Future<void> _confirm() async {
    if (_isMapMoving || _isSaving || _selectedPosition == null) return;

    setState(() => _isGeocoding = true);
    final place = await _resolveConfirmedPlace();
    if (!mounted) return;
    setState(() => _isGeocoding = false);

    if (place == null) return;

    final draft = UserLocationModel(
      id: 0,
      latitude: place.lat,
      longitude: place.lon,
      locationName: null,
      address: place.displayName,
      locationType: 'OTHER',
      isPrimary: true,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => LocationDetailsSheet(
        location: draft,
        isEdit: false,
        onSave: _persistNewLocation,
      ),
    );
  }

  Future<void> _persistNewLocation(UserLocationModel model) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final saved = await UserLocationRepository.instance.addLocation(model);
      UserLocationRepository.instance.setActiveLocation(saved);
      if (mounted) {
        Navigator.pop(context, saved);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('location.saved_success')),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              UserLocationRepository.errorMessage(
                e,
                fallback: context.tr('location.save_failed'),
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoadingInitial || _selectedPosition == null
          ? const Center(child: CustomLoadingIndicator(size: 32))
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _selectedPosition!,
                              zoom: 16,
                            ),
                            padding: const EdgeInsets.only(
                              top: 72,
                              bottom: _pinLift,
                            ),
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
                              padding: const EdgeInsets.only(
                                top: 36,
                                bottom: _pinLift,
                              ),
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
                    _buildBottomPanel(),
                  ],
                ),
                _buildSearchOverlay(),
                if (_isSaving)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x44FFFFFF),
                      child: Center(child: CustomLoadingIndicator(size: 32)),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSearchOverlay() {
    final topInset = MediaQuery.of(context).padding.top;

    if (!GoogleMapsConfig.placesSearchEnabled) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: topInset + 8,
            left: 8,
            child: Material(
              color: Colors.white,
              elevation: 4,
              shadowColor: Colors.black26,
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: topInset + 8,
          left: 8,
          right: 16,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
              ),
              Expanded(
                child: Material(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(24),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    onTap: () {
                      if (_searchController.text.trim().isNotEmpty) {
                        setState(() => _showSearchResults = true);
                      }
                    },
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('location.search_hint'),
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(
                        PhosphorIcons.magnifyingGlass,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showSearchResults && _searchController.text.trim().isNotEmpty)
          Positioned(
            top: topInset + 64,
            left: 56,
            right: 16,
            child: Material(
              elevation: 8,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: _buildSearchResultsList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResultsList() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CustomLoadingIndicator(size: 24)),
      );
    }
    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            context.tr('location.no_results'),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: Colors.grey.shade100,
        indent: 56,
      ),
      itemBuilder: (_, index) {
        final place = _searchResults[index];
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.mapPin,
              size: 20,
              color: Colors.grey.shade600,
            ),
          ),
          title: Text(
            place.name,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            place.displayName,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _selectSearchResult(place),
        );
      },
    );
  }

  Widget _buildBottomPanel() {
    final address = _selectedPlace?.displayName ??
        (_isGeocoding
            ? context.tr('location.detecting')
            : context.tr('location.map_picker_hint'));

    final canConfirm =
        !_isMapMoving && !_isGeocoding && !_isSaving && _selectedPosition != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('location.map_picker_hint'),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isGeocoding && !_isMapMoving)
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomLoadingIndicator(size: 18),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    PhosphorIconsFill.mapPin,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              Expanded(
                child: Text(
                  address,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryGradientButton(
            onPressed: canConfirm ? _confirm : null,
            isLoading: _isGeocoding && !_isMapMoving,
            child: Text(
              context.tr('location.confirm_location'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
