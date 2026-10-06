import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/haptic_splash_factory.dart';

/// Empty / error / loading for the Social feed.
///
/// Light content card on a soft stage + portrait “slot” previews so empty
/// never reads as a dead black screen.
class SocialFeedStatusView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool isLoading;
  final bool showPreviewSlots;

  const SocialFeedStatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.isLoading = false,
    this.showPreviewSlots = true,
  });

  factory SocialFeedStatusView.loading({Key? key}) {
    return SocialFeedStatusView(
      key: key,
      icon: PhosphorIcons.playCircle,
      title: '',
      subtitle: '',
      isLoading: true,
      showPreviewSlots: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF141418),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _StageBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 96),
                child: isLoading
                    ? const _LoadingCard()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showPreviewSlots) ...[
                            const _FeedPreviewSlots(),
                            const SizedBox(height: 28),
                          ],
                          _StatusCard(
                            icon: icon,
                            title: title,
                            subtitle: subtitle,
                            actionLabel: actionLabel,
                            onAction: onAction,
                            secondaryActionLabel: secondaryActionLabel,
                            onSecondaryAction: onSecondaryAction,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageBackdrop extends StatelessWidget {
  const _StageBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1C1C22),
            Color(0xFF141418),
            Color(0xFF101014),
          ],
        ),
      ),
    );
  }
}

/// Three portrait frames hinting at the vertical feed layout.
class _FeedPreviewSlots extends StatelessWidget {
  const _FeedPreviewSlots();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      width: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8,
            child: Transform.rotate(
              angle: -0.12,
              child: const _PreviewSlot(
                width: 92,
                height: 140,
                fill: Color(0xFF2A2A32),
              ),
            ),
          ),
          Positioned(
            right: 8,
            child: Transform.rotate(
              angle: 0.12,
              child: const _PreviewSlot(
                width: 92,
                height: 140,
                fill: Color(0xFF2A2A32),
              ),
            ),
          ),
          const _PreviewSlot(
            width: 104,
            height: 156,
            fill: Color(0xFF32323C),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _PreviewSlot extends StatelessWidget {
  final double width;
  final double height;
  final Color fill;
  final bool emphasize;

  const _PreviewSlot({
    required this.width,
    required this.height,
    required this.fill,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasize
              ? AppColors.primary.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.08),
          width: emphasize ? 1.5 : 1,
        ),
      ),
      child: emphasize
          ? Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: const Icon(
                  PhosphorIcons.playFill,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            )
          : Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  width: 36,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF1A1A1A),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF6B6B6B),
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  AppHaptics.buttonTap();
                  onAction!();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        PhosphorIcons.arrowClockwise,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        actionLabel!,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (onSecondaryAction != null && secondaryActionLabel != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  AppHaptics.buttonTap();
                  onSecondaryAction!();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  secondaryActionLabel!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
