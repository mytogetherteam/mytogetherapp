import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/config/google_maps_config.dart';
import '../../../../core/location/location_search_service.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../auth/data/models/user_location_model.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../auth/data/session_location_store.dart';
import '../widgets/location_details_sheet.dart';
import '../widgets/map_picker_address_panel.dart';
import '../widgets/map_pin_geocode_controller.dart';
import '../widgets/pinned_map_view.dart';

/// Unified map + search + pin screen for adding a delivery location.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final GlobalKey<PinnedMapViewState> _mapKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late final MapPinGeocodeController _geocode;

  Timer? _searchDebounce;
  LatLng? _selectedPosition;
  List<PlaceResult> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingInitial = true;
  bool _showMap = false;
  bool _isSaving = false;
  bool _showSearchResults = false;

  static const _pinLift = 36.0;

  @override
  void initState() {
    super.initState();
    _geocode = MapPinGeocodeController(
      addressController: TextEditingController(),
    );
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
    _searchDebounce?.cancel();
    _searchController.dispose();
    _geocode.addressController.dispose();
    _geocode.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _resolveInitialPosition() async {
    double? lat;
    double? lon;

    try {
      final pos = await LocationService().getCurrentPosition(
        requestPermissionIfDenied: true,
        forceRefresh: false,
        highAccuracy: false,
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

    final resolvedLat = lat ?? LocationService.defaultLat;
    final resolvedLon = lon ?? LocationService.defaultLon;
    if (!mounted) return;
    final position = LatLng(resolvedLat, resolvedLon);
    setState(() {
      _selectedPosition = position;
      _isLoadingInitial = false;
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showMap = true);
    });
    await _geocode.prefillFromCache(resolvedLat, resolvedLon);
    if (_geocode.addressController.text.trim().isEmpty) {
      await _geocode.lookupInitialPosition(position);
    }
  }

  void _onPinDropped(LatLng target) {
    _selectedPosition = target;
    _geocode.onPinDropped(target);
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
      final results = await LocationSearchService.instance.searchPlaces(
        trimmed,
        lat: _selectedPosition?.latitude,
        lon: _selectedPosition?.longitude,
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
    });

    PlaceResult resolved = place;
    if (place.lat == 0 && place.lon == 0) {
      final details =
          await LocationSearchService.instance.getPlaceDetails(place);
      if (details != null) resolved = details;
    }

    if (resolved.lat == 0 && resolved.lon == 0) return;

    final target = LatLng(resolved.lat, resolved.lon);
    await _mapKey.currentState?.animateTo(target);

    if (!mounted) return;
    setState(() => _selectedPosition = target);

    if (resolved.displayName.trim().isNotEmpty) {
      _geocode.applySearchResult(resolved);
    } else {
      await _geocode.reverseGeocodeNow(target);
    }
    _searchController.text = resolved.name;
  }

  Future<void> _goToMyLocation() async {
    try {
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
      await _mapKey.currentState?.animateTo(target);
      if (mounted) {
        _selectedPosition = target;
        await _geocode.reverseGeocodeNow(target);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('location.unavailable'))),
      );
    }
  }

  Future<void> _confirm() async {
    if (_geocode.isMapMoving || _isSaving || _selectedPosition == null) return;

    final address = _geocode.addressController.text.trim();
    if (address.isEmpty) {
      _geocode.setAddressRequiredError(
        context.tr('location.street_address_required'),
      );
      return;
    }

    final pos = _selectedPosition!;
    await SessionLocationStore.save(
      latitude: pos.latitude,
      longitude: pos.longitude,
      address: address,
    );

    if (!mounted) return;

    final draft = UserLocationModel(
      id: 0,
      latitude: pos.latitude,
      longitude: pos.longitude,
      locationName: null,
      address: address,
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
                      child: _showMap
                          ? PinnedMapView(
                              key: _mapKey,
                              initialPosition: _selectedPosition!,
                              mapPadding: const EdgeInsets.only(
                                top: 72,
                                bottom: _pinLift,
                              ),
                              onGoToMyLocation: _goToMyLocation,
                              onCameraMoveStarted: _geocode.onCameraMoveStarted,
                              onPinDropped: _onPinDropped,
                            )
                          : const ColoredBox(
                              color: Color(0xFFF1F5F9),
                              child: Center(
                                child: CustomLoadingIndicator(size: 28),
                              ),
                            ),
                    ),
                    ListenableBuilder(
                      listenable: _geocode,
                      builder: (context, _) => MapPickerAddressPanel(
                        addressController: _geocode.addressController,
                        isGeocoding: _geocode.isGeocoding,
                        isMapMoving: _geocode.isMapMoving,
                        isSaving: _isSaving,
                        canConfirmBase: _selectedPosition != null,
                        addressError: _geocode.addressError,
                        onAddressChanged: _geocode.onAddressEdited,
                        onConfirm: _confirm,
                      ),
                    ),
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
}
