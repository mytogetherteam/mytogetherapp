import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/features/call/data/call_session.dart';
import 'package:mytogetherapp/features/call/presentation/screens/call_screen.dart';
import 'package:mytogetherapp/app.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class FloatingCallBanner extends StatelessWidget {
  const FloatingCallBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CallState>(
      valueListenable: CallSession().state,
      builder: (context, state, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: CallScreen.isVisibleNotifier,
          builder: (context, isVisible, child) {
            if (isVisible || state == CallState.idle || state == CallState.ended) {
              return const SizedBox.shrink();
            }

            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  final nav = App.navigatorKey.currentState;
                  if (nav != null) {
                    nav.push(
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          shopName: CallSession().currentShopName ?? 'Unknown',
                          shopImageUrl: CallSession().currentShopImageUrl,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  color: const Color(0xFF22C55E), // Green
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(PhosphorIcons.phoneCallFill, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Tap to return to call',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
