import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Small gray chip Grab uses to mark a restaurant the user has already ordered from.
class OrderedBeforeLabel extends StatelessWidget {
  const OrderedBeforeLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.clockCounterClockwise,
            size: 12,
            color: Colors.grey[700],
          ),
          const SizedBox(width: 4),
          Text(
            context.tr('restaurant.ordered_before'),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF374151),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
