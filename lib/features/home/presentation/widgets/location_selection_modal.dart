import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_search_service.dart';
import '../../../../core/location/location_display_util.dart';
import '../../../auth/data/models/user_location_model.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../auth/data/session_location_store.dart';
import '../screens/location_search_page.dart';
import 'location_address_display.dart';
import 'location_skeleton_loader.dart';

class LocationSelectionModal extends StatefulWidget {
  final Function(PlaceResult)? onLocationSelected;

  const LocationSelectionModal({super.key, this.onLocationSelected});

  @override
  State<LocationSelectionModal> createState() => _LocationSelectionModalState();
}

class _LocationSelectionModalState extends State<LocationSelectionModal> {
  PlaceResult? _currentLocationResult;
  bool _isLoadingCurrent = true;
  bool _hasPreciseGps = false;
  List<UserLocationModel> _apiLocations = [];
  bool _isLoadingApi = true;
  bool _isProcessing = false;

  int get _savedCount =>
      UserLocationRepository.instance.countSavedLocations(_apiLocations);

  bool get _isAtLocationLimit =>
      UserLocationRepository.instance.isAtLocationLimit(_apiLocations);

  @override
  void initState() {
    super.initState();
    _hydrateFromActiveLocation();
    _loadCurrentLocation();
    _loadApiLocations();
    UserLocationRepository.instance.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    UserLocationRepository.instance.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (!mounted) return;
    _hydrateFromActiveLocation();
    setState(() {});
  }

  void _hydrateFromActiveLocation() {
    final active = UserLocationRepository.instance.activeLocation;
    if (!UserLocationRepository.instance.isSessionCurrentLocation ||
        active?.latitude == null ||
        active?.longitude == null) {
      return;
    }
    final resolved = active!;
    _currentLocationResult = PlaceResult(
      placeId: '',
      name: context.tr('location.current'),
      displayName: LocationDisplayUtil.firstReadableAddress([
            resolved.address,
            resolved.addressTh,
            resolved.locationName,
          ]) ??
          '',
      lat: resolved.latitude!,
      lon: resolved.longitude!,
    );
    _hasPreciseGps = true;
    _isLoadingCurrent = false;
  }

  bool _isGpsUsable(Position pos) {
    if (!LocationService().hasRealPosition) return false;
    // Web/browser GPS often reports coarse accuracy; still usable for delivery.
    if (kIsWeb) return true;
    return pos.accuracy <= 0 || pos.accuracy <= 100;
  }

