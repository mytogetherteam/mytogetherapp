import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

/// Fixed-height list footer for pagination loading / end-of-list states.
///
/// Using a consistent height prevents the scroll view from shrinking when the
/// loading spinner is replaced by an end message or removed entirely.
class PaginationListFooter extends StatelessWidget {
  static const double height = 72;

  final bool isLoading;
  final bool showEndMessage;
  final String? endMessage;

  const PaginationListFooter({
    super.key,
    required this.isLoading,
    this.showEndMessage = false,
    this.endMessage,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
              )
            : showEndMessage
                ? Text(
                    endMessage ?? context.tr('food.end_of_list'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}
