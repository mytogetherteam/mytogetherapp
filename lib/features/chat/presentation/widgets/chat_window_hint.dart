import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/features/chat/data/models/chat_window.dart';

/// States the post-delivery support window ("message the shop for 4 hours")
/// together with the time left.
///
/// It needs a full-width line of its own: the wording wraps to two lines on a
/// phone and gets clipped when squeezed into a button label.
class ChatWindowHint extends StatelessWidget {
  final DateTime? closesAt;

  /// Adds a tinted rounded background, used as a banner above a message list.
  final bool filled;

  const ChatWindowHint({
    super.key,
    required this.closesAt,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeLeft = ChatWindow.timeLeftUntil(closesAt);
    final text = timeLeft == null
        ? context.tr('chat.window_hint_no_time')
        : context.trArgs('chat.window_hint', {
            'time': context.countdown(timeLeft),
          });

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.schedule_rounded, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );

    if (!filled) return row;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: row,
    );
  }
}
