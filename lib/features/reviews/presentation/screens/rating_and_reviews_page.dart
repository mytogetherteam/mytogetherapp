import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../data/review_demo_data.dart';
import '../widgets/rating_progress_bar.dart';
import '../widgets/review_filter_chip.dart';
import '../widgets/tiktok_style_review_card.dart';
import '../widgets/skeleton_review_card.dart';
import 'write_review_page.dart';

class RatingAndReviewsPage extends StatefulWidget {
  const RatingAndReviewsPage({super.key});

  @override
  State<RatingAndReviewsPage> createState() => _RatingAndReviewsPageState();
}

class _RatingAndReviewsPageState extends State<RatingAndReviewsPage> {
  bool _isLoading = true;
  int _selectedFilterIndex = 0;

  final List<Map<String, dynamic>> _filters = [
    {'label': '📷 Photos/videos (26)', 'key': 'photos'},
    {'label': '⭐ 5 (121)', 'key': '5_star'},
    {'label': '⭐ 4 (4)', 'key': '4_star'},
    {'label': '⭐ 3 (1)', 'key': '3_star'},
    {'label': 'Follow-up reviews (1)', 'key': 'follow_up'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Ratings and Reviews',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100), // Space for sticky button
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Rating Summary
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer ratings & reviews',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B), // Dark slate blue matching the image
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '4.6',
                              style: GoogleFonts.poppins(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'out of 5',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                for (int i = 0; i < 4; i++)
                                  const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 24),
                                const Icon(Icons.star_half_rounded, color: Color(0xFFFFC107), size: 24),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '9,615 ratings',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Progress Bars
                        const RatingProgressBar(starCount: 5, percentage: 0.82, percentageText: '82%', countText: '7,971'),
                        const RatingProgressBar(starCount: 4, percentage: 0.08, percentageText: '8%', countText: '861'),
                        const RatingProgressBar(starCount: 3, percentage: 0.02, percentageText: '2%', countText: '241'),
                        const RatingProgressBar(starCount: 2, percentage: 0.00, percentageText: '0%', countText: '80'),
                        const RatingProgressBar(starCount: 1, percentage: 0.04, percentageText: '4%', countText: '462'),
                      ],
                    ),
                  ),
                  
                  // Divider
                  Divider(color: Colors.grey[200], thickness: 8),

                  // Section 2: Filter Tag Pills
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: _filters.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              return ReviewFilterChip(
                                label: _filters[index]['label'],
                                isSelected: _selectedFilterIndex == index,
                                onTap: () {
                                  setState(() {
                                    _selectedFilterIndex = index;
                                    // Normally this would trigger a reload with the new filter
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Authentic reviews from real customers',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Newest',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down, size: 18),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Section 3: Review List (TikTok-style)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _isLoading
                        ? Column(
                            children: List.generate(3, (index) => const SkeletonReviewCard()),
                          )
                        : Column(
                            children: ReviewDemoData.reviews
                                .map((review) => TiktokStyleReviewCard(review: review))
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
          
          // Section 4: Sticky "Write a Review" Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SafeArea(
                child: PrimaryGradientButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WriteReviewPage(),
                      ),
                    );
                  },
                  child: Text(
                    'Write a Review',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
