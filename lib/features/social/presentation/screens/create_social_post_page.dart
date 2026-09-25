import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/media/picked_image.dart';
import '../../../../core/media/image_crop_helper.dart';
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

  bool get _canPublish =>
      _media.isNotEmpty || _captionController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _captionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocus.dispose();
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
          final file = await _picker.pickImage(
              source: ImageSource.gallery, imageQuality: 85);
          if (file != null) {
            final cropped = await ImageCropHelper.crop(file);
            if (cropped != null) picked.add(cropped);
          }
          break;
        case _PickAction.cameraPhoto:
          final file = await _picker.pickImage(
              source: ImageSource.camera, imageQuality: 85);
          if (file != null) {
            final cropped = await ImageCropHelper.crop(file);
            if (cropped != null) picked.add(cropped);
          }
          break;
        case _PickAction.cameraVideo:
          final file = await _picker.pickVideo(
              source: ImageSource.camera,
              maxDuration: const Duration(seconds: 60));
          if (file != null) picked.add(file);
          break;
      }
      for (final file in picked) {
        _media.add(await PickedImage.fromXFile(file));
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
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
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppDialog.showToast(context, context.tr('social.publish_failed'),
          isError: true);
    }
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
            style: GoogleFonts.poppins(
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
                          style: GoogleFonts.poppins(
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
        body: Column(
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
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.45,
                      ),
                      decoration: InputDecoration(
                        hintText: context.tr('social.caption_hint'),
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 18,
                        ),
                        border: InputBorder.none,
                        counterStyle: GoogleFonts.poppins(
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
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    _buildBottomAction(
                      icon: PhosphorIcons.imageFill,
                      color: const Color(0xFF48BB78),
                      onTap: () => _handlePickAction(_PickAction.gallery),
                    ),
                    _buildBottomAction(
                      icon: PhosphorIcons.cameraFill,
                      color: const Color(0xFF4299E1),
                      onTap: () => _handlePickAction(_PickAction.cameraPhoto),
                    ),
                    _buildBottomAction(
                      icon: PhosphorIcons.videoCameraFill,
                      color: const Color(0xFFED8936),
                      onTap: () => _handlePickAction(_PickAction.cameraVideo),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PickAction { gallery, cameraPhoto, cameraVideo }
