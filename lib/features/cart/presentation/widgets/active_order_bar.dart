import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/notifications/order_tracker_channel.dart';
import '../../data/active_order_state.dart';
import '../screens/order_status_page.dart';
import '../screens/awaiting_payment_page.dart';
import '../screens/order_complete_page.dart';
import '../screens/order_tracking_page.dart';
import '../../data/cart_manager.dart';
import '../screens/revise_order_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_formatter.dart';

class ActiveOrderBar extends StatefulWidget {
  final int? shopId;
  const ActiveOrderBar({super.key, this.shopId});

  @override
  State<ActiveOrderBar> createState() => _ActiveOrderBarState();
}

class _ActiveOrderBarState extends State<ActiveOrderBar>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressCtrl;
  late AnimationController _dotCtrl;
  late AnimationController _slideCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<Offset> _slideAnim;
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    // ... existing dot/slide controllers
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _slideCtrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 600),
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed) {
            if (mounted) setState(() {});
          }
        });
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    final state = ActiveOrderState.instance;
    bool isActive;
    if (widget.shopId != null) {
      isActive = state.activeOrdersList.any(
        (o) => o.shopId == widget.shopId?.toString(),
      );
    } else {
      isActive = state.hasActiveOrder;
    }

    if (isActive) {
      _wasActive = true;
      _progressCtrl.repeat();
      _slideCtrl.forward();
      _shimmerCtrl.forward(from: 0);
    }

    ActiveOrderState.instance.addListener(_handleStateChange);
  }

  void _handleStateChange() {
    if (mounted) {
      final state = ActiveOrderState.instance;
      bool isActive;

      if (widget.shopId != null) {
        isActive = state.activeOrdersList.any(
          (o) => o.shopId == widget.shopId?.toString(),
        );
      } else {
        isActive = state.hasActiveOrder;
      }

      if (isActive && !_wasActive) {
        _progressCtrl.reset();
        _progressCtrl.repeat();
        _slideCtrl.forward(from: 0);
        _shimmerCtrl.forward(from: 0);
      } else if (!isActive && _wasActive) {
        _progressCtrl.stop();
        _progressCtrl.reset();
        _slideCtrl.reverse();
        _shimmerCtrl.stop();
        OrderTrackerChannel.stopTracker();
      }
      
      if (isActive && state.activeOrdersList.isNotEmpty) {
        final order = widget.shopId != null 
          ? state.activeOrdersList.firstWhere((o) => o.shopId == widget.shopId?.toString())
          : state.activeOrdersList.first;
        
        OrderTrackerChannel.startOrUpdateTracker(
          shopName: order.displayShopName.isNotEmpty ? order.displayShopName : 'Restaurant',
          statusText: _getStatusText(context, order),
          step: order.orderStatus,
        );
      }
      
      _wasActive = isActive;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    ActiveOrderState.instance.removeListener(_handleStateChange);
    _progressCtrl.dispose();
    _dotCtrl.dispose();
    _slideCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ActiveOrderState.instance, _slideCtrl]),
      builder: (context, _) {
        final state = ActiveOrderState.instance;
        var orders = state.activeOrdersList;

        // Filter by shopId if provided
        if (widget.shopId != null) {
          orders = orders
              .where((o) => o.shopId == widget.shopId?.toString())
              .toList();
        }

        if (orders.isEmpty && _slideCtrl.isDismissed) {
          return const SizedBox.shrink();
        }

        if (orders.isEmpty && !_slideCtrl.isDismissed) {
          _slideCtrl.reverse();
        }

        return SizeTransition(
          sizeFactor: _slideCtrl,
          axisAlignment: 1.0,
          child: SlideTransition(
            position: _slideAnim,
            child: Container(
              height: 120, // Reduced height for carousel items
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Stack(
                children: [
                  // Hint cards for multiple orders (visual UX)
                  if (orders.length > 1) ...[
                    Positioned(
                      left: 10,
                      right: 10,
                      top: 8,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                      ),
                    ),
                  ],

                  PageView.builder(
                    controller: _pageController,
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final orderItem = orders[index];
                      return _buildOrderCard(orderItem);
                    },
                  ),

                  // Indicators
                  if (orders.length > 1)
                    Positioned(
                      bottom: 6,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildPageIndicator(orders.length)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(ActiveOrderItem order) {
    return GestureDetector(
      onTap: () => _handleOrderTap(order),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          image: const DecorationImage(
            image: AssetImage('assets/images/top-bannner.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Color.fromRGBO(255, 255, 255, 0.85),
              BlendMode.lighten,
            ),
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: Row(
                children: [
                  _buildLogo(order.logoPath),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.displayShopName.isNotEmpty
                              ? order.displayShopName
                              : context.tr('common.restaurant'),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _getStatusText(context, order),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildTrackButton(),
                ],
              ),
            ),
            _buildProgressBar(order),
          ],
        ),
      ),
    );
  }

  void _handleOrderTap(ActiveOrderItem order) {
    final s = order.orderStatus;
    if (order.isRevised) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReviseOrderPage(orderId: order.orderId),
        ),
      );
      return;
    }
    if (s == 2 || s == -1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderStatusPage(
            foodTotal: order.resolvedItemSubtotal,
            deliveryFee: order.deliveryFee ?? 0,
          ),
        ),
      );
    } else if (s == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AwaitingPaymentPage(
            orderId: order.orderId,
            foodTotal: order.resolvedItemSubtotal,
            deliveryFee: order.deliveryFee ?? 0,
          ),
        ),
      );
    } else if (s == 3 || s == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingPage(
            store: CartStore(
              nameKey: order.shopNameEn ?? order.storeName ?? '',
              nameEn: order.shopNameEn ?? order.storeName,
              nameMm: order.shopNameMm,
              nameTh: order.shopNameTh,
              items: order.orderItems,
            ),
            foodTotal: order.resolvedItemSubtotal.round(),
          ),
        ),
      );
    } else if (s == 4 && !OrderCompletePage.isCurrentlyVisible) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OrderCompletePage()),
      );
    }
  }

  Widget _buildPageIndicator(int count) {
    return ListenableBuilder(
      listenable: _pageController,
      builder: (context, _) {
        final double page = _pageController.hasClients
            ? _pageController.page ?? 0
            : 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (i) {
            final double delta = (page - i).abs();
            final double size = 6 + (1.0 - delta.clamp(0.0, 1.0)) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: size,
              height: 6,
              decoration: BoxDecoration(
                color: delta < 0.5 ? AppColors.primary : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildProgressBar(ActiveOrderItem order) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _buildStepIcon(Icons.storefront_outlined, active: true),
          Expanded(
            child: _buildConnector(
              filled: order.orderStatus >= 2,
              isProcessing: order.orderStatus == 0 || order.orderStatus == 1,
            ),
          ),
          _buildStepIcon(
            Icons.receipt_long_outlined,
            active: order.orderStatus >= 2,
          ),
          Expanded(
            child: _buildConnector(
              filled: order.orderStatus >= 3,
              isProcessing: order.orderStatus == 2,
            ),
          ),
          _buildStepIcon(
            Icons.delivery_dining_outlined,
            active: order.orderStatus >= 3,
          ),
          Expanded(
            child: _buildConnector(
              filled: order.orderStatus >= 4,
              isProcessing: order.orderStatus == 3,
            ),
          ),
          _buildStepIcon(Icons.home_outlined, active: order.orderStatus >= 4),
        ],
      ),
    );
  }

  Widget _buildLogo(String? logoPath) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: ClipOval(
        child: (logoPath ?? '').isNotEmpty
            ? CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                imageUrl: logoPath!,
                fit: BoxFit.cover,
                errorWidget: (c, u, e) =>
                    const Icon(Icons.restaurant, size: 22, color: Colors.grey),
              )
            : const Icon(Icons.restaurant, size: 22, color: Colors.grey),
      ),
    );
  }

  Widget _buildTrackButton() {
    return ShaderMask(
      shaderCallback: (bounds) =>
          AppColors.primaryGradient.createShader(bounds),
      child: Row(
        children: [
          Text(
            context.tr('active_order.track'),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_forward, size: 14, color: Colors.white),
        ],
      ),
    );
  }

  String _getStatusText(BuildContext context, ActiveOrderItem order) {
    if (order.isRevised || order.isSlipRequested) {
      return context.tr('active_order.action_needed');
    }
    switch (order.orderStatus) {
      case 0:
        return context.tr('active_order.awaiting_confirmation');
      case 1:
        return order.showUploadSection
            ? context.tr('active_order.awaiting_payment')
            : context.tr('active_order.verifying_payment');
      case 2:
        return context.tr('active_order.preparing');
      case 3:
        final eta = order.estimatedTime;
        return eta != null && eta.isNotEmpty
            ? context.trArgs('active_order.est_arrival', {
                'time': TimeFormatter.normalizeDisplay(eta),
              })
            : context.tr('active_order.on_the_way');
      case 4:
        return context.tr('active_order.delivered');
      default:
        return context.tr('active_order.processing');
    }
  }

  Widget _buildStepIcon(IconData icon, {required bool active}) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, child) {
        return Container(
          width: 32,
          height: 32,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: active ? null : Colors.white,
            gradient: active ? AppColors.primaryGradient : null,
            shape: BoxShape.circle,
            border: active
                ? null
                : Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  icon,
                  size: 16,
                  color: active ? Colors.white : Colors.grey[500],
                ),
              ),
              // Reflection Shimmer Effect
              Positioned.fill(
                child: FractionallySizedBox(
                  widthFactor: 2.0,
                  alignment: Alignment(-3.0 + (_shimmerCtrl.value * 6.0), 0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.35, 0.5, 0.65],
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: active ? 0.4 : 0.2),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnector({required bool filled, bool isProcessing = false}) {
    return AnimatedBuilder(
      animation: _progressCtrl,
      builder: (context, child) {
        return Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              if (filled)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              if (isProcessing)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            width: constraints.maxWidth * _progressCtrl.value,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // Optional: Adding a small 'glow' or 'dot' at the end of processing
                          Positioned(
                            left:
                                constraints.maxWidth * _progressCtrl.value - 4,
                            top: -1,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF96232),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFF96232),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

