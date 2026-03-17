import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mytogetherapp/features/order/data/models/order_history_dto.dart';
import 'package:mytogetherapp/features/cart/data/active_order_state.dart';
import 'package:mytogetherapp/features/cart/presentation/screens/order_tracking_page.dart';
import 'package:mytogetherapp/features/cart/presentation/screens/order_status_page.dart';
import 'package:mytogetherapp/features/cart/presentation/screens/awaiting_payment_page.dart';
import 'package:mytogetherapp/features/cart/presentation/screens/order_complete_page.dart';
import 'package:mytogetherapp/features/cart/data/cart_manager.dart';
import 'package:mytogetherapp/core/network/websocket_service.dart';

class OrderHistoryCard extends StatelessWidget {
  final OrderHistoryDto order;

  const OrderHistoryCard({
    super.key,
    required this.order,
  });

  Color get primaryColor => const Color(0xFFED3A72);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
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
          // Shop Info Row
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: order.shopImageUrl != null && order.shopImageUrl!.isNotEmpty
                      ? Image.network(
                          order.shopImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.shopName ?? 'Restaurant',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      order.statusLabel ?? order.status,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                order.displayTotalAmount ?? '฿ ${order.totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          
          // Order ID and Time
          Row(
            children: [
              Text(
                '#${order.lastOrderNo ?? (order.id.length > 8 ? order.id.substring(order.id.length - 6) : order.id).toUpperCase()}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.circle, size: 4, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text(
                _formatDate(order.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Icon(PhosphorIcons.car(), size: 14, color: primaryColor),
              const SizedBox(width: 4),
              Text(
                'Delivery',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Progress Tracker
          _buildProgressTracker(),
          
          const SizedBox(height: 16),
          
          // Items Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.take(3).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        '${item.quantity}x ',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.menuItemName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
                if (order.items.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${order.items.length - 3} more items',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _viewDetails(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'View Details',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (order.ongoing) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _trackOrder(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Track Order',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: const Icon(Icons.restaurant, color: Colors.grey, size: 20),
    );
  }

  Widget _buildProgressTracker() {
    // Indices for stages: 0=Confirmed, 1=Preparing, 2=Ready, 3=Shipped, 4=Completed
    int activeIndex = _getStatusIndex(order.status);
    
    return Row(
      children: [
        _buildStep(PhosphorIcons.checkCircle(), activeIndex >= 0),
        _buildLine(activeIndex >= 1),
        _buildStep(PhosphorIcons.cookingPot(), activeIndex >= 1),
        _buildLine(activeIndex >= 2),
        _buildStep(PhosphorIcons.package(), activeIndex >= 2),
        _buildLine(activeIndex >= 3),
        _buildStep(PhosphorIcons.moped(), activeIndex >= 3),
        _buildLine(activeIndex >= 4),
        _buildStep(PhosphorIcons.house(), activeIndex >= 4),
      ],
    );
  }

  Widget _buildStep(IconData icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isActive ? primaryColor : Colors.grey[100],
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 16,
        color: isActive ? Colors.white : Colors.grey[400],
      ),
    );
  }

  Widget _buildLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? primaryColor : Colors.grey[200],
      ),
    );
  }

  int _getStatusIndex(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'CONFIRMED':
        return 0;
      case 'PAYMENT_VERIFIED':
      case 'PREPARING':
        return 1;
      case 'READY_TO_PICKUP':
        return 2;
      case 'ON_THE_WAY':
      case 'SHIPPED':
        return 3;
      case 'COMPLETED':
      case 'DELIVERED':
        return 4;
      default:
        return 0;
    }
  }

  String _formatDate(String isoString) {
    try {
      final DateTime date = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inHours < 1) return '${difference.inMinutes}m ago';
      if (difference.inDays < 1) return '${difference.inHours}h ago';
      
      return DateFormat('dd MMM, hh:mm a').format(date);
    } catch (_) {
      return '';
    }
  }

  void _viewDetails(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order Details for #${order.lastOrderNo ?? order.id} coming soon!')),
    );
  }

  Future<void> _trackOrder(BuildContext context) async {
    final state = ActiveOrderState.instance;
    
    // 1. Bootstrap the state with what we know
    state.setActiveOrder(
      storeName: order.shopName ?? 'Restaurant',
      restaurantName: order.shopName ?? 'Restaurant',
      logoPath: order.shopImageUrl,
      orderId: order.id,
    );
    
    // 2. Refresh full order details and status from API
    await state.syncActiveOrder();
    
    // 3. Connect WebSocket for live updates
    WebSocketService().connect(force: true);

    if (!context.mounted) return;

    // 4. Navigate based on the current status
    // Status mapping from updateFromSocket in active_order_state.dart:
    // 1: Awaiting Payment
    // 3: On the Way
    // others: Status Timeline
    
    Widget targetPage;
    final s = state.orderStatus;
    final foodTotal = (state.totalAmount ?? 0) - (state.deliveryFee ?? 0);
    final deliveryFee = state.deliveryFee ?? 0;

    if (s == 0 || s == 2 || s == -1) {
      targetPage = OrderStatusPage(
        foodTotal: foodTotal,
        deliveryFee: deliveryFee,
      );
    } else if (s == 1) {
      if (state.isPaymentChecking) {
        targetPage = OrderStatusPage(
          foodTotal: foodTotal,
          deliveryFee: deliveryFee,
        );
      } else {
        targetPage = AwaitingPaymentPage(
          foodTotal: foodTotal,
          deliveryFee: deliveryFee,
        );
      }
    } else if (s == 3) {
      targetPage = OrderTrackingPage(
        store: CartStore(name: state.storeName ?? '', items: state.orderItems),
        foodTotal: (state.totalAmount ?? 0).toInt(),
      );
    } else if (s == 4) {
       // Using status page for completed orders too if they are still "active" in state
       // or navigate to complete page directly
      targetPage = OrderCompletePage();
    } else {
      targetPage = OrderStatusPage(
        foodTotal: foodTotal,
        deliveryFee: deliveryFee,
      );
    }

    if (targetPage is OrderCompletePage && OrderCompletePage.isCurrentlyVisible) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetPage),
    );
  }
}