  Future<void> _loadCurrentLocation() async {
    try {
      LocationService().clearCache();
      final pos = await LocationService().getCurrentPosition(
        requestPermissionIfDenied: true,
        forceRefresh: true,
        highAccuracy: !kIsWeb,
      );
      if (!_isGpsUsable(pos)) {
        if (mounted) {
          setState(() {
            _hasPreciseGps = false;
            _isLoadingCurrent = false;
          });
        }
        return;
      }
      final result = await LocationSearchService.instance.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );
      final storedAddress = await SessionLocationStore.addressNear(
        pos.latitude,
        pos.longitude,
      );
      final resolvedAddress = LocationDisplayUtil.firstReadableAddress([
        result?.displayName,
        LocationService().currentAddress,
        storedAddress,
      ]);
      if (mounted) {
        setState(() {
          _currentLocationResult = PlaceResult(
            placeId: result?.placeId ?? '',
            name: result?.name ?? context.tr('location.current'),
            displayName: resolvedAddress ?? '',
            lat: result?.lat ?? pos.latitude,
            lon: result?.lon ?? pos.longitude,
          );
          _hasPreciseGps = true;
          _isLoadingCurrent = false;
        });
      }
    } catch (e) {
      debugPrint('CURRENT LOCATION ERROR: $e');
      if (mounted) {
        setState(() {
          _hasPreciseGps = false;
          _isLoadingCurrent = false;
        });
      }
    }
  }

  Future<void> _loadApiLocations() async {
    if (!mounted) return;
    setState(() => _isLoadingApi = true);
    try {
      final locs = await UserLocationRepository.instance.getRawLocations();
      if (mounted) {
        // Sort so primary is always first
        locs.sort(
          (a, b) => (b.isPrimary ? 1 : 0).compareTo(a.isPrimary ? 1 : 0),
        );
        setState(() {
          _apiLocations = locs;
          _isLoadingApi = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingApi = false);
    }
  }

  /// Opens the saved-addresses page (search, manage, add via map picker).
  Future<void> _onViewAddresses() async {
    if (!mounted || _isProcessing) return;

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);
    await rootNavigator.push<bool>(
      MaterialPageRoute(builder: (_) => const LocationSearchPage()),
    );
  }

  void _selectCurrentLocation() {
    final place = _currentLocationResult;
    if (!_hasPreciseGps || place == null) return;

    final sessionLocation = UserLocationModel(
      id: -1,
      latitude: place.lat,
      longitude: place.lon,
      locationName: context.tr('location.current'),
      address: place.displayName,
      locationType: 'OTHER',
      isPrimary: true,
    );
    if (place.displayName.trim().isNotEmpty) {
      SessionLocationStore.save(
        latitude: place.lat,
        longitude: place.lon,
        address: place.displayName.trim(),
      );
    }
    UserLocationRepository.instance.setActiveLocation(sessionLocation);
    setState(() {});
    widget.onLocationSelected?.call(place);
    Navigator.pop(context);
  }

  Future<void> _handleSelectionChange(
    PlaceResult place, {
    int? existingId,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (existingId != null) {
        final existing = _apiLocations.firstWhere((l) => l.id == existingId);
        UserLocationRepository.instance.setActiveLocation(
          existing.copyWith(isPrimary: true),
        );
        if (!existing.isPrimary) {
          await UserLocationRepository.instance.updateLocation(
            existing.copyWith(isPrimary: true),
          );
        }
      } else {
        // Try to find by address first
        final match = _apiLocations
            .where((l) => l.address == place.displayName)
            .firstOrNull;
        if (match != null) {
          UserLocationRepository.instance.setActiveLocation(
            match.copyWith(isPrimary: true),
          );
          if (!match.isPrimary) {
            await UserLocationRepository.instance.updateLocation(
              match.copyWith(isPrimary: true),
            );
          }
        } else {
          if (UserLocationRepository.instance.isAtLocationLimit(_apiLocations)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('location.limit_message')),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return;
          }
          // New locations must go through the picker + details form.
          return;
        }
      }

      if (mounted) {
        widget.onLocationSelected?.call(place);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              UserLocationRepository.errorMessage(
                e,
                fallback: context.tr('location.update_failed'),
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.7),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Non-scrollable Title part
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      context.tr('location.select_title'),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey.shade500,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: Colors.grey.shade100),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Current Location
                      _buildCurrentLocationTile(),
                      Divider(
                        height: 1,
                        color: Colors.grey.shade100,
                        indent: 20,
                        endIndent: 20,
                      ),

                      // API locations
                      if (_isLoadingApi)
                        const LocationSkeletonLoader(isList: true, itemCount: 2)
                      else if (_apiLocations.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Row(
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
                                  {
                                    'current': '$_savedCount',
                                    'max':
                                        '${UserLocationRepository.maxSavedLocations}',
                                  },
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
                        ),
                        ..._apiLocations.map(
                          (loc) => _buildSavedLocationTile(loc),
                        ),
                        Divider(
                          height: 1,
                          color: Colors.grey.shade100,
                          indent: 20,
                          endIndent: 20,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Fixed footer — outside the scroll view so taps are never blocked.
              Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isProcessing ? null : _onViewAddresses,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            PhosphorIcons.mapPin,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('location.view_addresses'),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: const Center(child: CustomLoadingIndicator(size: 30)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationTile() {
    final canSelect = _hasPreciseGps && _currentLocationResult != null;
    final isSelected = UserLocationRepository.instance.isSessionCurrentLocation;
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: canSelect ? _selectCurrentLocation : null,
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.primary, width: 3),
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.crosshairSimple,
                size: 22,
                color: isSelected ? AppColors.primary : Colors.grey.shade700,
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
                          context.tr('location.current'),
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
                  const SizedBox(height: 2),
                  if (_isLoadingCurrent)
                    Text(
                      context.tr('location.detecting'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    )
                  else if (_currentLocationResult == null)
                    Text(
                      context.tr('location.unavailable_short'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    )
                  else if (LocationDisplayUtil.readableAddress(
                        _currentLocationResult?.displayName,
                      ) ==
                      null)
                    Text(
                      context.tr('location.pin_to_add_address'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        height: 1.4,
                      ),
                      maxLines: 3,
                    )
                  else
                    LocationAddressDisplay(
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
    ),
    );
  }

  bool _isSavedLocationSelected(UserLocationModel location) {
    if (UserLocationRepository.instance.isSessionCurrentLocation) {
      return false;
    }
    final active = UserLocationRepository.instance.activeLocation;
    if (active != null && active.id > 0) {
      return active.id == location.id;
    }
    if (active != null && active.id <= 0) {
      return false;
    }
    return location.isPrimary;
  }

  Widget _buildSavedLocationTile(UserLocationModel location) {
    final isSelected = _isSavedLocationSelected(location);
    return InkWell(
      onTap: () async {
        final place = PlaceResult(
          placeId: location.id.toString(),
          name: location.locationName ?? location.address ?? context.tr('location.saved'),
          displayName: location.address ?? location.addressTh ?? '',
          lat: location.latitude ?? 0,
          lon: location.longitude ?? 0,
        );
        _handleSelectionChange(place, existingId: location.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getLocationIcon(location.locationType),
                size: 22,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
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
                          location.locationName ??
                              location.locationType ??
                              context.tr('location.saved'),
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (LocationDisplayUtil.readableAddress(location.address) !=
                      null)
                    Text(
                      location.address!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
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

  IconData _getLocationIcon(String? type) {
    switch (type?.toUpperCase()) {
      case 'HOME':
        return PhosphorIcons.house;
      case 'WORK':
      case 'OFFICE':
        return PhosphorIcons.briefcase;
      default:
        return PhosphorIcons.mapPin;
    }
  }
}
