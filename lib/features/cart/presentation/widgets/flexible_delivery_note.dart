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
  final String? estimatedFee;
  final bool isActualFee;

  const FlexibleDeliveryNote({
    super.key, 
    this.margin, 
    this.estimatedFee,
    this.isActualFee = false,
  });

  @override
  Widget build(BuildContext context) {
    if (estimatedFee != null && estimatedFee!.isNotEmpty) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            // Top part: The Fee
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const GradientIcon(icon: PhosphorIconsFill.moped, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isActualFee 
                          ? context.tr('payment.actual_delivery_fee')
                          : context.tr('payment.est_delivery_fee'),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    estimatedFee!,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
