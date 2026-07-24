import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../features/home/data/repositories/restaurant_repository.dart';

/// Holds the optional remote Splash banner fetched at boot.
class BrandedSplash {
  BrandedSplash._();

  static String? imageUrl;
  static Uint8List? imageBytes;

  static bool get hasSplash =>
      (imageBytes != null && imageBytes!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);

  /// Fetches `position=Splash`. Keeps the URL even if byte download fails so
  /// the gate can still render via [CachedNetworkImage].
  static Future<void> prefetch() async {
    try {
      final banners = await RestaurantRepository.instance.getBanners(
        position: 'Splash',
      );
      final url = banners.isNotEmpty ? banners.first.imageUrl : null;
      if (url == null || url.isEmpty) {
        debugPrint('[BOOT] No Splash banner configured.');
        imageUrl = null;
        imageBytes = null;
        return;
      }

      imageUrl = url;
      debugPrint('[BOOT] Splash banner URL: $url');

      try {
        final response = await Dio().get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 4),
            sendTimeout: const Duration(seconds: 4),
          ),
        );
        final data = response.data;
        if (response.statusCode == 200 && data != null && data.isNotEmpty) {
          imageBytes = Uint8List.fromList(data);
          debugPrint(
            '[BOOT] Splash banner bytes ready (${imageBytes!.length})',
          );
        }
      } catch (e) {
        debugPrint('[BOOT] Splash byte download failed (URL fallback): $e');
        imageBytes = null;
      }
    } catch (e) {
      imageUrl = null;
      imageBytes = null;
      debugPrint('[BOOT] Splash banner fetch failed: $e');
    }
  }
}

/// Full-screen remote splash over [child]. Uses precached bytes when available,
/// otherwise loads [BrandedSplash.imageUrl]. Removes native splash on first frame.
class BrandedSplashGate extends StatefulWidget {
  final Widget child;
  final Duration minDisplay;

  const BrandedSplashGate({
    super.key,
    required this.child,
    this.minDisplay = const Duration(milliseconds: 2200),
  });

  @override
  State<BrandedSplashGate> createState() => _BrandedSplashGateState();
}

class _BrandedSplashGateState extends State<BrandedSplashGate> {
  late final bool _hasRemoteSplash;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _hasRemoteSplash = BrandedSplash.hasSplash;
    if (!_hasRemoteSplash) return;

    _visible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      Future<void>.delayed(widget.minDisplay, () {
        if (mounted) setState(() => _visible = false);
      });
    });
  }

  Widget _buildSplashImage() {
    final bytes = BrandedSplash.imageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    }

    final url = BrandedSplash.imageUrl!;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: Duration.zero,
      placeholder: (_, _) => const ColoredBox(color: Colors.white),
      errorWidget: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _visible) setState(() => _visible = false);
        });
        return const ColoredBox(color: Colors.white);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasRemoteSplash) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_visible,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            child: ColoredBox(
              color: Colors.white,
              child: _buildSplashImage(),
            ),
          ),
        ),
      ],
    );
  }
}
