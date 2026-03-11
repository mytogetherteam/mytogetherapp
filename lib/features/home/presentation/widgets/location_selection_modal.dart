import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_search_service.dart';
import '../../../auth/data/models/user_location_model.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../screens/location_search_page.dart';
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
  List<UserLocationModel> _apiLocations = [];
  bool _isLoadingApi = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _loadApiLocations();
    UserLocationRepository.instance.addListener(_loadApiLocations);
  }

  @override
  void dispose() {
    UserLocationRepository.instance.removeListener(_loadApiLocations);
    super.dispose();
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
        // Sort so primary is always first
        locs.sort((a, b) => (b.isPrimary ? 1 : 0).compareTo(a.isPrimary ? 1 : 0));
        setState(() {
          _apiLocations = locs;
          _isLoadingApi = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingApi = false);
    }
  }

  Future<void> _handleSelectionChange(PlaceResult place, {int? existingId}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (existingId != null) {
        // Find existing model to preserve data
        final existing = _apiLocations.firstWhere((l) => l.id == existingId);
        if (!existing.isPrimary) {
          await UserLocationRepository.instance.updateLocation(
            existing.copyWith(isPrimary: true),
          );
        }
      } else {
        // Try to find by address first
        final match = _apiLocations.where((l) => l.address == place.displayName).firstOrNull;
        if (match != null) {
          if (!match.isPrimary) {
            await UserLocationRepository.instance.updateLocation(
              match.copyWith(isPrimary: true),
            );
          }
        } else {
          // Add as new primary
          final newLoc = UserLocationModel(
            id: 0,
            latitude: place.lat,
            longitude: place.lon,
            locationName: place.name,
            address: place.displayName,
            locationType: 'OTHER',
            isPrimary: true,
          );
          await UserLocationRepository.instance.addLocation(newLoc);
        }
      }

      if (mounted) {
        widget.onLocationSelected?.call(place);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating location: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.7,
      ),
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
                      'Select Location',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey.shade500, size: 22),
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
                      Divider(height: 1, color: Colors.grey.shade100, indent: 20, endIndent: 20),
        
                      // API locations
                      if (_isLoadingApi)
                        const LocationSkeletonLoader(isList: true, itemCount: 2)
                      else if (_apiLocations.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Saved Locations',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        ..._apiLocations.map((loc) => _buildSavedLocationTile(loc)),
                        Divider(height: 1, color: Colors.grey.shade100, indent: 20, endIndent: 20),
                      ],
        
                      const SizedBox(height: 80), // Extra space for fixed button
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Fixed small pill shape floating button at bottom center
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LocationSearchPage()),
                    );
                    if (result != null && mounted) {
                      if (result is PlaceResult) {
                        _handleSelectionChange(result);
                      } else {
                        Navigator.pop(context);
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFED3973),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFED3973).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIconsFill.mapPinPlus, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Add new location',
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
          ),
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Center(
                  child: CustomLoadingIndicator(size: 30),
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
          ? () => _handleSelectionChange(_currentLocationResult!)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIcons.crosshairSimple(), size: 22, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current location',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (_isLoadingCurrent)
                    Text('Detecting...', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400))
                  else
                    Text(
                      _currentLocationResult?.displayName ?? 'Location unavailable',
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

  Widget _buildSavedLocationTile(UserLocationModel location) {
    return InkWell(
      onTap: () async {
        final place = PlaceResult(
          placeId: location.id.toString(),
          name: location.locationName ?? location.address ?? 'Saved Location',
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
                color: location.isPrimary ? const Color(0xFFED3973).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getLocationIcon(location.locationType),
                size: 22,
                color: location.isPrimary ? const Color(0xFFED3973) : Colors.grey.shade600,
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
                          location.locationName ?? location.locationType ?? 'Saved Location',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (location.isPrimary)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFED3973).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Selected',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFED3973),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location.address ?? '',
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

  IconData _getLocationIcon(String? type) {
    switch (type?.toUpperCase()) {
      case 'HOME':
        return PhosphorIcons.house();
      case 'WORK':
      case 'OFFICE':
        return PhosphorIcons.briefcase();
      default:
        return PhosphorIcons.mapPin();
    }
  }
}
