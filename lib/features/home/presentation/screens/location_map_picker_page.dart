import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';

import '../../../../core/location/location_search_service.dart';
import '../../../../core/location/location_service.dart';
import '../../../auth/data/session_location_store.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../widgets/map_picker_address_panel.dart';
import '../widgets/map_pin_geocode_controller.dart';
import '../widgets/pinned_map_view.dart';

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
  final GlobalKey<PinnedMapViewState> _mapKey = GlobalKey();
  late final MapPinGeocodeController _geocode;

  LatLng? _selectedPosition;
  bool _isLoadingInitial = true;
  bool _showMap = false;

  static const _pinLift = 36.0;

  @override
  void initState() {
    super.initState();
    _geocode = MapPinGeocodeController(
      addressController: TextEditingController(),
    );
    _resolveInitialPosition();
  }

  @override
  void dispose() {
    _geocode.addressController.dispose();
    _geocode.dispose();
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
    if (_geocode.isMapMoving || _selectedPosition == null) return;

    final address = _geocode.addressController.text.trim();
    if (address.isEmpty) {
      _geocode.setAddressRequiredError(
        context.tr('location.street_address_required'),
      );
      return;
    }

    final pos = _selectedPosition!;
    var place = _geocode.selectedPlaceResult;

    if (place == null) {
      await _geocode.reverseGeocodeNow(pos);
      place = _geocode.selectedPlaceResult;
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
                  child: _showMap
                      ? PinnedMapView(
                          key: _mapKey,
                          initialPosition: _selectedPosition!,
                          mapPadding: const EdgeInsets.only(bottom: _pinLift),
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
                    isSaving: false,
                    canConfirmBase: _selectedPosition != null,
                    addressError: _geocode.addressError,
                    onAddressChanged: _geocode.onAddressEdited,
                    onConfirm: _confirm,
                  ),
                ),
              ],
            ),
    );
  }
}
