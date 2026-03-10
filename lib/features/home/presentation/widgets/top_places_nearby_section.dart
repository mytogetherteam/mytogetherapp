import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'place_card.dart';
import 'view_all_icon_button.dart';

class TopPlacesNearbySection extends StatefulWidget {
  const TopPlacesNearbySection({super.key});

  @override
  State<TopPlacesNearbySection> createState() => _TopPlacesNearbySectionState();
}

class _TopPlacesNearbySectionState extends State<TopPlacesNearbySection> {
  final Set<int> _favoriteIndices = {};

  final List<Map<String, dynamic>> _places = [
    {
      'name': 'MahaNakhon Skywalk',
      'category': 'Tower',
      'distance': '3.2 km',
      'imagePath': 'https://i.pinimg.com/736x/65/b1/76/65b176609f757713b3a68ecae83086dc.jpg',
    },
    {
      'name': 'The Grand Palace',
      'category': 'Royal Palace',
      'distance': '2.8 km',
      'imagePath': 'https://images.unsplash.com/photo-1563492065599-3520f775eeed?q=80&w=800&auto=format&fit=crop',
    },
    {
      'name': 'Bangkok Downtown',
      'category': 'Places',
      'distance': '3.0 km',
      'imagePath': 'https://i.pinimg.com/736x/e0/69/ab/e069ab1924ca69a71f927998e1410fb8.jpg',
    },
    {
      'name': 'Chinatown',
      'category': 'Places',
      'distance': '1.2 km',
      'imagePath': 'https://i.pinimg.com/736x/30/5e/37/305e3795e89af49b42873adeaf5213ea.jpg',
    },
    {
      'name': 'Chatuchak Market',
      'category': 'Weekend Market',
      'distance': '8.5 km',
      'imagePath': 'https://i.pinimg.com/736x/7e/11/db/7e11dbf1041eeaffb77a0d092a7ddbec.jpg',
    },
    {
      'name': 'Lumpini Park',
      'category': 'City Park',
      'distance': '1.5 km',
      'imagePath': 'https://i.pinimg.com/736x/85/bc/16/85bc161fc4bff6a316ec552c3bd8d001.jpg',
    },
    {
      'name': 'Iconsiam',
      'category': 'Luxury Mall',
      'distance': '4.2 km',
      'imagePath': 'https://i.pinimg.com/736x/a4/12/9f/a4129f56eb5543471515a6cc157e20d2.jpg',
    }
  ];

  void _toggleFavorite(int index) {
    setState(() {
      if (_favoriteIndices.contains(index)) {
        _favoriteIndices.remove(index);
      } else {
        _favoriteIndices.add(index);
      }
    });

    if (mounted) {
      final isAdded = _favoriteIndices.contains(index);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAdded ? 'Added to favorites' : 'Removed from favorites'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Places Nearby',
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
          height: 320,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16.0),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: _places.length,
            itemBuilder: (context, index) {
              final place = _places[index];
              return PlaceCard(
                name: place['name']!,
                category: place['category']!,
                distance: place['distance']!,
                imagePath: place['imagePath']!,
                isFavorite: _favoriteIndices.contains(index),
                onFavoriteToggle: () => _toggleFavorite(index),
              );
            },
          ),
        ),
      ],
    );
  }
}
