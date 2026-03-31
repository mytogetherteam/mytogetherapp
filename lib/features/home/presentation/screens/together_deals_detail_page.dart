import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_menu_item_card.dart';
import 'package:mytogetherapp/features/home/data/fallback_data.dart';
import 'package:mytogetherapp/features/home/data/models/menu_item_dto.dart';
import 'package:mytogetherapp/features/home/data/repositories/restaurant_repository.dart';

class TogetherDealsDetailPage extends StatefulWidget {
  const TogetherDealsDetailPage({super.key});

  @override
  State<TogetherDealsDetailPage> createState() => _TogetherDealsDetailPageState();
}

class _TogetherDealsDetailPageState extends State<TogetherDealsDetailPage> {
  final Map<String, bool> _localFavorites = {};

  // Convert map data to MenuItemDto so we can reuse FoodMenuItemCard
  List<MenuItemDto> get _items {
    return FallbackData.togetherDeals.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      return MenuItemDto(
        id: 'deal_$index',
        restaurantId: '1', // Dummy ID
        restaurantName: 'Together Deals Shop',
        title: data['name']!,
        price: (data['price'] as int).toDouble(),
        currency: '฿',
        imagePath: data['imagePath']!,
        category: 'Deal',
        isFavorite: false,
        displayPrice: '฿${data['price']}',
        originalPrice: (data['originalPrice'] as int).toDouble(),
        rating: 4.8,
        reviewCount: 124,
        distanceKm: 1.5,
        estimatedTime: '${data['minutes']} min',
        deliveryFee: '฿${data['deliveryFee']}',
      );
    }).toList();
  }

  Future<void> _toggleFavorite(MenuItemDto item) async {
    final newStatus = !(_localFavorites[item.id] ?? item.isFavorite);
    final messenger = ScaffoldMessenger.of(context);
    
    // Immediate local feedback
    setState(() {
      _localFavorites[item.id] = newStatus;
    });

    try {
      await RestaurantRepository.instance.toggleMenuFavorite(
        int.tryParse(item.id.replaceAll('deal_', '')) ?? 0,
        newStatus,
      );
      
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Added to favorites' : 'Removed from favorites'),
            backgroundColor: const Color(0xFFED3A72),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _localFavorites[item.id] = !newStatus;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to update favorite. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const displayTitle = 'Together Up to 40% Off';
    final int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          displayTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.black.withValues(alpha: 0.05),
            height: 1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 48.0),
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
          childAspectRatio: 0.85,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return FoodMenuItemCard(
            id: item.id,
            restaurantId: item.restaurantId,
            title: item.title,
            price: item.price,
            currency: item.currency,
            imagePath: item.imagePath,
            restaurantName: item.restaurantName,
            isFavorite: _localFavorites[item.id] ?? item.isFavorite,
            displayPrice: item.displayPrice,
            rating: item.rating,
            reviewCount: item.reviewCount,
            distanceKm: item.distanceKm,
            estimatedTime: item.estimatedTime,
            deliveryFee: item.deliveryFee,
            originalDeliveryFee: item.originalDeliveryFee,
            originalPrice: item.originalPrice,
            onFavoriteToggle: () => _toggleFavorite(item),
            forceRestaurantNavigation: true,
          );
        },
      ),
    );
  }
}
