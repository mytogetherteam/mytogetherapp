import 'dart:async';
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
    
    try {
      setState(() => _isProcessingApi = true);
      // Get details (lat/lon) if missing
      final fullPlace = (place.lat == 0 || place.lon == 0) 
          ? await LocationSearchService.instance.getPlaceDetails(place)
          : place;
      
      setState(() => _isProcessingApi = false);

      if (fullPlace == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get place details'), backgroundColor: Colors.red),
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
                  const SnackBar(content: Text('Location saved successfully'), backgroundColor: AppColors.primary),
                );
              }
            } catch (e) {
               if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving location: $e'), backgroundColor: Colors.red),
                );
              }
            } finally {
              if (mounted) setState(() => _isProcessingApi = false);
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingApi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
          const SnackBar(content: Text('Location updated successfully'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating location: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingApi = false);
    }
  }

  Future<void> _deleteLocation(UserLocationModel location) async {
    if (location.isPrimary) {
      AppDialog.show(
        context: context,
        title: 'Cannot Delete',
        content: 'You cannot delete your primary location. Please set another location as primary first.',
        buttonText: 'OK',
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
          const SnackBar(content: Text('Location deleted successfully'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting location: $e'), backgroundColor: Colors.red),
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
                  hintText: 'Search for a location...',
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
        _buildHeader('Saved Locations'),
        if (_isLoadingApi)
          const LocationSkeletonLoader(isList: true, itemCount: 4)
        else if (_apiLocations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('No saved locations', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade400)),
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
      return Center(child: Text('No results found', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade400)));
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

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
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
                  Text('Current location', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(
                    _isLoadingCurrent ? 'Detecting...' : (_currentLocationResult?.displayName ?? 'Location unavailable'),
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
        final place = PlaceResult(
          placeId: location.id.toString(),
          name: location.locationName ?? location.address ?? 'Saved Location',
          displayName: location.address ?? '',
          lat: location.latitude ?? 0,
          lon: location.longitude ?? 0,
        );
        Navigator.pop(context, place);
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
                          location.locationName ?? 'Saved Location',
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
                            'Selected',
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
                const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
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
