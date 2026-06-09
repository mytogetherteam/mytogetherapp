import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShopItemMetadataRow extends StatelessWidget {
  final double? rating;
  final int? reviewCount;
  final double? distanceKm;
  final String? deliveryTime;
  final String? deliveryFee;
  final String? originalDeliveryFee;
  final bool showDeliveryFee;
  final double iconSize;
  final double fontSize;

  const ShopItemMetadataRow({
    super.key,
    this.rating,
    this.reviewCount,
    this.distanceKm,
    this.deliveryTime,
    this.deliveryFee,
    this.originalDeliveryFee,
    this.showDeliveryFee = true,
    this.iconSize = 14.0,
    this.fontSize = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final elements = <Widget>[];

    // 1. Rating & Review Count
    if (rating != null && rating! > 0 && reviewCount != null && reviewCount! > 0) {
      elements.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
             Icon(Icons.star_rounded, color: Colors.amber, size: iconSize + 2),
             const SizedBox(width: 2),
             Text(
               rating!.toStringAsFixed(1),
               style: GoogleFonts.poppins(
                 fontSize: fontSize + 1,
                 fontWeight: FontWeight.w600,
                 color: Colors.black,
                 height: 1.0,
               ),
             ),
             if (reviewCount != null && reviewCount! > 0) ...[
               const SizedBox(width: 4),
               Text(
                 '($reviewCount)',
                 style: GoogleFonts.poppins(
                   fontSize: fontSize,
                   fontWeight: FontWeight.w400,
                   color: Colors.grey[500],
                   height: 1.0,
                 ),
               ),
             ]
          ],
        ),
      );
    }

    // 2. Distance
    if (distanceKm != null) {
      String distStr = distanceKm! < 1.0 
          ? '${(distanceKm! * 1000).toInt()}m' 
          : '${distanceKm!.toStringAsFixed(1)}km';
      elements.add(
        Text(
          distStr,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            color: Colors.grey[500],
            height: 1.0,
          ),
        ),
      );
    }

    // 3. ETA / Delivery Time
    if (deliveryTime != null && deliveryTime!.isNotEmpty) {
      String timeStr = deliveryTime!.replaceAll('mins', 'min').replaceAll('minutes', 'min');
      elements.add(
        Text(
          timeStr,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            color: Colors.grey[500],
            height: 1.0,
          ),
        ),
      );
    }

    // 4. Delivery Fee (hide empty/zero — API often returns "0" for menu items)
    if (showDeliveryFee && _hasMeaningfulDeliveryFee(deliveryFee)) {
      elements.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining_outlined, color: const Color(0xFF10B981), size: iconSize + 2),
            const SizedBox(width: 4),
            Text(
              deliveryFee!,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF10B981), // Teal color from design
                height: 1.0,
              ),
            ),
            if (originalDeliveryFee != null && originalDeliveryFee!.isNotEmpty && originalDeliveryFee != deliveryFee) ...[
              const SizedBox(width: 4),
              Text(
                originalDeliveryFee!,
                style: GoogleFonts.poppins(
                  fontSize: fontSize - 1,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[400],
                  decoration: TextDecoration.lineThrough,
                  height: 1.0,
                ),
              ),
            ]
          ],
        )
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4.0,
      runSpacing: 4.0,
      children: [
        for (int i = 0; i < elements.length; i++) ...[
          elements[i],
          if (i < elements.length - 1)
            Text(
              '|',
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
        ]
      ],
    );
  }

  /// Returns false for null, blank, or zero-valued fees (e.g. "0", "฿0", "Free" is kept).
  static bool _hasMeaningfulDeliveryFee(String? fee) {
    if (fee == null || fee.trim().isEmpty) return false;
    final lower = fee.trim().toLowerCase();
    if (lower == 'free') return true;
    final numeric = fee.replaceAll(RegExp(r'[^0-9.]'), '');
    if (numeric.isEmpty) return true; // non-numeric label, show it
    final value = double.tryParse(numeric);
    return value != null && value > 0;
  }
}
