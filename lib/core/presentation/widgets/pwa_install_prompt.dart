import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; 

class PWAInstallPrompt extends StatefulWidget {
  final Widget child;
  const PWAInstallPrompt({super.key, required this.child});

  @override
  State<PWAInstallPrompt> createState() => _PWAInstallPromptState();
}

class _PWAInstallPromptState extends State<PWAInstallPrompt> {
  dynamic _deferredPrompt;
  bool _showInstallPrompt = false;
  bool _isIOS = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    
    // Use a small delay to ensure the engine is fully ready before running PWA logic
    Timer(const Duration(milliseconds: 500), () {
      try {
        _initPwaLogic();
      } catch (e) {
        debugPrint(' [PWA] Error during init: $e');
      }
    });
  }

  void _initPwaLogic() {
    // Check if it's already running as a standalone app
    bool isStandalone = html.window.matchMedia('(display-mode: standalone)').matches;
    
    // Safely check for iOS-specific standalone property
    try {
      final nav = html.window.navigator;
      if ((nav as dynamic).standalone == true) {
        isStandalone = true;
      }
    } catch (_) {}

    debugPrint(' [PWA] Status: isStandalone=$isStandalone');
    if (isStandalone) return;

    _isIOS = html.window.navigator.userAgent.contains('iPhone') ||
             html.window.navigator.userAgent.contains('iPad');

    // Listen for the Chrome/Android install prompt
    html.window.addEventListener('beforeinstallprompt', (event) {
      debugPrint(' [PWA] Detected Chrome install prompt event');
      event.preventDefault();
      _deferredPrompt = event;
      if (mounted) setState(() => _showInstallPrompt = true);
    });

    // For iOS, show the guide after 3 seconds
    if (_isIOS) {
      debugPrint(' [PWA] Detected iOS environment');
      Timer(const Duration(seconds: 3), () {
        if (mounted && _deferredPrompt == null) {
          setState(() => _showInstallPrompt = true);
        }
      });
    }
  }

  void _checkPwaStatus() {
    // Only show if we are on web and not already installed
  }

  Future<void> _installPwa() async {
    if (_deferredPrompt != null) {
      _deferredPrompt.prompt();
      final result = await _deferredPrompt.userChoice;
      if (result['outcome'] == 'accepted') {
        setState(() {
          _showInstallPrompt = false;
        });
      }
      _deferredPrompt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showInstallPrompt)
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFED3A72), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFED3A72).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.download, color: Color(0xFFED3A72)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Install MyTogether',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            _isIOS 
                                ? 'Tap Share > Add to Home Screen' 
                                : 'Install App for better experience',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _showInstallPrompt = false),
                    ),
                    ElevatedButton(
                      onPressed: _isIOS ? null : _installPwa,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFED3A72),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(_isIOS ? 'Safari' : 'Install'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
