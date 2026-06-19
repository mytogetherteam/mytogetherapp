import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/theme/app_map_theme.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Map with a fixed center pin. Uses [Positioned.fill] so the platform view
/// gets bounded size (required on web). Parent should avoid setState on pin
/// moves so this widget is not rebuilt unnecessarily.
class PinnedMapView extends StatefulWidget {
  final LatLng initialPosition;
  final EdgeInsets mapPadding;
  final VoidCallback onGoToMyLocation;
  final VoidCallback? onCameraMoveStarted;
  final ValueChanged<LatLng> onPinDropped;
  final ValueChanged<GoogleMapController>? onControllerReady;

  const PinnedMapView({
    super.key,
    required this.initialPosition,
    this.mapPadding = EdgeInsets.zero,
    required this.onGoToMyLocation,
    this.onCameraMoveStarted,
    required this.onPinDropped,
    this.onControllerReady,
  });

  @override
  State<PinnedMapView> createState() => PinnedMapViewState();
}

class PinnedMapViewState extends State<PinnedMapView> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _cameraTarget;
  bool _isMapMoving = false;
  bool _tilesVisible = false;
  bool _initialLookupSent = false;

  static const _pinLift = 36.0;

  Future<void> animateTo(LatLng target, {double zoom = 16}) async {
    final controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  void _notifyPinDropped(LatLng target) {
    widget.onPinDropped(target);
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    if (!_controller.isCompleted) {
      _controller.complete(controller);
    }
    _cameraTarget = widget.initialPosition;
    widget.onControllerReady?.call(controller);

    if (mounted) {
      setState(() => _tilesVisible = true);
    }

    // Web platform views often need a nudge after first layout before tiles paint.
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      try {
        await controller.moveCamera(
          CameraUpdate.newLatLngZoom(widget.initialPosition, 16),
        );
      } catch (_) {}
    }

    if (!_initialLookupSent) {
      _initialLookupSent = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _notifyPinDropped(_cameraTarget ?? widget.initialPosition);
        }
      });
    }
  }

  void _onCameraIdle() {
    final target = _cameraTarget ?? widget.initialPosition;
    if (_isMapMoving) {
      setState(() => _isMapMoving = false);
    }
    _notifyPinDropped(target);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: 16,
            ),
            padding: widget.mapPadding,
            myLocationEnabled: !kIsWeb,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            style: kIsWeb ? null : AppMapTheme.defaultStyle,
            onMapCreated: _onMapCreated,
            onCameraMoveStarted: () {
              widget.onCameraMoveStarted?.call();
              if (!_isMapMoving) {
                setState(() => _isMapMoving = true);
              }
            },
            onCameraMove: (position) {
              _cameraTarget = position.target;
            },
            onCameraIdle: _onCameraIdle,
          ),
        ),
        if (!_tilesVisible)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xFFF1F5F9),
              child: Center(child: CustomLoadingIndicator(size: 28)),
            ),
          ),
        Center(
          child: Padding(
            padding: EdgeInsets.only(
              top: widget.mapPadding.top,
              bottom: widget.mapPadding.bottom > 0
                  ? widget.mapPadding.bottom
                  : _pinLift,
            ),
            child: IgnorePointer(
              child: Icon(
                PhosphorIconsFill.mapPin,
                size: 44,
                color: AppColors.primary,
                shadows: const [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            elevation: 4,
            onPressed: widget.onGoToMyLocation,
            child: Icon(
              PhosphorIcons.crosshairSimple,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}
