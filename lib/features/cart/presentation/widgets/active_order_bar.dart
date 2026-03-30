import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/active_order_state.dart';
import '../screens/order_status_page.dart';
import '../screens/awaiting_payment_page.dart';
import '../screens/order_complete_page.dart';
import '../screens/order_tracking_page.dart';
import '../screens/order_cancel_page.dart';
import '../../data/cart_manager.dart';

class ActiveOrderBar extends StatefulWidget {
  const ActiveOrderBar({super.key});

  @override
  State<ActiveOrderBar> createState() => _ActiveOrderBarState();
}

class _ActiveOrderBarState extends State<ActiveOrderBar> with TickerProviderStateMixin {
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

    _slideCtrl = AnimationController(
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
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOutCubic,
    ));

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (ActiveOrderState.instance.hasActiveOrder) {
      _wasActive = true;
      _progressCtrl.repeat();
      _slideCtrl.forward();
      _shimmerCtrl.forward(from: 0);
    }
    
    ActiveOrderState.instance.addListener(_handleStateChange);
  }

  void _handleStateChange() {
    if (mounted) {
      final isActive = ActiveOrderState.instance.hasActiveOrder;
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
    if (OrderCompletePage.isCurrentlyVisible) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: Listenable.merge([ActiveOrderState.instance, _slideCtrl]),
      builder: (context, _) {
        final state = ActiveOrderState.instance;
        final orders = state.activeOrdersList;
        
        if (!state.hasActiveOrder && _slideCtrl.isDismissed) return const SizedBox.shrink();
        
        if (!state.hasActiveOrder && !_slideCtrl.isDismissed) {
           _slideCtrl.reverse();
        }

        return SizeTransition(
          sizeFactor: _slideCtrl,
          axisAlignment: -1.0,
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
                      left: 10, right: 10, top: 8, bottom: 0,
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
                      child: Center(
                        child: _buildPageIndicator(orders.length),
                      ),
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
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
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
                          order.restaurantName ?? order.storeName ?? 'Restaurant',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _getStatusText(order),
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
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
    // RESOLVE LATEST STATE: Fetch the freshest data from the repository before navigating
    final latestOrder = ActiveOrderState.instance.getOrder(order.orderId) ?? order;
    final s = latestOrder.orderStatus;
    
    // Calculate subtotal (Total - Fee)
    final double subtotal = (latestOrder.totalAmount ?? 0) - (latestOrder.deliveryFee ?? 0);
    final double deliveryFee = latestOrder.deliveryFee ?? 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      if (s == 1) {
        // Awaiting Payment - Logic check for upload state
        if (latestOrder.showUploadSection) {
          // Still need to upload or show QR
          Navigator.push(context, MaterialPageRoute(builder: (_) => AwaitingPaymentPage(
            orderId: latestOrder.orderId,
            foodTotal: subtotal,
            deliveryFee: deliveryFee,
          )));
        } else {
          // Already uploaded, go to verification status page
          Navigator.push(context, MaterialPageRoute(builder: (_) => OrderStatusPage(
            foodTotal: subtotal,
            deliveryFee: deliveryFee,
            orderId: latestOrder.orderId,
          )));
        }
      } else if (s == 0 || s == 2 || s == 3) {
        // Pending Confirmation, Preparing or Delivering
        Navigator.push(context, MaterialPageRoute(builder: (_) => OrderStatusPage(
          foodTotal: subtotal,
          deliveryFee: deliveryFee,
          orderId: latestOrder.orderId,
        )));
      } else if (s == 4 && !OrderCompletePage.isCurrentlyVisible) {
        // Completed
        Navigator.push(context, MaterialPageRoute(builder: (_) => OrderCompletePage(orderId: latestOrder.orderId)));
      } else if (s == -1) {
        // Cancelled
        Navigator.push(context, MaterialPageRoute(builder: (_) => OrderCancelPage(
          orderId: latestOrder.orderId,
          shopId: latestOrder.restaurantId,
          shopName: latestOrder.restaurantName,
          shopLogo: latestOrder.logoPath,
          shopImageUrl: latestOrder.shopImageUrl,
          reason: 'The restaurant is unable to fulfill your order at this time.',
        )));
      }
    });
  }

  Widget _buildPageIndicator(int count) {
    return ListenableBuilder(
      listenable: _pageController,
      builder: (context, _) {
        final double page = _pageController.hasClients ? _pageController.page ?? 0 : 0;
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
                color: delta < 0.5 ? const Color(0xFFED3973) : Colors.grey[300],
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
          Expanded(child: _buildConnector(
            filled: order.orderStatus >= 2,
            isProcessing: order.orderStatus == 0 || order.orderStatus == 1,
          )),
          _buildStepIcon(Icons.receipt_long_outlined, active: order.orderStatus >= 2),
          Expanded(child: _buildConnector(
            filled: order.orderStatus >= 3,
            isProcessing: order.orderStatus == 2,
          )),
          _buildStepIcon(Icons.delivery_dining_outlined, active: order.orderStatus >= 3),
          Expanded(child: _buildConnector(
            filled: order.orderStatus >= 4,
            isProcessing: order.orderStatus == 3,
          )),
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
            ? CachedNetworkImage(
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
    return Row(
      children: [
        Text(
          'Track order',
          style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFED3973)),
        ),
        const SizedBox(width: 2),
        const Icon(Icons.arrow_forward,
            size: 14, color: Color(0xFFED3973)),
      ],
    );
  }

  String _getStatusText(ActiveOrderItem order) {
    switch (order.orderStatus) {
      case 0:
        return 'Awaiting Confirmation';
      case 1:
        return order.showUploadSection ? 'Awaiting Payment' : 'Verifying Payment...';
      case 2:
        return 'Restaurant Preparing...';
      case 3:
        final eta = order.estimatedTime;
        return eta != null && eta.isNotEmpty ? 'Est. arrival: $eta' : 'Order Is On The Way...';
      case 4:
        return 'Order Delivered!';
      default:
        return 'Processing Order...';
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
            color: active ? const Color(0xFFED3973) : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(icon,
                    size: 16,
                    color: active ? Colors.white : Colors.grey[500]),
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
                      color: const Color(0xFFED3973),
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
                              color: const Color(0xFFED3973),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // Optional: Adding a small 'glow' or 'dot' at the end of processing
                          Positioned(
                            left: constraints.maxWidth * _progressCtrl.value - 4,
                            top: -1,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFED3973),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFED3973),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
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
