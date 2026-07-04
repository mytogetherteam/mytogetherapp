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
///
/// Long names ellipsize (`...`); the badge stays visible on the right and is
/// never clipped. Use [centered] on overview-style headers so short names
/// stay visually centered as a name+badge group.
class VerifiedRestaurantNameRow extends StatelessWidget {
  final String name;
  final bool isVerified;
  final TextStyle style;
  final double badgeSize;
  final int maxLines;
  /// When true, the name+badge group is centered (overview). When false, the
  /// row spans the full available width (cards, detail headers).
  final bool centered;

  const VerifiedRestaurantNameRow({
    super.key,
    required this.name,
    required this.isVerified,
    required this.style,
    required this.badgeSize,
    this.maxLines = 1,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final nameText = Text(
      name,
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );

    final badge = isVerified
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 4),
              MyTogetherVerifiedBadge(size: badgeSize),
            ],
          )
        : null;

    if (centered) {
      // Short names: centered name+badge group. Long names: truncate before badge.
      return LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: nameText),
                  if (badge != null) badge,
                ],
              ),
            ),
          );
        },
      );
    }

    // Full-width: name fills leftover space; badge pinned to the trailing edge.
    return Row(
      children: [
        Expanded(child: nameText),
        if (badge != null) badge,
      ],
    );
  }
}
