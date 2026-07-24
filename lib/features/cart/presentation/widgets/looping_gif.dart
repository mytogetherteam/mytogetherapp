import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoopingGif extends StatefulWidget {
  /// Local asset path (e.g. `assets/images/cooking.gif`). Used when
  /// [bytes] / [networkUrl] are missing or fail to load.
  final String? assetPath;

  /// Optional remote GIF/image URL (Order / Splash banners keep original format).
  final String? networkUrl;

  /// Already-downloaded image bytes (e.g. splash precache). Preferred over URL.
  final Uint8List? bytes;

  final double? height;
  final double? width;
  final BoxFit? fit;
  final Duration loopDuration;

  const LoopingGif({
    super.key,
    this.assetPath,
    this.networkUrl,
    this.bytes,
    this.height,
    this.width,
    this.fit,
    this.loopDuration = const Duration(milliseconds: 3800),
  }) : assert(
         assetPath != null || networkUrl != null || bytes != null,
         'Either assetPath, networkUrl, or bytes must be provided',
       );

  @override
  State<LoopingGif> createState() => _LoopingGifState();
}

class _LoopingGifState extends State<LoopingGif> {
  Uint8List? _originalBytes;
  Uint8List? _activeBytes;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initGif();
  }

  @override
  void didUpdateWidget(covariant LoopingGif oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.networkUrl != widget.networkUrl ||
        oldWidget.assetPath != widget.assetPath ||
        !identical(oldWidget.bytes, widget.bytes)) {
      _timer?.cancel();
      _originalBytes = null;
      _activeBytes = null;
      _initGif();
    }
  }

  Future<void> _initGif() async {
    try {
      Uint8List? loaded = widget.bytes;

      final networkUrl = widget.networkUrl;
      if (loaded == null && networkUrl != null && networkUrl.isNotEmpty) {
        try {
          final response = await Dio().get<List<int>>(
            networkUrl,
            options: Options(
              responseType: ResponseType.bytes,
              receiveTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 8),
            ),
          );
          final data = response.data;
          if (response.statusCode == 200 && data != null && data.isNotEmpty) {
            loaded = Uint8List.fromList(data);
          }
        } catch (e) {
          debugPrint('Error loading network gif: $e');
        }
      }

      if (loaded == null) {
        final assetPath = widget.assetPath;
        if (assetPath == null || assetPath.isEmpty) return;
        final data = await rootBundle.load(assetPath);
        loaded = data.buffer.asUint8List();
      }

      _originalBytes = loaded;

      if (mounted) {
        setState(() {
          _activeBytes = Uint8List.fromList(_originalBytes!);
        });

        _timer = Timer.periodic(widget.loopDuration, (_) {
          if (mounted && _originalBytes != null) {
            setState(() {
              _activeBytes = Uint8List.fromList(_originalBytes!);
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading gif: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeBytes == null) {
      return SizedBox(height: widget.height, width: widget.width);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Image.memory(
        _activeBytes!,
        key: ValueKey(_activeBytes.hashCode),
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        gaplessPlayback: true,
      ),
    );
  }
}
