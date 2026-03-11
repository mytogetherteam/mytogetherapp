import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/active_order_state.dart';
import '../screens/order_status_page.dart';
import '../screens/awaiting_payment_page.dart';
import '../screens/order_complete_page.dart';
import '../screens/order_tracking_page.dart';
import '../../data/cart_manager.dart';

class ActiveOrderBar extends StatefulWidget {
  const ActiveOrderBar({super.key});

  @override
  State<ActiveOrderBar> createState() => _ActiveOrderBarState();
}

class _ActiveOrderBarState extends State<ActiveOrderBar>
    with TickerProviderStateMixin {
  late AnimationController _progressCtrl;
  late AnimationController _dotCtrl;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  
  // Shimmer controller
  late AnimationController _shimmerCtrl;
  
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Slide up animation (bottom to top)
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        if (mounted) setState(() {});
      }
    });
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1.2), // Start below screen
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOutCubic,
    ));

    // Shimmer effect animation
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Initial check
    if (ActiveOrderState.instance.hasActiveOrder) {
      _wasActive = true;
      _progressCtrl.forward();
      _slideCtrl.forward();
      _shimmerCtrl.forward(from: 0);
    }
    
    ActiveOrderState.instance.addListener(_handleStateChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Whenever this route becomes current (e.g. returning from sub-page), trigger slide animation
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (isCurrent && ActiveOrderState.instance.hasActiveOrder) {
      _slideCtrl.forward(from: 0);
    }
  }

  void _handleStateChange() {
    if (mounted) {
      final isActive = ActiveOrderState.instance.hasActiveOrder;
      if (isActive && !_wasActive) {
        _progressCtrl.reset();
        _progressCtrl.forward();
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
        if (!state.hasActiveOrder && _slideCtrl.isDismissed) return const SizedBox.shrink();
        
        // Ensure it slides down correctly when order is cleared
        if (!state.hasActiveOrder && !_slideCtrl.isDismissed) {
           _slideCtrl.reverse();
        }

        return SizeTransition(
          sizeFactor: _slideCtrl,
          axisAlignment: -1.0,
          child: SlideTransition(
            position: _slideAnim,
            child: GestureDetector(
                onTap: () {
              final orderStatus = state.orderStatus;
              
              if (orderStatus == 0) {
                // Return to Order Tracking Page (Awaiting Confirmation)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderTrackingPage(
                      store: CartStore(name: state.storeName ?? '', items: state.orderItems),
                      foodTotal: (state.totalAmount ?? 0).toInt(),
                    ),
                  ),
                );
              } else if (orderStatus == 1 || orderStatus == 2) {
                // Return to Awaiting Payment Page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AwaitingPaymentPage(
                      foodTotal: state.totalAmount ?? 0,
                      deliveryFee: state.deliveryFee ?? 0,
                    ),
                  ),
                );
              } else if (orderStatus == 3) {
                // In order tracking status — go to OrderStatusPage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderStatusPage(
                      foodTotal: state.totalAmount ?? 0,
                      deliveryFee: state.deliveryFee ?? 0,
                    ),
                  ),
                );
              } else if (orderStatus == 4) {
                // In Completed status — go to OrderCompletePage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrderCompletePage(),
                  ),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        // Logo
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[100],
                            border: Border.all(color: Colors.grey[200]!, width: 1),
                          ),
                          child: ClipOval(
                            child: (state.logoPath ?? '').isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: state.logoPath!,
                                    fit: BoxFit.cover,
                                    errorWidget: (c, u, e) =>
                                        const Icon(Icons.restaurant, size: 22, color: Colors.grey),
                                  )
                                : const Icon(Icons.restaurant, size: 22, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.restaurantName ?? state.storeName ?? '',
                                style: GoogleFonts.poppins(
                                    fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _getStatusText(state),
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Row(
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
                        ),
                      ],
                    ),
                  ),

                  // Progress bar + step icons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Row(
                      children: [
                        _buildStepIcon(Icons.storefront_outlined, active: true),
                        Expanded(child: _buildConnector(filled: true)),
                        _buildStepIcon(Icons.restaurant_menu_outlined, active: state.orderStatus >= 2),
                        Expanded(child: _buildConnector(filled: state.orderStatus >= 2)),
                        _buildStepIcon(Icons.delivery_dining_outlined, active: state.orderStatus >= 3),
                        Expanded(child: _buildConnector(filled: state.orderStatus >= 3)),
                        _buildStepIcon(Icons.home_outlined, active: state.orderStatus >= 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  },
);
  }

  String _getStatusText(ActiveOrderState state) {
    if (state.orderStatus == 0) {
      return 'Awaiting Confirmation';
    } else if (state.orderStatus == 1) {
      return 'Checking your Payment...';
    } else if (state.orderStatus == 2) {
      return 'Restaurant Preparing...';
    } else if (state.orderStatus == 3) {
      return 'Est. arrival: ${state.estimatedTime}';
    } else if (state.orderStatus == 4) {
      return 'Order Completed';
    }
    return 'Processing Order...';
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

  Widget _buildConnector({required bool filled}) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: filled ? const Color(0xFFED3973) : Colors.grey[200],
    );
  }
}
