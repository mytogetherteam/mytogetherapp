import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_enable_dialog.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../auth/data/models/user_location_model.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/guest_auth_guard.dart';
import '../../../../core/network/dio_error_message.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/data/delivery_address_prefs.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../auth/data/session_location_store.dart';
import '../widgets/location_details_sheet.dart';
import '../widgets/map_picker_address_panel.dart';
import '../widgets/map_pin_geocode_controller.dart';
import '../widgets/pinned_map_view.dart';

/// Unified map + search + pin screen for adding a delivery location.
class LocationPickerPage extends StatefulWidget {
  /// First delivery: back asks to save or discard. Checkout still requires a saved address.
  final bool forcedSetup;

  const LocationPickerPage({super.key, this.forcedSetup = false});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final GlobalKey<PinnedMapViewState> _mapKey = GlobalKey();
  final TextEditingController _phoneController = TextEditingController();
  late final MapPinGeocodeController _geocode;

  LatLng? _selectedPosition;
  bool _isLoadingInitial = true;
  bool _showMap = false;
  bool _isSaving = false;
  bool _didSaveAddress = false;
  bool _leavePromptOpen = false;
  bool _geocodeReady = false;
  bool _askForPhone = false;
  bool _checkingPhone = false;
  String? _phoneError;

  static const _pinLift = 36.0;

  @override
  void initState() {
    super.initState();
    final storedPhone = AuthService().currentUser?.phone?.trim() ?? '';
    _askForPhone = !GuestAuthGuard.isGuest &&
        (storedPhone.isEmpty || storedPhone.startsWith('g_'));
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
    _geocode = MapPinGeocodeController(
      addressController: TextEditingController(),
    );
    _geocodeReady = true;
    _resolveInitialPosition();
  }

  @override
  void dispose() {
    if (_geocodeReady) {
      _geocode.addressController.dispose();
      _geocode.dispose();
    }
    _phoneController.dispose();
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
    } catch (e) {
      if (kDebugMode) debugPrint('location_picker_page.dart: ignored error: $e');
    }

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

    final resolvedLat = lat;
    final resolvedLon = lon;
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
    await _geocode.lookupInitialPosition(position);
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
        await LocationEnableDialog.show(context);
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

  bool get _interceptBack => widget.forcedSetup && !GuestAuthGuard.isGuest;

  void _onBack() {
    if (_isSaving) return;
    if (!_interceptBack) {
      Navigator.of(context).pop();
      return;
    }
    _promptSaveOrDiscard();
  }

  Future<void> _promptSaveOrDiscard() async {
    if (_leavePromptOpen || _isSaving || !mounted) return;
    _leavePromptOpen = true;
    try {
      final action = await AppDialog.show<bool>(
        context: context,
        title: context.tr('location.leave_title'),
        content: context.tr('location.leave_body'),
        buttonText: context.tr('common.save'),
        secondaryButtonText: context.tr('location.discard'),
      );
      if (!mounted) return;
      if (action == false) {
        Navigator.of(context).pop();
        return;
      }
      if (action == true) {
        final draft = await _currentDraft(notifyIfNotReady: true);
        if (draft == null || !mounted) return;
        await _persistNewLocation(draft);
      }
    } finally {
      _leavePromptOpen = false;
    }
  }

  /// Builds the pin address. Returns null when the map or street address is not ready.
  Future<UserLocationModel?> _currentDraft({bool notifyIfNotReady = false}) async {
    if (_isSaving) return null;
    if (_geocode.isMapMoving || _selectedPosition == null) {
      if (notifyIfNotReady && mounted) {
        AppDialog.showToast(
          context,
          context.tr('location.address_not_ready'),
          isError: true,
        );
      }
      return null;
    }

    final address = _geocode.addressController.text.trim();
    if (address.isEmpty) {
      _geocode.setAddressRequiredError(
        context.tr('location.street_address_required'),
      );
      return null;
    }

    final pos = _selectedPosition!;
    await SessionLocationStore.save(
      latitude: pos.latitude,
      longitude: pos.longitude,
      address: address,
    );
    if (!mounted) return null;

    // Use the geocode-resolved place name (condo / building / POI) as the
    // default building name so the LocationDetailsSheet pre-fills it.
    final geoName = _geocode.selectedPlaceResult?.name.trim();
    final buildingNameHint =
        (geoName != null && geoName.isNotEmpty) ? geoName : null;

    return UserLocationModel(
      id: 0,
      latitude: pos.latitude,
      longitude: pos.longitude,
      locationName: null,
      address: address,
      buildingName: buildingNameHint,
      locationType: 'OTHER',
      isPrimary: true,
    );
  }

