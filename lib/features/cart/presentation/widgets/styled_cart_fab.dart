import 'package:flutter/material.dart';
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

        return FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartPage()),
            );
          },
          backgroundColor: const Color(0xFFED3A72),
          shape: const CircleBorder(),
          child: Badge(
            label: Text(
              '$cartCount',
              style: const TextStyle(
                color: Color(0xFFED3A72),
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            child: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
          ),
        );
      },
    );
  }
}
