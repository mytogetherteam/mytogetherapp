import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

/// Ordering vs browse-only. Delivery and pickup both count as ordering.
enum RestaurantOrderingFilter {
  delivery,
  visitOnly,
}

class RestaurantOrderingFilterChips extends StatelessWidget {
  final RestaurantOrderingFilter selected;
  final ValueChanged<RestaurantOrderingFilter> onChanged;
  final EdgeInsetsGeometry padding;

  const RestaurantOrderingFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          _Chip(
            label: context.tr('restaurants.tab_delivery'),
            selected: selected == RestaurantOrderingFilter.delivery,
            onTap: () => onChanged(RestaurantOrderingFilter.delivery),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: context.tr('restaurants.tab_visit_only'),
            selected: selected == RestaurantOrderingFilter.visitOnly,
            onTap: () => onChanged(RestaurantOrderingFilter.visitOnly),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
