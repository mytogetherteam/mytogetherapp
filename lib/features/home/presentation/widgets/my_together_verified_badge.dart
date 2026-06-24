import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';

/// MyTogether verified seal — primary gradient, tap for tooltip.
class MyTogetherVerifiedBadge extends StatelessWidget {
  static const double cardSize = 16;
  static const double detailSize = 18;
  static const double overviewSize = 22;

  final double size;

  const MyTogetherVerifiedBadge({super.key, required this.size});

  const MyTogetherVerifiedBadge.card({super.key}) : size = cardSize;

  const MyTogetherVerifiedBadge.detail({super.key}) : size = detailSize;

  const MyTogetherVerifiedBadge.overview({super.key}) : size = overviewSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      preferBelow: false,
      message: context.tr('restaurant.verified_tooltip'),
      child: Semantics(
        label: context.tr('restaurant.verified_tooltip'),
        button: true,
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: Icon(
            PhosphorIconsFill.sealCheck,
            size: size,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Restaurant name with an optional verified badge beside it.
class VerifiedRestaurantNameRow extends StatelessWidget {
  final String name;
  final bool isVerified;
  final TextStyle style;
  final double badgeSize;
  final int maxLines;
  final MainAxisAlignment alignment;

  const VerifiedRestaurantNameRow({
    super.key,
    required this.name,
    required this.isVerified,
    required this.style,
    required this.badgeSize,
    this.maxLines = 1,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            name,
            style: style,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isVerified) ...[
          const SizedBox(width: 4),
          MyTogetherVerifiedBadge(size: badgeSize),
        ],
      ],
    );
  }
}
