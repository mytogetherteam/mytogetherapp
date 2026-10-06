import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../data/models/post_dto.dart';
import '../../data/repositories/social_posts_repository.dart';
import 'social_page.dart';

/// Opens one post from a share link, after the phone has handed the link to the app.
class SharedPostPage extends StatefulWidget {
  final int postId;

  const SharedPostPage({super.key, required this.postId});

  @override
  State<SharedPostPage> createState() => _SharedPostPageState();
}

class _SharedPostPageState extends State<SharedPostPage> {
  SocialPostDto? _post;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final post =
          await SocialPostsRepository.instance.fetchOne(widget.postId);
      if (!mounted) return;
      if (post == null) {
        setState(() => _failed = true);
        return;
      }
      setState(() => _post = post);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    if (post != null) return SocialPostViewerPage(post: post);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: _failed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('social.post_unavailable'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.tr('common.back')),
                      ),
                    ],
                  ),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
      ),
    );
  }
}
