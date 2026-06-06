import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_text.dart';
import '../../data/models/announcement_model.dart';

/// Full-bleed announcement detail, styled after the early-access reference:
/// a hero image that fades into the sheet, a gradient title, and the body
/// copy. There is no action button — the user dismisses with the close
/// affordance or by dragging the sheet down.
class AnnouncementDetailSheet extends StatelessWidget {
  final AnnouncementModel announcement;

  const AnnouncementDetailSheet({super.key, required this.announcement});

  static Future<void> show(
    BuildContext context,
    AnnouncementModel announcement,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => AnnouncementDetailSheet(announcement: announcement),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            color: Colors.white,
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasImage)
                        _buildImageHeader(context)
                      else
                        const SizedBox(height: 24),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          hasImage ? 0 : 16,
                          24,
                          24 + MediaQuery.of(context).padding.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GradientText(
                              announcement.title,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDate(announcement.createdAt),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              announcement.message,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                height: 1.6,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: _CloseButton(onTap: () => Navigator.pop(context)),
                ),
                if (!hasImage)
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(child: _buildGrabber()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageHeader(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return SizedBox(
      width: width,
      height: width * 0.62,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: announcement.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(color: Colors.grey.shade200),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey.shade200,
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Colors.grey.shade400,
                size: 48,
              ),
            ),
          ),
          // Fade the bottom of the image into the white sheet body.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.45, 1.0],
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white,
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(child: _buildGrabber()),
          ),
        ],
      ),
    );
  }

  Widget _buildGrabber() {
    return Container(
      width: 44,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return LocaleController.instance
        .relativeTime(date, olderFormat: 'MMM d, yyyy');
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.close, size: 20, color: AppColors.primary),
      ),
    );
  }
}