  String _normalizePhone(String raw) {
    var digits = raw.trim().replaceAll(' ', '').replaceAll('-', '');
    if (digits.startsWith('+66')) digits = digits.substring(3);
    else if (digits.startsWith('66')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return digits;
  }

  bool _phoneDigitsAreValid(String digits) =>
      RegExp(r'^[689]\d{8}$').hasMatch(_normalizePhone(digits));

  Future<bool> _deliveryPhoneReady({bool checkTaken = false}) async {
    if (!_askForPhone) return true;
    final digits = _phoneController.text.trim();
    if (!_phoneDigitsAreValid(digits)) {
      if (mounted) {
        setState(() {
          _phoneError = digits.isEmpty
              ? context.tr('location.delivery_phone_required')
              : context.tr('auth.invalid_thai_phone');
        });
      }
      return false;
    }
    if (checkTaken) {
      final normalized = _normalizePhone(digits);
      final taken = await AuthRepository.instance.checkPhoneExists('+66$normalized');
      if (!mounted) return false;
      if (taken) {
        setState(() => _phoneError = context.tr('location.delivery_phone_taken'));
        return false;
      }
    }
    if (mounted && _phoneError != null) setState(() => _phoneError = null);
    return true;
  }

  Future<bool> _saveDeliveryPhone() async {
    if (!_askForPhone) return true;
    if (!await _deliveryPhoneReady(checkTaken: true)) return false;
    try {
      final normalized = _normalizePhone(_phoneController.text);
      await AuthRepository.instance.updateProfile(
        phone: '+66$normalized',
      );
      if (mounted) {
        setState(() {
          _askForPhone = false;
          _phoneError = null;
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _phoneError = userFacingError(
            e,
            fallback: context.tr('firebase.unknown_error'),
          );
        });
      }
      return false;
    }
  }

  Future<void> _confirm() async {
    if (_isSaving || _checkingPhone) return;
    setState(() => _checkingPhone = true);
    try {
      if (!await _deliveryPhoneReady(checkTaken: true)) return;
      final draft = await _currentDraft();
      if (draft == null || !mounted) return;
      if (mounted) setState(() => _checkingPhone = false);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => LocationDetailsSheet(
          location: draft,
          isEdit: false,
          onSave: _persistNewLocation,
        ),
      );
    } finally {
      if (mounted && _checkingPhone) setState(() => _checkingPhone = false);
    }
  }

  Future<void> _persistNewLocation(UserLocationModel model) async {
    if (_isSaving) return;
    if (!await _saveDeliveryPhone()) return;
    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      final saved = await UserLocationRepository.instance.addLocation(model);
      if (widget.forcedSetup) {
        await DeliveryAddressPrefs.setCompletedSetup(true);
      }
      UserLocationRepository.instance.setActiveLocation(saved);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _didSaveAddress = true;
      });
      Navigator.of(context).pop(saved);
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
      if (mounted && !_didSaveAddress) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: _onBack,
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
      ),
    );
  }

  Widget _buildForcedSetupBanner() {
    return Material(
      color: const Color(0xFFFFF7ED),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              PhosphorIconsFill.mapPin,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('location.forced_setup_title'),
                    style: AppFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('location.forced_setup_subtitle'),
                    style: AppFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.4,
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

  @override
  Widget build(BuildContext context) {
    final forcedBannerInset = widget.forcedSetup ? 88.0 : 0.0;

    return PopScope(
      canPop: !_interceptBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_interceptBack) return;
        _promptSaveOrDiscard();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isLoadingInitial || _selectedPosition == null
            ? Stack(
                children: [
                  const Center(child: CustomLoadingIndicator(size: 32)),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    left: 8,
                    child: _buildBackButton(),
                  ),
                ],
              )
            : Stack(
                children: [
                  Column(
                    children: [
                      SizedBox(height: forcedBannerInset),
                      Expanded(
                        child: _showMap
                            ? PinnedMapView(
                              key: _mapKey,
                              initialPosition: _selectedPosition!,
                              mapPadding: EdgeInsets.only(
                                top: 72 + forcedBannerInset,
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
                          isSaving: _isSaving || _checkingPhone,
                          canConfirmBase: _selectedPosition != null,
                          addressError: _geocode.addressError,
                          onAddressChanged: _geocode.onAddressEdited,
                          onConfirm: _confirm,
                          askForPhone: _askForPhone,
                          phoneController: _phoneController,
                          phoneError: _phoneError,
                          onPhoneChanged: () {
                            final digits = _phoneController.text.trim();
                            if (_phoneError != null &&
                                _phoneDigitsAreValid(digits)) {
                              setState(() => _phoneError = null);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (widget.forcedSetup)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: _buildForcedSetupBanner(),
                      ),
                    ),
                  _buildTopOverlay(forcedBannerInset: forcedBannerInset),
                  if (_isSaving)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x44FFFFFF),
                        child: Center(child: CustomLoadingIndicator(size: 32)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildTopOverlay({double forcedBannerInset = 0}) {
    final topInset = MediaQuery.of(context).padding.top + forcedBannerInset;
    return Positioned(
      top: topInset + 8,
      left: 12,
      child: _buildBackButton(),
    );
  }
}
