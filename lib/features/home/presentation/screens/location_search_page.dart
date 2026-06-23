import 'dart:async';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/google_maps_config.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_search_service.dart';
import '../../../../core/location/location_display_util.dart';
import '../../../auth/data/models/user_location_model.dart';
import '../../../../core/auth/guest_auth_guard.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../auth/data/session_location_store.dart';
import '../widgets/location_skeleton_loader.dart';
import '../widgets/location_address_display.dart';
import '../widgets/location_details_sheet.dart';
import 'location_picker_page.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';

class LocationSearchPage extends StatefulWidget {
  const LocationSearchPage({super.key});

  @override
  State<LocationSearchPage> createState() => _LocationSearchPageState();
}

class _LocationSearchPageState extends State<LocationSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  List<PlaceResult> _searchResults = [];
  PlaceResult? _currentLocationResult;
  List<UserLocationModel> _apiLocations = [];
  bool _isSearching = false;
  bool _isLoadingCurrent = true;
  bool _isLoadingApi = true;
  bool _isProcessingApi = false;
  bool _hasChanges = false;
  double? _currentLat;
  double? _currentLon;

  bool get _isAtLocationLimit =>
      UserLocationRepository.instance.isAtLocationLimit(_apiLocations);

  void _showLocationErrorSnack(Object error, String fallback) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          UserLocationRepository.errorMessage(error, fallback: fallback),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (GuestAuthGuard.isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await GuestAuthGuard.requireAccount(context);
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return;
    }
    if (GoogleMapsConfig.placesSearchEnabled) {
      _searchFocus.requestFocus();
    }
    _loadCurrentLocation();
    _loadApiLocations();
    UserLocationRepository.instance.addListener(_loadApiLocations);
  }

  Future<void> _loadCurrentLocation() async {
    try {
      LocationService().clearCache();
      final pos = await LocationService().getCurrentPosition(
        requestPermissionIfDenied: true,
        forceRefresh: true,
        highAccuracy: !kIsWeb,
      );
      if (LocationService().hasRealPosition) {
        _currentLat = pos.latitude;
        _currentLon = pos.longitude;
      }
      final result = LocationService().hasRealPosition
          ? await LocationSearchService.instance
              .reverseGeocode(pos.latitude, pos.longitude)
          : null;
      final storedAddress = LocationService().hasRealPosition
          ? await SessionLocationStore.addressNear(pos.latitude, pos.longitude)
          : null;
      final resolvedAddress = LocationDisplayUtil.firstReadableAddress([
        result?.displayName,
        LocationService().currentAddress,
        storedAddress,
      ]);
      if (mounted) {
        setState(() {
          _currentLocationResult = LocationService().hasRealPosition
              ? PlaceResult(
                  placeId: result?.placeId ?? '',
                  name: result?.name ?? context.tr('location.current'),
                  displayName: resolvedAddress ?? '',
                  lat: result?.lat ?? pos.latitude,
                  lon: result?.lon ?? pos.longitude,
                )
              : null;
          _isLoadingCurrent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCurrent = false);
    }
  }

  Future<void> _loadApiLocations() async {
    if (!mounted) return;
    setState(() => _isLoadingApi = true);
    try {
      final locs = await UserLocationRepository.instance.getRawLocations();
      if (mounted) {
        setState(() {
          _apiLocations = locs;
          _isLoadingApi = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingApi = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final lat = _currentLat ??
          (LocationService().hasRealPosition ? LocationService().lat : null);
      final lon = _currentLon ??
          (LocationService().hasRealPosition ? LocationService().lon : null);
      final savedMatches = _matchSavedLocations(query);
      final googleResults =
          await LocationSearchService.instance.searchPlaces(query, lat: lat, lon: lon);
      if (mounted) {
        setState(() {
          _searchResults = _mergeSearchResults(savedMatches, googleResults);
          _isSearching = false;
        });
      }
    });
  }

  List<PlaceResult> _matchSavedLocations(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    return _apiLocations
        .where((loc) {
          final addr = (loc.streetAddress ?? '').toLowerCase();
          return addr.contains(q);
        })
        .map(
          (loc) => PlaceResult(
            placeId: 'saved-${loc.id}',
            name: loc.displayTitle(context.tr('location.saved')),
            displayName: loc.streetAddress ?? '',
            lat: loc.latitude ?? 0,
            lon: loc.longitude ?? 0,
          ),
        )
        .toList();
  }

  List<PlaceResult> _mergeSearchResults(
    List<PlaceResult> saved,
    List<PlaceResult> google,
  ) {
    if (saved.isEmpty) return google;
    final savedIds = saved.map((p) => p.placeId).toSet();
    final merged = [...saved];
    for (final place in google) {
      if (!savedIds.contains(place.placeId)) {
        merged.add(place);
      }
    }
    return merged;
  }

  Future<void> _confirmNewPlace(PlaceResult place) async {
    if (_isProcessingApi) return;

    if (_isAtLocationLimit) {
      _showLimitSnack();
      return;
    }

    try {
      setState(() => _isProcessingApi = true);
      final fullPlace = (place.lat == 0 || place.lon == 0)
          ? await LocationSearchService.instance.getPlaceDetails(place)
          : place;

      if (fullPlace == null || (fullPlace.lat == 0 && fullPlace.lon == 0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('location.place_details_failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      final draft = UserLocationModel(
        id: 0,
        latitude: fullPlace.lat,
        longitude: fullPlace.lon,
        address: fullPlace.displayName,
        locationType: 'OTHER',
        isPrimary: true,
      );

      setState(() => _isProcessingApi = false);

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => LocationDetailsSheet(
          location: draft,
          isEdit: false,
          onSave: (updated) => _persistNewLocation(updated),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showLocationErrorSnack(e, context.tr('location.save_failed'));
      }
    } finally {
      if (mounted) setState(() => _isProcessingApi = false);
    }
  }

  Future<void> _persistNewLocation(UserLocationModel model) async {
    if (_isProcessingApi) return;

    try {
      setState(() => _isProcessingApi = true);
      final saved = await UserLocationRepository.instance.addLocation(model);
      UserLocationRepository.instance.setActiveLocation(saved);
      _hasChanges = true;
      if (mounted) {
        _searchController.clear();
        setState(() => _searchResults = []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('location.saved_success')),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showLocationErrorSnack(e, context.tr('location.save_failed'));
      }
    } finally {
      if (mounted) setState(() => _isProcessingApi = false);
    }
  }

  Future<void> _openMapPicker() async {
    if (_isAtLocationLimit) {
      _showLimitSnack();
      return;
    }
    if (_isProcessingApi) return;

    final saved = await Navigator.push<UserLocationModel>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );

    if (saved != null && mounted) {
      _hasChanges = true;
      await _loadApiLocations();
    }
  }

  void _showLimitSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('location.limit_full_hint')),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _updateLocation(UserLocationModel location, {bool? setPrimary, UserLocationModel? fullUpdate}) async {
    if (_isProcessingApi) return;
    setState(() => _isProcessingApi = true);

    try {
      final modelToSave = fullUpdate ?? location.copyWith(isPrimary: setPrimary);
      await UserLocationRepository.instance.updateLocation(modelToSave);
      _hasChanges = true;
      if (mounted && fullUpdate != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('location.updated_success')), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showLocationErrorSnack(
        e,
        context.tr('location.update_failed'),
      );
    } finally {
      if (mounted) setState(() => _isProcessingApi = false);
    }
  }

  Future<void> _deleteLocation(UserLocationModel location) async {
    if (location.isPrimary) {
      AppDialog.show(
        context: context,
        title: context.tr('location.cannot_delete'),
        content: context.tr('location.cannot_delete_primary'),
        buttonText: context.tr('common.confirm'),
      );
      return;
    }

    if (_isProcessingApi) return;
    setState(() => _isProcessingApi = true);

    try {
      await UserLocationRepository.instance.deleteLocation(location.id);
      _hasChanges = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('location.deleted_success')), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.trArgs('location.delete_error', {'error': '$e'})), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingApi = false);
    }
  }

  @override
  void dispose() {
    UserLocationRepository.instance.removeListener(_loadApiLocations);
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Stack(
                children: [
                  GoogleMapsConfig.placesSearchEnabled &&
                          _searchController.text.trim().isNotEmpty
                      ? _buildSearchResults()
                      : _buildMainList(),
                      
                  if (_isProcessingApi)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: AppColors.primary,
                        backgroundColor: Color(0xFFF1F5F9),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    if (!GoogleMapsConfig.placesSearchEnabled) {
      return Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context, _hasChanges),
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsFill.mapPin,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('location.saved_locations'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _buildSearchBar();
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context, _hasChanges),
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(PhosphorIconsFill.mapPin, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: context.tr('location.search_hint'),
                  hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainList() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildCurrentLocationTile(),
        _buildSavedLocationsHeader(),
        if (_isLoadingApi)
          const LocationSkeletonLoader(isList: true, itemCount: 4)
        else if (_apiLocations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(context.tr('location.no_saved'), style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade400)),
            ),
          )
        else
          ..._apiLocations.map((loc) => _buildApiLocationTile(loc)),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CustomLoadingIndicator(size: 30));
    }
    if (_searchResults.isEmpty) {
      return Center(child: Text(context.tr('location.no_results'), style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade400)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100, indent: 72, endIndent: 16),
      itemBuilder: (context, index) {
        final place = _searchResults[index];
        return _buildPlaceTile(place);
      },
    );
  }

  Widget _buildSavedLocationsHeader() {
    final count = _apiLocations.length;
    final max = UserLocationRepository.maxSavedLocations;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('location.saved_locations'),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              Text(
                context.trArgs(
                  'location.slots_used',
                  {'current': '$count', 'max': '$max'},
                ),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _isAtLocationLimit
                      ? Colors.orange.shade800
                      : Colors.grey.shade500,
                ),
              ),
            ],
          ),
          if (_isAtLocationLimit) ...[
            const SizedBox(height: 10),
            _buildLimitBanner(),
          ] else ...[
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isProcessingApi ? null : _openMapPicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                    color: AppColors.primary.withValues(alpha: 0.06),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        PhosphorIconsFill.mapPinPlus,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('location.add_new_short'),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLimitBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.orange.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('location.limit_full_hint'),
              style: GoogleFonts.poppins(
                fontSize: 12,
                height: 1.45,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationTile() {
    return InkWell(
      onTap: _currentLocationResult != null 
          ? () => Navigator.pop(context, _currentLocationResult) 
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: Icon(PhosphorIcons.crosshairSimple, size: 22, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('location.current'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 2),
                  _isLoadingCurrent
                      ? Text(
                          context.tr('location.detecting'),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        )
                      : _currentLocationResult == null
                          ? Text(
                              context.tr('location.unavailable'),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            )
                          : LocationDisplayUtil.readableAddress(
                                  _currentLocationResult?.displayName,
                                ) ==
                                null
                              ? Text(
                                  context.tr('location.pin_to_add_address'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                )
                              : LocationAddressDisplay(
                                  address: _currentLocationResult?.displayName,
                                  latitude: _currentLocationResult?.lat,
                                  longitude: _currentLocationResult?.lon,
                                  showCoordinates: false,
                                  addressMaxLines: 3,
                                ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiLocationTile(UserLocationModel location) {
    return InkWell(
      onTap: () {
        // Selecting a saved location marks it as the active/primary location
        // in place. We intentionally don't pop here — only the back button
        // returns to the previous screen.
        UserLocationRepository.instance.setActiveLocation(location);
        if (!location.isPrimary) {
          _updateLocation(location, setPrimary: true);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: location.isPrimary ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                location.locationType == 'HOME' ? PhosphorIcons.house : location.locationType == 'WORK' ? PhosphorIcons.briefcase : PhosphorIcons.mapPin,
                size: 18,
                color: location.isPrimary ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          location.displayTitle(context.tr('location.saved')),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (location.isPrimary)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.tr('location.selected'),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (location.detailSubtitle != null)
                    Text(
                      location.detailSubtitle!,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: Colors.white,
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: Icon(PhosphorIcons.dotsThreeVertical, size: 22, color: Colors.grey.shade500),
              onSelected: (val) {
                if (val == 'primary') _updateLocation(location, setPrimary: true);
                if (val == 'edit') {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => LocationDetailsSheet(
                      location: location,
                      isEdit: true,
                      onSave: (UserLocationModel updated) => _updateLocation(location, fullUpdate: updated),
                    ),
                  );
                }
                if (val == 'delete') _deleteLocation(location);
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'edit', child: Text(context.tr('location.edit_details'))),
                PopupMenuItem(value: 'delete', child: Text(context.tr('common.delete'), style: const TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceTile(PlaceResult place) {
    final isSaved = place.placeId.startsWith('saved-');
    return InkWell(
      onTap: () {
        if (isSaved) {
          final id = int.tryParse(place.placeId.replaceFirst('saved-', ''));
          final loc = id != null
              ? _apiLocations.where((l) => l.id == id).firstOrNull
              : null;
          if (loc != null) {
            UserLocationRepository.instance.setActiveLocation(loc);
            if (!loc.isPrimary) {
              _updateLocation(loc, setPrimary: true);
            }
          }
          return;
        }
        _confirmNewPlace(place);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: Icon(PhosphorIcons.mapPin, size: 22, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(place.displayName, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(
              isSaved ? PhosphorIcons.checkCircle : Icons.add_circle_outline,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
