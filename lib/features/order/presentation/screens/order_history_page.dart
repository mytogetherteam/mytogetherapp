import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/features/order/data/models/order_history_dto.dart';
import 'package:mytogetherapp/features/order/data/repositories/order_repository.dart';
import 'package:mytogetherapp/features/order/presentation/widgets/order_history_card.dart';
import 'package:mytogetherapp/features/reviews/data/repositories/shop_review_repository.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import 'package:mytogetherapp/core/utils/navigation_controller.dart';
import 'package:mytogetherapp/core/presentation/widgets/notification_bell.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_text.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';

class OrderHistoryPage extends StatefulWidget {
  final int? shopId;
  // 0 = Completed tab, 1 = Cancelled tab.
  final int initialTabIndex;
  const OrderHistoryPage({super.key, this.shopId, this.initialTabIndex = 0});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  TabController? _tabController;
  List<OrderHistoryDto> _completedOrders = [];
  List<OrderHistoryDto> _cancelledOrders = [];
  Map<int, double> _shopRatings = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Server-side filtering via `?status=` (see UserOrdersController). The
    // backend enum spells it `CANCELED` (single L).
    final results = await Future.wait([
      OrderRepository().getOrderHistory(
        statuses: const ['DELIVERED'],
        shopId: widget.shopId,
      ),
      OrderRepository().getOrderHistory(
        statuses: const ['CANCELED'],
        shopId: widget.shopId,
      ),
    ]);

    if (mounted) {
      setState(() {
        _completedOrders = results[0];
        _cancelledOrders = results[1];
        _isLoading = false;
        _initTabController();
      });
      await _loadShopRatings(results[0]);
    }
  }

  Future<void> _loadShopRatings(List<OrderHistoryDto> orders) async {
    final shopIds = orders
        .where((o) => o.shopId != null)
        .map((o) => o.shopId!)
        .toSet();
    if (shopIds.isEmpty) {
      if (mounted) setState(() => _shopRatings = {});
      return;
    }

    final entries = await Future.wait(shopIds.map((id) async {
      try {
        final reviews = await ShopReviewRepository.instance.getMyReviews(
          shopId: id,
          size: 1,
        );
        if (reviews.isNotEmpty) {
          return MapEntry(id, reviews.first.rating);
        }
      } catch (_) {}
      return null;
    }));

    if (!mounted) return;
    setState(() {
      _shopRatings = {
        for (final entry in entries)
          if (entry != null) entry.key: entry.value,
      };
    });
  }

  void _initTabController() {
    if (_tabController != null) {
      _tabController!.dispose();
    }

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/app_icon_small.png',
              height: 28,
            ),
            const SizedBox(width: 12),
            Transform.translate(
              offset: const Offset(0, 4), // Nudge text down to align visually
              child: Text(
                context.tr('orders.history'),
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: LocaleController.instance.language.code == 'mm' ? 18 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: NotificationBell(),
          ),
        ],
        bottom: _isLoading
            ? null
            : TabBar(
                controller: _tabController,
                indicator: const _GradientTabIndicator(
                  height: 3.0,
                  gradient: AppColors.primaryGradient,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                tabs: [
                  Tab(
                    child: AnimatedBuilder(
                      animation: _tabController!,
                      builder: (context, _) {
                        final isSelected = _tabController!.index == 0;
                        return isSelected
                            ? GradientText(context.tr('orders.completed'))
                            : Text(
                                context.tr('orders.completed'),
                                style: GoogleFonts.poppins(
                                    color: Colors.grey, fontWeight: FontWeight.w600),
                              );
                      },
                    ),
                  ),
                  Tab(
                    child: AnimatedBuilder(
                      animation: _tabController!,
                      builder: (context, _) {
                        final isSelected = _tabController!.index == 1;
                        return isSelected
                            ? GradientText(context.tr('orders.cancelled'))
                            : Text(
                                context.tr('orders.cancelled'),
                                style: GoogleFonts.poppins(
                                    color: Colors.grey, fontWeight: FontWeight.w600),
                              );
                      },
                    ),
                  ),
                ],
              ),
      ),
      body: _isLoading
          ? _buildSkeletonLoading()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(_completedOrders, context.tr('orders.no_completed')),
                _buildOrdersList(_cancelledOrders, context.tr('orders.no_cancelled')),
              ],
            ),
    );
  }

  Widget _buildOrdersList(List<OrderHistoryDto> orders, String emptyTitle) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildEmptyState(emptyTitle),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return OrderHistoryCard(
            order: orders[index],
            shopRating: orders[index].shopId != null
                ? _shopRatings[orders[index].shopId!]
                : null,
            onReviewSubmitted: _loadData,
          );
        },
      ),
    );
  }

  void _goToOrdering() {
    NavigationController.instance.goToFoodTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildEmptyState(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration Placeholder
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('orders.no_orders'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('orders.start_ordering_desc'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryGradientButton(
              width: 220,
              onPressed: _goToOrdering,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.restaurant_menu, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('orders.start_ordering'),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      itemCount: 3,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 120, height: 16, color: Colors.grey[200]),
                    const Spacer(),
                    Container(width: 60, height: 16, color: Colors.grey[200]),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const Spacer(),
                    Container(width: 80, height: 16, color: Colors.grey[200]),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 100, height: 14, color: Colors.grey[200]),
                    Container(
                      width: 100,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GradientTabIndicator extends Decoration {
  final double height;
  final Gradient gradient;

  const _GradientTabIndicator({
    this.height = 3.0,
    required this.gradient,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _GradientPainter(this, onChanged);
  }
}

class _GradientPainter extends BoxPainter {
  final _GradientTabIndicator decoration;

  _GradientPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    if (configuration.size == null) return;
    final Rect rect = Offset(
            offset.dx, configuration.size!.height - decoration.height) &
        Size(configuration.size!.width, decoration.height);
    final Paint paint = Paint()..shader = decoration.gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }
}
