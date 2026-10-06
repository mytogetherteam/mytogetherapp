import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:mytogetherapp/app.dart';

import 'post_share_link.dart';
import 'presentation/screens/shared_post_page.dart';

/// Opens a shared post when the phone hands the app a `/p/:id` link.
class PostLinkListener {
  PostLinkListener._();

  static final PostLinkListener instance = PostLinkListener._();

  StreamSubscription<Uri>? _subscription;
  int? _lastPostId;
  DateTime? _lastAt;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) unawaited(_open(initial));
    } catch (_) {}
    _subscription = appLinks.uriLinkStream.listen(
      (uri) => unawaited(_open(uri)),
      onError: (_) {},
    );
  }

  Future<void> _open(Uri uri) async {
    final id = postIdFromShareLink(uri);
    if (id == null) return;
    final now = DateTime.now();
    if (_lastPostId == id &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastPostId = id;
    _lastAt = now;
    _navigateWhenReady((nav) {
      nav.push(
        MaterialPageRoute(builder: (_) => SharedPostPage(postId: id)),
      );
    });
  }

  void _navigateWhenReady(
    void Function(NavigatorState nav) action, {
    int attempts = 0,
  }) {
    final nav = App.navigatorKey.currentState;
    if (nav != null && nav.mounted) {
      Future.delayed(const Duration(milliseconds: 400), () {
        final ready = App.navigatorKey.currentState;
        if (ready != null) action(ready);
      });
      return;
    }
    if (attempts >= 60) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      _navigateWhenReady(action, attempts: attempts + 1);
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
