import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/features/home/data/models/banner_image_dto.dart';
import 'package:mytogetherapp/features/home/data/repositories/restaurant_repository.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/image_skeleton_loader.dart';

class FoodPromotionsCarousel extends StatefulWidget {
  const FoodPromotionsCarousel({super.key});

  @override
  State<FoodPromotionsCarousel> createState() => _FoodPromotionsCarouselState();
}

class _FoodPromotionsCarouselState extends State<FoodPromotionsCarousel> {
  final PageController _controller = PageController(viewportFraction: 1.0);
  List<BannerImageDto> _banners = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (_banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_controller.hasClients) {
        final nextPage = _controller.page!.round() + 1;
        _controller.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchBanners() async {
    try {
      final banners = await RestaurantRepository.instance.getBanners(
        position: 'Promotions',
      );
      if (mounted) {
        setState(() {
          _banners = banners;
          _isLoading = false;
        });
        _startAutoPlay();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getImageUrl(String path) {
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return '${ApiClient.baseUrl}$path';
    return '${ApiClient.baseUrl}/$path';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _banners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) {
                  if (_banners.isEmpty) return;
                  setState(() {
                    _currentIndex = index % _banners.length;
                  });
                },
                itemBuilder: (context, index) {
                  if (_isLoading) {
                    return const ImageSkeletonLoader(showLogo: true);
                  }
                  final realIndex = index % _banners.length;
                  final banner = _banners[realIndex];
                  final image = banner.image;
                  
                  if (image.startsWith('assets/')) {
                    return Image.asset(image, fit: BoxFit.cover, width: double.infinity);
                  }
                  return CachedNetworkImage(
                    imageUrl: _getImageUrl(image),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const ImageSkeletonLoader(showLogo: true),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.primary,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, color: Colors.white),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Dots Indicator
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
