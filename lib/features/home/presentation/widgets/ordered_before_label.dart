import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Small gray chip Grab uses to mark a restaurant the user has already ordered from.
class OrderedBeforeLabel extends StatelessWidget {
  final bool elevated;
  const OrderedBeforeLabel({super.key, this.elevated = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: elevated ? 10 : 8,
        vertical: elevated ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: elevated ? Colors.white : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(elevated ? 12 : 6),
        border: elevated
            ? Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1,
              )
            : null,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.clockCounterClockwise,
            size: elevated ? 14 : 12,
            color: Colors.grey[700],
          ),
          const SizedBox(width: 4),
          Text(
            context.tr('restaurant.ordered_before'),
            style: GoogleFonts.poppins(
              fontSize: elevated ? 12 : 11,
              fontWeight: elevated ? FontWeight.w600 : FontWeight.w500,
              color: const Color(0xFF374151),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
