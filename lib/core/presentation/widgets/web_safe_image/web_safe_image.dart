import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

import 'web_safe_image_stub.dart'
    if (dart.library.html) 'web_safe_image_web.dart';

class WebSafeImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const WebSafeImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Use HtmlElementView on web to bypass CanvasKit CORS completely
      return buildWebImage(imageUrl, fit);
    }
    
    // On mobile, use CachedNetworkImage since CORS is not an issue
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      errorWidget: (context, url, error) => Container(
        color: AppColors.primary,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, color: Colors.white),
      ),
    );
  }
}
