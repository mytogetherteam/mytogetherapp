import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
                  'Upload Item Photo',
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
                  leading: const Icon(Icons.photo_library_outlined, color: Color(0xFFED3A72)),
                  title: Text(
                    'Choose from Gallery',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, ImageUploadAction.gallery),
                ),
                Divider(color: Colors.grey[200], height: 1, indent: 24, endIndent: 24),
                
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFFED3A72)),
                  title: Text(
                    'Take a Photo',
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
                      'Remove Photo',
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
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFF9E4751), // matching the darker pink cancel text from UI
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
