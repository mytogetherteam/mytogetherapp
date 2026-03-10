import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'special_promotion_card.dart';
import 'view_all_icon_button.dart';

class SpecialPromotionSection extends StatefulWidget {
  const SpecialPromotionSection({super.key});

  @override
  State<SpecialPromotionSection> createState() =>
      _SpecialPromotionSectionState();
}

class _SpecialPromotionSectionState extends State<SpecialPromotionSection> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  final double _itemWidth = 280.0 + 12.0; // Card width + margin

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Width of card (280) + margin (12). 
    // This is a rough estimation for dots.
    final index = (_scrollController.offset / _itemWidth).round();
    if (index != _currentPage) {
      setState(() {
        _currentPage = index;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Just for demo, assuming 3 items
    final itemCount = 3;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Special Promotion',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              ViewAllIconButton(
                onPressed: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170, // Reduced height for smaller cards
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              // Creating dummy data for variation
              if (index == 0) {
                 return const SpecialPromotionCard(
                    title: 'Discount for',
                    highlightText: 'Monday',
                    subtitle: 'Save On Your Order',
                    imagePath: 'assets/images/services/food.png', // Fallback to existing asset
                  );
              } else if (index == 1) {
                return const SpecialPromotionCard(
                  title: 'Discount for',
                  highlightText: 'Weekend',
                  subtitle: 'Get 20% Off Pizza',
                  imagePath: 'assets/images/services/places.png',
                );
              } else {
                 return const SpecialPromotionCard(
                  title: 'Special',
                  highlightText: 'Combo',
                  subtitle: 'Burger + Coke for \$5',
                  imagePath: 'assets/images/services/store.png',
                );
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        // Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(itemCount, (index) {
            final isSelected = _currentPage == index; 
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: isSelected ? 24 : 8,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFED3A72) : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}
