import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'food_scramble_game_sheet.dart';

class FoodGameBanner extends StatelessWidget {
  const FoodGameBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: const Color(0xFFFBF1E4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3E5D4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF78350F).withValues(alpha: 0.06),
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              FoodScrambleGameSheet.show(context);
            },
            borderRadius: BorderRadius.circular(17),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keep text starting safely past the character's pointing finger
                final leftPadding =
                    (constraints.maxWidth * 0.43).clamp(142.0, 185.0);

                return Stack(
                  children: [
                    // Illustration Background
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/food_game_banner_bg.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.centerLeft,
                      ),
                    ),

                    // Content Area (Positioned past the character on the left)
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: leftPadding,
                          right: 14,
                          top: 7,
                          bottom: 7,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            // Main Title - Single line, un-truncated
                            Text(
                              'အစားအစာ စကားလုံးဆက်တမ်း',
                              style: AppFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B),
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),

                            // Subtitle
                            Text(
                              'အော်ဒါစောင့်ဆိုင်းရင်း ဉာဏ်စမ်းပါ',
                              style: AppFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 7),

                            // Play Button Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.28),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'ကစားမည်',
                                    style: AppFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    PhosphorIcons.caretRightBold,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
