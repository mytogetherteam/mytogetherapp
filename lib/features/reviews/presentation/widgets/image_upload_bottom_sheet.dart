import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

enum ImageUploadAction { gallery, camera, remove }

class ImageUploadBottomSheet {
  static Future<ImageUploadAction?> show(BuildContext context, {bool showRemove = false}) {
    return showModalBottomSheet<ImageUploadAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.tr('review.upload_photo'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey[200], height: 1),
                
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: Icon(Icons.photo_library_outlined, color: AppColors.primary),
                  title: Text(
                    context.tr('review.choose_gallery'),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, ImageUploadAction.gallery),
                ),
                Divider(color: Colors.grey[200], height: 1, indent: 24, endIndent: 24),

                if (!kIsWeb)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                    title: Text(
                      context.tr('review.take_photo'),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, ImageUploadAction.camera),
                  ),
                
                if (showRemove) ...[
                  Divider(color: Colors.grey[200], height: 1, indent: 24, endIndent: 24),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(
                      context.tr('review.remove_photo'),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.red,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, ImageUploadAction.remove),
                  ),
                ],
                
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(
                    context.tr('common.cancel'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
