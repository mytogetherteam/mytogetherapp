import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/media/picked_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/media/image_crop_helper.dart';
import '../../../../core/media/video_compress_helper.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/utils/haptic_splash_factory.dart';
import '../../data/repositories/social_posts_repository.dart';

class CreateSocialPostPage extends StatefulWidget {
  const CreateSocialPostPage({super.key});

  @override
  State<CreateSocialPostPage> createState() => _CreateSocialPostPageState();
}

class _CreateSocialPostPageState extends State<CreateSocialPostPage> {
  final _captionController = TextEditingController();
  final _captionFocus = FocusNode();
  final _picker = ImagePicker();
  final List<PickedImage> _media = [];
  bool _submitting = false;
  bool _isCompressing = false;

  bool get _canPublish =>
      (_media.isNotEmpty || _captionController.text.trim().isNotEmpty) &&
      !_submitting &&
      !_isCompressing;

  @override
  void initState() {
    super.initState();
    _captionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocus.dispose();
    VideoCompressHelper.clearCache();
    super.dispose();
  }

  Future<void> _handlePickAction(_PickAction action) async {
    if (_media.length >= 10) {
      AppDialog.showToast(context, context.tr('social.max_media'), isError: true);
      return;
    }
    try {
      final remaining = 10 - _media.length;
      final picked = <XFile>[];
      switch (action) {
        case _PickAction.gallery:
          final files = await _picker.pickMultiImage(
            maxWidth: 1200,
            maxHeight: 1200,
            imageQuality: 80,
            limit: remaining,
          );
          picked.addAll(files.take(remaining));
          break;
        case _PickAction.cameraPhoto:
          final file = await _picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1200,
            maxHeight: 1200,
            imageQuality: 80,
          );
          if (file != null) {
            final cropped = await ImageCropHelper.crop(file);
            picked.add(cropped ?? file);
          }
          break;
        case _PickAction.cameraVideo:
          final file = await _picker.pickVideo(
            source: ImageSource.camera,
            maxDuration: const Duration(seconds: 60),
          );
          if (file != null) picked.add(file);
          break;
        case _PickAction.galleryVideo:
          final file = await _picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(seconds: 120),
          );
          if (file != null) picked.add(file);
          break;
      }
      for (final file in picked) {
        final isVideo = file.name.toLowerCase().endsWith('.mp4') ||
            file.name.toLowerCase().endsWith('.mov') ||
            file.name.toLowerCase().endsWith('.m4v') ||
            file.name.toLowerCase().endsWith('.webm');

        if (isVideo) {
          if (mounted) setState(() => _isCompressing = true);
          try {
            final compressed = await VideoCompressHelper.compressAndConvert(file);
            _media.add(compressed);
          } finally {
            if (mounted) setState(() => _isCompressing = false);
          }
        } else {
          _media.add(await PickedImage.fromXFile(file));
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _isCompressing = false);
        AppDialog.showToast(context, context.tr('social.pick_failed'),
            isError: true);
      }
    }
  }

  Future<void> _submit() async {
    if (!_canPublish) {
      AppDialog.showToast(context, context.tr('social.media_required'),
          isError: true);
      return;
    }
    if (_submitting) return;
    AppHaptics.buttonTap();
    setState(() => _submitting = true);
    try {
      await SocialPostsRepository.instance.createPost(
        content: _captionController.text,
        media: _media,
      );
      await VideoCompressHelper.clearCache();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppDialog.showToast(context, context.tr('social.publish_failed'),
          isError: true);
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('social.pick_photo_source'),
                  style: AppFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF48BB78).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIcons.imageSquareFill,
                      color: Color(0xFF48BB78),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    context.tr('social.choose_photo_gallery'),
                    style: AppFonts.poppins(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handlePickAction(_PickAction.gallery);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4299E1).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIcons.cameraFill,
                      color: Color(0xFF4299E1),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    context.tr('social.take_photo'),
                    style: AppFonts.poppins(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handlePickAction(_PickAction.cameraPhoto);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVideoSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('social.pick_video_source'),
                  style: AppFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFED8936).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIcons.videoCameraFill,
                      color: Color(0xFFED8936),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    context.tr('social.record_camera_video'),
                    style: AppFonts.poppins(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handlePickAction(_PickAction.cameraVideo);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4299E1).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIcons.filmStripFill,
                      color: Color(0xFF4299E1),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    context.tr('social.choose_from_gallery'),
                    style: AppFonts.poppins(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handlePickAction(_PickAction.galleryVideo);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomAction({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0A0A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(PhosphorIcons.arrowLeft, color: Colors.white70, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            context.tr('social.create_post'),
            style: AppFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _submitting
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFEE1D52),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _canPublish ? _submit : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: _canPublish
                              ? const Color(0xFFEE1D52)
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          context.tr('social.publish'),
                          style: AppFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _canPublish ? Colors.white : Colors.white54,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Caption Area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: TextField(
                      controller: _captionController,
                      focusNode: _captionFocus,
                      maxLines: null,
                      minLines: 4,
                      maxLength: 5000,
                      style: AppFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.45,
                      ),
                      decoration: InputDecoration(
                        hintText: context.tr('social.caption_hint'),
                        hintStyle: AppFonts.poppins(
                          color: Colors.white38,
                          fontSize: 18,
                        ),
                        border: InputBorder.none,
                        counterStyle: AppFonts.poppins(
                          color: Colors.white30,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  // Media Grid
                  if (_media.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _media.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                        itemBuilder: (context, index) {
                          final item = _media[index];
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: item.isVideo
                                    ? ColoredBox(
                                        color: const Color(0xFF161618),
                                        child: Center(
                                          child: Icon(
                                            PhosphorIcons.playFill,
                                            color: Colors.white.withValues(alpha: 0.85),
                                            size: 32,
                                          ),
                                        ),
                                      )
                                    : Image.memory(
                                        item.bytes,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(() => _media.removeAt(index)),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      PhosphorIcons.x,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              if (item.isVideo)
                                Positioned(
                                  bottom: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      PhosphorIcons.videoCamera,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF161618),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Text(
                      context.tr('social.add_media'),
                      style: AppFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    _buildBottomAction(
                      icon: PhosphorIcons.imageFill,
                      color: const Color(0xFF48BB78),
                      onTap: _showPhotoSourceSheet,
                    ),
                    _buildBottomAction(
                      icon: PhosphorIcons.cameraFill,
                      color: const Color(0xFF4299E1),
                      onTap: () => _handlePickAction(_PickAction.cameraPhoto),
                    ),
                    _buildBottomAction(
                      icon: PhosphorIcons.videoCameraFill,
                      color: const Color(0xFFED8936),
                      onTap: _showVideoSourceSheet,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_isCompressing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.65),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222228),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        context.tr('social.compressing_video'),
                        style: AppFonts.poppins(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  ),
);
  }
}

enum _PickAction { gallery, cameraPhoto, cameraVideo, galleryVideo }
