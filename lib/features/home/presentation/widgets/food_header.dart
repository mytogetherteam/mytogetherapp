import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../auth/data/models/user_location_model.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_search_service.dart';
import '../../../../core/location/location_display_util.dart';
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
  UserLocationModel? _displayLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _syncDisplayLocation();
    UserLocationRepository.instance.addListener(_syncDisplayLocation);
  }

  @override
  void dispose() {
    UserLocationRepository.instance.removeListener(_syncDisplayLocation);
    super.dispose();
  }

  /// Header always reflects [UserLocationRepository.activeLocation] first so
  /// a session "Current location" selection is not overwritten by saved names.
  Future<void> _syncDisplayLocation() async {
    if (!mounted) return;

    final active = UserLocationRepository.instance.activeLocation;
    if (active != null) {
      setState(() {
        _displayLocation = active;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final loc = await UserLocationRepository.instance
          .getPrimaryLocation()
          .timeout(const Duration(seconds: 8));
      if (loc != null && mounted) {
        UserLocationRepository.instance.setActiveLocation(loc);
        setState(() {
          _displayLocation = loc;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    await _fallbackToCurrentLocation();
  }

  Future<void> _fallbackToCurrentLocation() async {
    try {
      final pos = await LocationService().getCurrentPosition(
        requestPermissionIfDenied: false,
        forceRefresh: true,
        highAccuracy: true,
      ).timeout(const Duration(seconds: 15));
      if (!LocationService().hasRealPosition) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final place = await LocationSearchService.instance
          .reverseGeocode(pos.latitude, pos.longitude)
          .timeout(const Duration(seconds: 8));

      if (place != null && mounted) {
        final sessionLoc = UserLocationModel(
          id: -1,
          latitude: place.lat,
          longitude: place.lon,
          locationName: context.tr('location.current'),
          address: place.displayName,
          locationType: 'OTHER',
          isPrimary: true,
        );
        setState(() {
          _displayLocation = sessionLoc;
          _isLoading = false;
        });
        UserLocationRepository.instance.setActiveLocation(sessionLoc);
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _headerLabel(BuildContext context) {
    if (_displayLocation == null) {
      return context.tr('food.set_location');
    }
    if (UserLocationRepository.instance.isSessionCurrentLocation) {
      return context.tr('location.current');
    }
    final compact = LocationDisplayUtil.compactAddress(
      _displayLocation!.streetAddress ?? _displayLocation!.address,
    );
    return compact.isNotEmpty ? compact : context.tr('food.my_location');
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
                                      _headerLabel(context),
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
                                  const Icon(
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
                            MaterialPageRoute(
                              builder: (_) => const FoodSearchPage(),
                            ),
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
        onLocationSelected: (_) {
          if (mounted) {
            _syncDisplayLocation();
          }
          widget.onLocationChanged?.call();
        },
      ),
    );
  }
}
