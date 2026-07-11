import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';

class LoopingGif extends StatefulWidget {
  final String assetPath;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final Duration loopDuration;

  const LoopingGif({
    super.key,
    required this.assetPath,
    this.height,
    this.width,
    this.fit,
    this.loopDuration = const Duration(milliseconds: 3800), // Adjusted to avoid gap
  });

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

  Future<void> _initGif() async {
    try {
      final data = await rootBundle.load(widget.assetPath);
      _originalBytes = data.buffer.asUint8List();
      
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
