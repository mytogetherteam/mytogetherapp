import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../auth/data/models/user_location_model.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_search_service.dart';
import 'location_selection_modal.dart';
import 'location_skeleton_loader.dart';
import '../../../food/presentation/screens/food_search_page.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../../../core/presentation/widgets/notification_bell.dart';

class FoodHeader extends StatefulWidget {
  final VoidCallback? onLocationChanged;
  final bool isScrolled;

  const FoodHeader({super.key, this.onLocationChanged, this.isScrolled = false});

  @override
  State<FoodHeader> createState() => _FoodHeaderState();
}

class _FoodHeaderState extends State<FoodHeader> {
  UserLocationModel? _primaryLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrimaryLocation();
    UserLocationRepository.instance.addListener(_loadPrimaryLocation);
  }

  Future<void> _loadPrimaryLocation() async {
    if (!mounted) return;

    // 1. Try Cache first for instant UI response
    final cachedAddr = LocationService().currentAddress;
    final cachedPos = LocationService().cachedPosition;
    
    if (cachedAddr != null && cachedPos != null) {
      if (mounted) {
        final loc = UserLocationModel(
          id: -1, // Temporary flag for cached
          latitude: cachedPos.latitude,
          longitude: cachedPos.longitude,
          locationName: cachedAddr.split(',').first,
          address: cachedAddr,
          locationType: 'OTHER',
          isPrimary: false,
        );
        setState(() {
          _primaryLocation = loc;
          _isLoading = false;
        });
        UserLocationRepository.instance.setActiveLocation(loc);
      }
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      // We wrap the API call to ensure it doesn't hang the whole process indefinitely
      final loc = await UserLocationRepository.instance.getPrimaryLocation().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Primary location API timeout'),
      );
      
      if (loc != null) {
        if (mounted) {
          setState(() {
            _primaryLocation = loc;
            _isLoading = false;
          });
          UserLocationRepository.instance.setActiveLocation(loc);
        }
        return; // Success, we have the official primary
      }
    } catch (e) {
      // API error or timeout, fall through to GPS fallback
    }

    // 2. If no primary found in API (or API failed), trigger robust fallback
    await _fallbackToCurrentLocation();
  }

  Future<void> _fallbackToCurrentLocation() async {
    try {
      final pos = await LocationService().getCurrentPosition().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('GPS detection timed out'),
      );
      final place = await LocationSearchService.instance.reverseGeocode(pos.latitude, pos.longitude).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Geocoding timed out'),
      );
      
      if (place != null) {
        final newLoc = UserLocationModel(
          id: 0,
          latitude: place.lat,
          longitude: place.lon,
          locationName: place.name,
          address: place.displayName,
          locationType: 'OTHER',
          isPrimary: true,
        );
        
        // Update UI immediately with detected location
        if (mounted) {
          setState(() {
            _primaryLocation = newLoc;
            _isLoading = false;
          });
          UserLocationRepository.instance.setActiveLocation(newLoc);
        }

        try {
          final savedLoc = await UserLocationRepository.instance.addLocation(newLoc).timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Add location API timeout'),
          );
          if (mounted) {
            setState(() => _primaryLocation = savedLoc);
            UserLocationRepository.instance.setActiveLocation(savedLoc);
          }
        } catch (e) {
          // Keep showing the detected location; explain why save failed.
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
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    UserLocationRepository.instance.removeListener(_loadPrimaryLocation);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.fromLTRB(16, statusBarHeight + 2, 16, 8),
      decoration: BoxDecoration(
        color: widget.isScrolled ? null : Colors.transparent,
        gradient: widget.isScrolled ? AppColors.primaryGradient : null,
        boxShadow: widget.isScrolled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Location selector (tappable)
              Expanded(
                child: GestureDetector(
                  onTap: () => _showLocationModal(context),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsFill.mapPin,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isLoading
                          ? const LocationSkeletonLoader()
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _primaryLocation != null
                                        ? (_primaryLocation!.locationName ?? _primaryLocation!.address ?? context.tr('food.my_location'))
                                        : context.tr('food.set_location'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  PhosphorIcons.caretDown,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isScrolled) ...[
                    AnimatedOpacity(
                      opacity: widget.isScrolled ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FoodSearchPage()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            PhosphorIcons.magnifyingGlass,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const NotificationBell(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLocationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationSelectionModal(
        onLocationSelected: (place) {
          _loadPrimaryLocation();
          widget.onLocationChanged?.call();
        },
      ),
    );
  }
}
