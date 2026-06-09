import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

/// Reusable "no data" / empty-state placeholder.
///
/// Use this whenever a data-driven screen finishes loading successfully but has
/// nothing to display, so the user sees a friendly message instead of a blank
/// screen. Optionally renders a retry/refresh action.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    this.icon = Icons.inbox_rounded,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            Text(
              title ?? context.tr('common.no_data_title'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle ?? context.tr('common.no_data_sub'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[500],
                height: 1.4,
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: onAction,
                icon: Icon(Icons.refresh_rounded,
                    size: 18, color: AppColors.primary),
                label: Text(
                  actionLabel ?? context.tr('common.retry'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
