import 'dart:async';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_search_service.dart';
import '../../../auth/data/models/user_location_model.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../widgets/location_skeleton_loader.dart';
import '../widgets/location_details_sheet.dart';
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

  bool get _isAtLocationLimit =>
      UserLocationRepository.instance.isAtLocationLimit(_apiLocations);

  void _showLocationLimitSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('location.limit_message')),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

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
    _searchFocus.requestFocus();
    _loadCurrentLocation();
    _loadApiLocations();
    UserLocationRepository.instance.addListener(_loadApiLocations);
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final pos = await LocationService().getCurrentPosition();
      final result = await LocationSearchService.instance.reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentLocationResult = result;
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
      final lat = LocationService().lat;
      final lon = LocationService().lon;
      final results = await LocationSearchService.instance.searchPlaces(query, lat: lat, lon: lon);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _saveNewLocation(PlaceResult place) async {
    if (_isProcessingApi) return;
    if (_isAtLocationLimit) {
      _showLocationLimitSnack();
      return;
    }

    try {
      setState(() => _isProcessingApi = true);
      // Get details (lat/lon) if missing
      final fullPlace = (place.lat == 0 || place.lon == 0) 
          ? await LocationSearchService.instance.getPlaceDetails(place)
          : place;
      
      setState(() => _isProcessingApi = false);

      if (fullPlace == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('location.place_details_failed')), backgroundColor: Colors.red),
        );
        return;
      }

      if (!mounted) return;

      final initialModel = UserLocationModel(
        id: 0,
        latitude: fullPlace!.lat,
        longitude: fullPlace.lon,
        locationName: fullPlace.name,
        address: fullPlace.displayName,
        locationType: 'OTHER',
        isPrimary: true,
      );

      // Open details sheet before saving
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => LocationDetailsSheet(
          location: initialModel,
          onSave: (UserLocationModel finalModel) async {
            setState(() => _isProcessingApi = true);
            try {
              await UserLocationRepository.instance.addLocation(finalModel);
              _hasChanges = true;
              if (mounted) {
                _searchController.clear();
                setState(() => _searchResults = []);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('location.saved_success')), backgroundColor: AppColors.primary),
                );
              }
            } catch (e) {
              if (!mounted) return;
              _showLocationErrorSnack(
                e,
                context.tr('location.save_failed'),
              );
            } finally {
              if (mounted) setState(() => _isProcessingApi = false);
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingApi = false);
        _showLocationErrorSnack(e, context.tr('location.load_place_failed'));
      }
    }
  }

  /// Opens the location form in "create" mode without requiring the user to
  /// first pick a place from search. Seeds coordinates from the detected
  /// current location / last known GPS fix when available so the saved
  /// location still has usable coordinates.
  void _createNewLocation() {
    if (_isAtLocationLimit) {
      _showLocationLimitSnack();
      return;
    }

    final current = _currentLocationResult;
    final initialModel = UserLocationModel(
      id: 0,
      latitude: current?.lat ?? LocationService().lat,
      longitude: current?.lon ?? LocationService().lon,
      locationName: null,
      address: current?.displayName,
      locationType: 'OTHER',
      // First-ever location becomes the primary one.
      isPrimary: _apiLocations.isEmpty,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationDetailsSheet(
        location: initialModel,
        onSave: (UserLocationModel finalModel) async {
          setState(() => _isProcessingApi = true);
          try {
            await UserLocationRepository.instance.addLocation(finalModel);
            _hasChanges = true;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('location.created_success')), backgroundColor: AppColors.primary),
              );
            }
          } catch (e) {
            if (!mounted) return;
            _showLocationErrorSnack(
              e,
              context.tr('location.create_failed'),
            );
          } finally {
            if (mounted) setState(() => _isProcessingApi = false);
          }
        },
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
            _buildSearchBar(),
            Expanded(
              child: Stack(
                children: [
                  _searchController.text.trim().isNotEmpty
                      ? _buildSearchResults()
                      : _buildMainList(),
                      
                  if (_isProcessingApi)
                    Container(
                      color: Colors.white.withValues(alpha: 0.6),
                      child: const Center(
                        child: CustomLoadingIndicator(size: 30),
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
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr('location.saved_locations'),
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
          ),
          if (_isAtLocationLimit)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                context.trArgs('location.saved_count', {'current': '3', 'max': '3'}),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _createNewLocation,
              icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
              label: Text(
                context.tr('location.add_new_short'),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                  Text(
                    _isLoadingCurrent ? context.tr('location.detecting') : (_currentLocationResult?.displayName ?? context.tr('location.unavailable')),
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                          location.locationName ?? context.tr('location.saved'),
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                          maxLines: 1,
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
                  Text(
                    location.address ?? '',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
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
    return InkWell(
      onTap: () => _saveNewLocation(place),
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
            const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
