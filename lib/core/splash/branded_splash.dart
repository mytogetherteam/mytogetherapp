import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../features/home/data/repositories/restaurant_repository.dart';
import '../theme/app_colors.dart';

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

class _BrandedSplashGateState extends State<BrandedSplashGate> with SingleTickerProviderStateMixin {
  late final bool _hasRemoteSplash;
  bool _visible = false;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _hasRemoteSplash = BrandedSplash.hasSplash;
    if (!_hasRemoteSplash) return;

    _visible = true;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _controller.forward().then((_) {
        _dismissSplash();
      });
    });
  }

  void _dismissSplash() {
    if (mounted && _visible) {
      setState(() => _visible = false);
    }
  }

  @override
  void dispose() {
    if (_hasRemoteSplash) {
      _controller.dispose();
    }
    super.dispose();
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
      placeholder: (_, _) => const ColoredBox(color: Colors.transparent),
      errorWidget: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _dismissSplash();
        });
        return const ColoredBox(color: Colors.transparent);
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.transparent,
                  child: _buildSplashImage(),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // AD Label (Left)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'AD',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      
                      // Skip Button & Timer (Right)
                      GestureDetector(
                        onTap: _dismissSplash,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4.0),
                                child: Text(
                                  'Skip',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) {
                                    final seconds = (10 - (_controller.value * 10)).ceil();
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: 1.0 - _controller.value,
                                          strokeWidth: 2.5,
                                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                          backgroundColor: Colors.white24,
                                        ),
                                        Text(
                                          '$seconds',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
