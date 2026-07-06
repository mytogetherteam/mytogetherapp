import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/presentation/widgets/gradient_icon.dart';
import '../../../../core/auth/guest_auth_guard.dart';
import '../../../reviews/presentation/screens/write_review_page.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/shop_review_dto.dart';

class RestaurantReviewsPage extends StatefulWidget {
  final int shopId;
  final String restaurantName;

  const RestaurantReviewsPage({
    super.key,
    required this.shopId,
    required this.restaurantName,
  });

  @override
  State<RestaurantReviewsPage> createState() => _RestaurantReviewsPageState();
}

class _RestaurantReviewsPageState extends State<RestaurantReviewsPage>
    with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 45);

  late Future<List<ShopReviewDto>> _reviewsFuture;
  late Future<ShopReviewSummaryDto> _summaryFuture;
  Timer? _pollTimer;
  ShopReviewSummaryDto? _cachedSummary;
  List<ShopReviewDto> _cachedReviews = const [];
  List<String> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBlockedUsers().then((_) {
      _loadData();
      _startPolling();
    });
  }

  Future<void> _loadBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _blockedUsers = prefs.getStringList('blocked_review_users') ?? [];
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollForUpdates();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollForUpdates());
  }

  Future<void> _pollForUpdates() async {
    if (!mounted) return;
    try {
      final summary =
          await RestaurantRepository.instance.getShopReviewSummary(widget.shopId);
      final reviews =
          await RestaurantRepository.instance.getShopReviews(widget.shopId);
      if (!mounted) return;

      final countChanged =
          summary.totalCount != (_cachedSummary?.totalCount ?? -1);
      final listChanged = reviews.isNotEmpty &&
          (_cachedReviews.isEmpty || reviews.first.id != _cachedReviews.first.id);

      if (countChanged || listChanged) {
        setState(() {
          _cachedSummary = summary;
          _cachedReviews = reviews;
          _summaryFuture = Future.value(summary);
          _reviewsFuture = Future.value(reviews);
        });
      }
    } catch (_) {}
  }

  void _loadData() {
    _reviewsFuture = RestaurantRepository.instance.getShopReviews(
      widget.shopId,
    );
    _summaryFuture = RestaurantRepository.instance.getShopReviewSummary(
      widget.shopId,
    );
    _reviewsFuture.then((reviews) {
      if (mounted) setState(() => _cachedReviews = reviews);
    });
    _summaryFuture.then((summary) {
      if (mounted) setState(() => _cachedSummary = summary);
    });
  }

  Future<void> _writeReview() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;
    if (!mounted) return;
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WriteReviewPage(
          shopId: widget.shopId,
          shopName: widget.restaurantName,
        ),
      ),
    );
    if (submitted == true && mounted) {
      setState(_loadData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Very light gray background
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: _writeReview,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.rate_review_outlined, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('review.write_title'),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('restaurant.reviews'),
          style: GoogleFonts.poppins(
            color: const Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[100], height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loadData();
          });
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('review.customer_ratings'),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSummaryHeader(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildReviewsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return FutureBuilder<ShopReviewSummaryDto>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) return const SizedBox.shrink();

        final summary = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  summary.averageRating.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('review.out_of_5'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < summary.averageRating.round()
                          ? Icons.star_rounded
                          : Icons.star_rounded,
                      color: index < summary.averageRating.round()
                          ? Colors.amber
                          : Colors.grey[200],
                      size: 28,
                    );
                  }),
                ),
              ],
            ),
            Text(
              context.trArgs('review.ratings_count',
                  {'count': '${summary.totalCount}'}),
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            // Rating Bars
            for (int i = 5; i >= 1; i--)
              _buildRatingBar(
                i,
                summary.ratingStats[i] ?? 0,
                summary.totalCount,
              ),
          ],
        );
      },
    );
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final double percentage = total > 0 ? count / total : 0.0;
    final int percentInt = (percentage * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              context.trArgs('review.stars_count', {'count': '$stars'}),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              '$percentInt% ($count)',
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return FutureBuilder<List<ShopReviewDto>>(
      future: _reviewsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final allReviews = snapshot.data ?? [];
        final reviews = allReviews.where((r) => !_blockedUsers.contains(r.userName)).toList();
        if (reviews.isEmpty) return _buildEmptyState();

        return Column(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  context.tr('review.recent'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
            ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                return _buildReviewItem(review);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 60),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const GradientIcon(
                icon: Icons.rate_review_outlined,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('review.empty_title'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('review.empty_sub'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reviewer avatar: shows the user's profile photo when available, otherwise
  /// falls back to a generic person icon on a tinted circle.
  Widget _buildReviewerAvatar(ShopReviewDto review) {
    const double size = 44;
    final url = review.userProfileUrl?.trim();
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person_outline, color: AppColors.primary, size: 24),
    );

    if (url == null || url.isEmpty || !url.startsWith('http')) {
      return placeholder;
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => placeholder,
        fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
        memCacheWidth: 200,
      ),
    );
  }

  Widget _buildReviewItem(ShopReviewDto review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildReviewerAvatar(review),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  review.userName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'report') {
                    _handleReport(review);
                  } else if (value == 'block') {
                    _handleBlock(review);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Text(context.tr('news.report_post') != 'news.report_post' ? context.tr('news.report_post') : 'Report Review'),
                  ),
                  PopupMenuItem<String>(
                    value: 'block',
                    child: Text(
                      context.tr('news.block_user') != 'news.block_user' ? context.tr('news.block_user') : 'Block User',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: index < review.rating.round()
                        ? Colors.amber
                        : Colors.grey[300],
                    size: 20,
                  );
                }),
              ),
              const SizedBox(width: 12),
              Text(
                _getTimeAgo(review.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment ?? context.tr('review.no_comment'),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF475569),
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (review.hasShopReply) _buildShopReply(review),
        ],
      ),
    );
  }

  /// Small circular badge for the reply: shows the admin/shop logo when
  /// available, otherwise a tinted storefront icon.
  Widget _buildShopReplyAvatar(ShopReviewDto review) {
    const double size = 32;
    final url = review.shopReplyAvatarUrl?.trim();
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.storefront_outlined,
        size: 18,
        color: AppColors.primary,
      ),
    );

    if (url == null || url.isEmpty || !url.startsWith('http')) {
      return fallback;
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => fallback,
        errorWidget: (context, url, error) => fallback,
        fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
        memCacheWidth: 150,
      ),
    );
  }

  /// Read-only shop owner reply shown under a review. Customers can see the
  /// owner's response but cannot reply back (one-way conversation).
  Widget _buildShopReply(ShopReviewDto review) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildShopReplyAvatar(review),
              const SizedBox(width: 8),
              Flexible(
                child: GradientText(
                  review.shopReplyAuthorName?.trim().isNotEmpty == true
                      ? review.shopReplyAuthorName!.trim()
                      : context.tr('review.shop_reply'),
                  gradient: AppColors.primaryGradient,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (review.shopRepliedAt != null)
                Text(
                  _getTimeAgo(review.shopRepliedAt!),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.shopReply!.trim(),
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              color: const Color(0xFF475569),
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    return context.relativeTime(dateTime);
  }

  void _handleReport(ShopReviewDto review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('news.report_post') != 'news.report_post' ? context.tr('news.report_post') : 'Report Review', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(context.tr('news.report_confirm') != 'news.report_confirm' ? context.tr('news.report_confirm') : 'Are you sure you want to report this content?', style: GoogleFonts.poppins(fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel'), style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('news.reported_success') != 'news.reported_success' ? context.tr('news.reported_success') : 'Reported successfully.', style: GoogleFonts.poppins(color: Colors.white)),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(context.tr('news.report_action') != 'news.report_action' ? context.tr('news.report_action') : 'Report', style: GoogleFonts.poppins(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleBlock(ShopReviewDto review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('news.block_user') != 'news.block_user' ? context.tr('news.block_user') : 'Block User', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
        content: Text(context.tr('news.block_confirm') != 'news.block_confirm' ? context.tr('news.block_confirm') : 'Are you sure you want to block this user? You will no longer see their posts.', style: GoogleFonts.poppins(fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel'), style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final messenger = ScaffoldMessenger.of(context);
              final blockedMessage = context.tr('news.blocked_success') !=
                      'news.blocked_success'
                  ? context.tr('news.blocked_success')
                  : 'User blocked.';

              // Block the user locally
              final prefs = await SharedPreferences.getInstance();
              final currentBlocked =
                  prefs.getStringList('blocked_review_users') ?? [];
              if (!currentBlocked.contains(review.userName)) {
                currentBlocked.add(review.userName);
                await prefs.setStringList(
                  'blocked_review_users',
                  currentBlocked,
                );
              }

              if (!mounted) return;
              setState(() {
                _blockedUsers = currentBlocked;
              });
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    blockedMessage,
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor: Colors.grey[800],
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(context.tr('news.block_action') != 'news.block_action' ? context.tr('news.block_action') : 'Block', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}




