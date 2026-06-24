import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/gradient_icon.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';

/// Explains that checkout covers food (+ tax) only and delivery is paid to the
/// rider later. The fee shown elsewhere is an estimate.
class FlexibleDeliveryNote extends StatelessWidget {
  final EdgeInsetsGeometry? margin;

  const FlexibleDeliveryNote({super.key, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GradientIcon(icon: PhosphorIconsFill.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: GradientText(
              context.tr('cart.flexible_delivery_note'),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
