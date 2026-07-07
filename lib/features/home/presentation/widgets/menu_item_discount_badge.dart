import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

/// Corner badge label for a discounted menu item.
String? menuItemDiscountBadgeLabel({
  double? originalPrice,
  double? sellingPrice,
  double? discountPercentage,
  double? discountAmount,
}) {
  if (discountPercentage != null && discountPercentage > 0) {
    final v = discountPercentage == discountPercentage.roundToDouble()
        ? discountPercentage.toInt()
        : discountPercentage;
    return '-$v%';
  }

  final original = originalPrice ?? 0;
  final selling = sellingPrice ?? original;
  if (original > 0 && selling < original) {
    if (discountAmount != null && discountAmount > 0) {
      final v = discountAmount == discountAmount.roundToDouble()
          ? discountAmount.toInt()
          : discountAmount;
      return '-฿$v';
    }
    final pct = ((original - selling) / original * 100).round();
    if (pct > 0) return '-$pct%';
  }

  return null;
}

class MenuItemDiscountBadge extends StatelessWidget {
  final String label;

  const MenuItemDiscountBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
