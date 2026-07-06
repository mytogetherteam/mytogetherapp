import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_text.dart';
import 'package:mytogetherapp/core/config/env_config.dart';
import '../../data/models/announcement_model.dart';

/// Full-bleed announcement detail, styled after the early-access reference:
/// a centered modal box with a hero image that fades into the white body,
/// a gradient title, and the body copy. The user dismisses with the close
/// affordance or by tapping the barrier.
class AnnouncementDetailSheet extends StatelessWidget {
  final AnnouncementModel announcement;

  const AnnouncementDetailSheet({super.key, required this.announcement});

  static Future<void> show(
    BuildContext context,
    AnnouncementModel announcement,
  ) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: true,
      builder: (_) => AnnouncementDetailSheet(announcement: announcement),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty;
    final size = MediaQuery.of(context).size;
    // Fill the available width (minus the dialog inset) up to a comfortable
    // max, so the box never collapses around short content.
    final double boxWidth = (size.width - 48).clamp(0.0, 400.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SizedBox(
        width: boxWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: size.height * 0.82,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      if (hasImage)
                        _buildImageHeader(context)
                      else
                        const SizedBox(height: 48),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          hasImage ? 0 : 8,
                          24,
                          28,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GradientText(
                              announcement.title,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
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
              ),
            ),
              Positioned(
                top: 12,
                right: 12,
                child: _CloseButton(onTap: () => Navigator.pop(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageHeader(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 11,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            fadeInDuration: const Duration(milliseconds: 300),
            fadeOutDuration: const Duration(milliseconds: 300),
            imageUrl: _getFullImageUrl(announcement.imageUrl!),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: (context, url) => Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (context, url, error) {
              debugPrint('ANNOUNCEMENT IMAGE LOAD ERROR: $url -> $error');
              return Container(
                color: Colors.grey.shade200,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey.shade400,
                  size: 48,
                ),
              );
            },
          ),
          // Fade the bottom of the image into the white body so the photo
          // blends into the content instead of showing a hard edge.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.35, 0.75, 1.0],
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.55),
                  Colors.white,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return LocaleController.instance
        .relativeTime(date, olderFormat: 'MMM d, yyyy');
  }

  String _getFullImageUrl(String url) {
    if (url.startsWith('http')) return url;
    
    // The backend currently returns relative paths for announcements but stores them in S3
    if (url.startsWith('announcements/')) {
      return 'https://my-together-moonlight201.s3.ap-southeast-1.amazonaws.com/$url';
    }

    String baseUrl = EnvConfig.apiBaseUrl;
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    if (!url.startsWith('/')) url = '/$url';
    return '$baseUrl$url';
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


