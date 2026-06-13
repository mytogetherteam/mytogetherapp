import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../food/presentation/screens/food_search_page.dart';
import '../../data/models/master_category_dto.dart';
import '../../data/repositories/restaurant_repository.dart';
import 'image_skeleton_loader.dart';

/// Horizontal rail of the platform's most-ordered master categories from
/// `GET /api/user/master-menu-categories/popular`. Tapping a category opens
/// the food search seeded with that category's name.
class PopularCategoriesSection extends StatefulWidget {
  const PopularCategoriesSection({super.key});

  @override
  State<PopularCategoriesSection> createState() =>
      _PopularCategoriesSectionState();
}

class _PopularCategoriesSectionState extends State<PopularCategoriesSection> {
  late Future<List<MasterCategoryDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MasterCategoryDto>> _load() async {
    if (!AuthService().isLoggedIn) return [];
    try {
      return await RestaurantRepository.instance
          .getPopularMasterCategories(limit: 12)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return [];
    }
  }

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http') || path.startsWith('assets/')) return path;
    return '${ApiClient.baseUrl}/$path';
  }

  void _openCategory(MasterCategoryDto category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodSearchPage(
          initialQuery: category.displayName,
          initialMasterCategoryId: category.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MasterCategoryDto>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }
        final categories = snapshot.data ?? [];
        if (categories.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                context.tr('food.popular_categories'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 104,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return _buildCategoryItem(cat);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildCategoryItem(MasterCategoryDto cat) {
    final url = _imageUrl(cat.imageUrl);
    return GestureDetector(
      onTap: () => _openCategory(cat),
      child: Container(
        width: 76,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: url.isEmpty
                  ? Icon(PhosphorIcons.forkKnife,
                      color: Colors.grey[400], size: 28)
                  : CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          const ImageSkeletonLoader(width: 68, height: 68),
                      errorWidget: (_, _, _) => Icon(
                        PhosphorIcons.forkKnife,
                        color: Colors.grey[400],
                        size: 28,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              cat.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const ImageSkeletonLoader(width: 150, height: 20),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (_, _) => Container(
              width: 76,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  ClipOval(
                    child: const ImageSkeletonLoader(width: 68, height: 68),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const ImageSkeletonLoader(width: 50, height: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

