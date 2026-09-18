import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/media/picked_image.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_splash_factory.dart';
import '../../data/repositories/social_posts_repository.dart';

class CreateSocialPostPage extends StatefulWidget {
  const CreateSocialPostPage({super.key});

  @override
  State<CreateSocialPostPage> createState() => _CreateSocialPostPageState();
}

class _CreateSocialPostPageState extends State<CreateSocialPostPage> {
  final _captionController = TextEditingController();
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
    super.dispose();
  }

  Future<void> _addMedia() async {
    if (_media.length >= 10) {
      AppDialog.showToast(context, context.tr('social.max_media'), isError: true);
      return;
    }

    final action = await showModalBottomSheet<_PickAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('social.add_media'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(PhosphorIcons.images),
              title: Text(context.tr('social.pick_gallery')),
              onTap: () => Navigator.pop(ctx, _PickAction.gallery),
            ),
            ListTile(
              leading: const Icon(PhosphorIcons.camera),
              title: Text(context.tr('social.take_photo')),
              onTap: () => Navigator.pop(ctx, _PickAction.cameraPhoto),
            ),
            ListTile(
              leading: const Icon(PhosphorIcons.videoCamera),
              title: Text(context.tr('social.record_video')),
              onTap: () => Navigator.pop(ctx, _PickAction.cameraVideo),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null) return;

    try {
      final remaining = 10 - _media.length;
      final picked = <XFile>[];
      switch (action) {
        case _PickAction.gallery:
          final files = await _picker.pickMultipleMedia(imageQuality: 85);
          picked.addAll(files.take(remaining));
          break;
        case _PickAction.cameraPhoto:
          final file = await _picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
          );
          if (file != null) picked.add(file);
          break;
        case _PickAction.cameraVideo:
          final file = await _picker.pickVideo(
            source: ImageSource.camera,
            maxDuration: const Duration(seconds: 60),
          );
          if (file != null) picked.add(file);
          break;
      }

      for (final file in picked) {
        _media.add(await PickedImage.fromXFile(file));
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('social.pick_failed'),
          isError: true,
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_canPublish) {
      AppDialog.showToast(
        context,
        context.tr('social.media_required'),
        isError: true,
      );
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
      AppDialog.showToast(
        context,
        context.tr('social.publish_failed'),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(
          context.tr('social.create_post'),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _submitting || !_canPublish ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      context.tr('social.publish'),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: _canPublish
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _captionController,
            maxLines: 4,
            maxLength: 5000,
            decoration: InputDecoration(
              hintText: context.tr('social.caption_hint'),
              border: InputBorder.none,
              hintStyle: GoogleFonts.poppins(color: Colors.black38),
            ),
            style: GoogleFonts.poppins(fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _media.length + (_media.length < 10 ? 1 : 0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              if (index == _media.length) {
                return InkWell(
                  onTap: _addMedia,
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.plus, color: Colors.grey.shade600),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('social.add_media'),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final item = _media[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item.isVideo
                        ? ColoredBox(
                            color: Colors.black87,
                            child: Center(
                              child: Icon(
                                PhosphorIcons.playFill,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: 28,
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
                          color: Colors.black54,
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
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('social.create_help'),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PickAction { gallery, cameraPhoto, cameraVideo }
