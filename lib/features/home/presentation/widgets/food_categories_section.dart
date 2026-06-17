import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/image_skeleton_loader.dart';
import 'package:mytogetherapp/features/home/data/models/master_category_dto.dart';
import 'package:mytogetherapp/features/home/data/models/shop_dto.dart';
import 'package:mytogetherapp/features/home/data/repositories/restaurant_repository.dart';
import 'package:mytogetherapp/features/food/presentation/screens/food_search_page.dart';

class FoodCategoriesSection extends StatefulWidget {
  const FoodCategoriesSection({super.key});

  @override
  State<FoodCategoriesSection> createState() => _FoodCategoriesSectionState();
}

class _FoodCategoriesSectionState extends State<FoodCategoriesSection> {
  List<MasterCategoryDto> _categories = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await RestaurantRepository.instance
          .getPopularMasterCategories(limit: 20)
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && _categories.isNotEmpty) {
            final int middleIndex = _categories.length ~/ 2;
            // Jump to the middle item. Each item has 96.0 width extent.
            _scrollController.jumpTo(middleIndex * 96.0);
          }
        });
      }
    } catch (e) {
      debugPrint('[FoodCategoriesSection] Error loading categories: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _categoryImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http') || path.startsWith('assets/')) return path;
    return 'https://dev.api.mytogether.work/$path';
  }

  void _onCategoryTap(MasterCategoryDto category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodSearchPage(
          initialMasterCategoryId: category.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Landing screen style background circle
          Positioned(
            top: 40,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.5,
              height: MediaQuery.of(context).size.width * 1.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.015),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  width: 60,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 136,
            child: _isLoading
                ? _buildSkeletonList()
                : AnimatedBuilder(
                    animation: _scrollController,
                    builder: (context, child) {
                      final double viewportWidth = MediaQuery.of(context).size.width;
                      final double scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
                      
                      return ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(
                          horizontal: (viewportWidth - 72) / 2, // Center first and last items
                        ),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final imageUrl = _categoryImageUrl(category.imageUrl);
                          
                          // Calculate distance from center
                          double itemCenterScrollOffset = index * 96.0; // 80 width + 16 right margin
                          double distanceFromCenter = itemCenterScrollOffset - scrollOffset;
                          
                          // Normalize distance to calculate curve and scale
                          double normalizedDistance = (distanceFromCenter / 180.0).clamp(-1.0, 1.0);
                          
                          // Parabola for Y translation
                          double translateY = normalizedDistance * normalizedDistance * 30.0; 
                          // Scale down edges
                          double scale = 1.0 - (normalizedDistance.abs() * 0.25);
                          
                          return Transform.translate(
                            offset: Offset(0, translateY),
                            child: Transform.scale(
                              scale: scale,
                              child: GestureDetector(
                                onTap: () => _onCategoryTap(category),
                                child: Container(
                                  width: 80,
                                  margin: const EdgeInsets.only(right: 16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary.withValues(alpha: 0.15),
                                            AppColors.secondary.withValues(alpha: 0.15),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: imageUrl.isEmpty
                                            ? ShaderMask(
                                                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                                                child: const Icon(
                                                  PhosphorIcons.forkKnife,
                                                  size: 28,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : CachedNetworkImage(
                                                fadeInDuration: Duration.zero,
                                                fadeOutDuration: Duration.zero,
                                                imageUrl: imageUrl,
                                                fit: BoxFit.cover,
                                                placeholder: (_, _) => const ImageSkeletonLoader(
                                                  width: 72,
                                                  height: 72,
                                                ),
                                                errorWidget: (_, _, _) => ShaderMask(
                                                  shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                                                  child: const Icon(
                                                    PhosphorIcons.forkKnife,
                                                    size: 28,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        category.displayName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[800],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 6, // Show 6 skeleton items
      itemBuilder: (context, index) {
        return Container(
          width: 80,
          margin: const EdgeInsets.only(right: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 50,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
