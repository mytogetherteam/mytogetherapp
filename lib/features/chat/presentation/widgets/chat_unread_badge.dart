import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_unread_controller.dart';

/// Overlays a live unread-message count on top of an order's chat icon button.
///
/// Wrap the existing chat button visual with this widget, passing the order id.
/// The badge listens to [ChatUnreadController] and reflects messages the shop
/// has sent that the customer hasn't opened yet.
class ChatUnreadBadge extends StatelessWidget {
  final int? orderId;
  final Widget child;

  const ChatUnreadBadge({
    super.key,
    required this.orderId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final id = orderId;
    if (id == null || id <= 0) return child;

    return ValueListenableBuilder<int>(
      valueListenable: ChatUnreadController.instance.notifierFor(id),
      builder: (context, count, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFED3973),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
