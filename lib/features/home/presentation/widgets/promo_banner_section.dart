import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../data/models/banner_image_dto.dart';
import '../../data/repositories/restaurant_repository.dart';
import 'image_skeleton_loader.dart';

/// Auto-scrolling promotional banner carousel with a dots indicator, matching
/// the banner shown on the Home tab. Fetches banners for [position] and hides
/// itself entirely when none are available.
class PromoBannerSection extends StatefulWidget {
  final String position;
  final double height;

  const PromoBannerSection({
    super.key,
    this.position = 'Ads',
    this.height = 200,
  });

  @override
  State<PromoBannerSection> createState() => _PromoBannerSectionState();
}

class _PromoBannerSectionState extends State<PromoBannerSection> {
  late final PageController _controller;
  Timer? _timer;
  List<BannerImageDto> _banners = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: 10000);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_controller.hasClients && _banners.isNotEmpty) {
        _controller.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
    _fetchBanners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchBanners() async {
    try {
      final banners = await RestaurantRepository.instance.getBanners(
        position: widget.position,
      );
      if (mounted) {
        setState(() {
          _banners = banners;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _resolveUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http') || path.startsWith('assets/')) return path;
    return '${ApiClient.baseUrl}/$path';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          SizedBox(
            height: widget.height,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) {
                  if (_banners.isEmpty) return;
                  setState(() => _currentIndex = index % _banners.length);
                },
                itemBuilder: (context, index) {
                  if (_isLoading) {
                    return const ImageSkeletonLoader(showLogo: true);
                  }
                  final banner = _banners[index % _banners.length];
                  return CachedNetworkImage(
                    imageUrl: _resolveUrl(banner.imageUrl),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) =>
                        const ImageSkeletonLoader(showLogo: true),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.primary,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_isLoading && _banners.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _banners.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
