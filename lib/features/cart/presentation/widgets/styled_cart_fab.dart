import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/cart_manager.dart';
import '../screens/cart_page.dart';

import '../../data/active_order_state.dart';

class StyledCartFab extends StatelessWidget {
  const StyledCartFab({super.key, this.liftAboveActiveOrderBar = true});

  /// Whether to raise the cart above the active-order tracking card.
  ///
  /// Only tabs that actually render [ActiveOrderBar] (Home, Food) should set
  /// this to true. On tabs without the tracking card (e.g. Order History) it
  /// stays false so the cart rests in its original place.
  final bool liftAboveActiveOrderBar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([CartManager.instance, ActiveOrderState.instance]),
      builder: (context, _) {
        final cartCount = CartManager.instance.totalItemCount;
        final hasActiveOrder = ActiveOrderState.instance.hasActiveOrder;
        final lift = liftAboveActiveOrderBar && hasActiveOrder;

        if (cartCount <= 0) return const SizedBox.shrink();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(bottom: lift ? 130.0 : 0.0),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartPage()),
                );
              },
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Center(
                  child: Badge(
                    label: Text(
                      '$cartCount',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
