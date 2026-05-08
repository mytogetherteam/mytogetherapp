import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/cart_manager.dart';
import '../screens/cart_page.dart';

class StyledCartFab extends StatelessWidget {
  const StyledCartFab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, _) {
        final cartCount = CartManager.instance.totalItemCount;

        if (cartCount <= 0) return const SizedBox.shrink();

        return Container(
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
