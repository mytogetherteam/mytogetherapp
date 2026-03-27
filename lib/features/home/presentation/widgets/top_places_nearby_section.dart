import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'place_card.dart';
import 'view_all_icon_button.dart';
import '../screens/place_detail_page.dart';

class TopPlacesNearbySection extends StatefulWidget {
  const TopPlacesNearbySection({super.key});

  @override
  State<TopPlacesNearbySection> createState() => _TopPlacesNearbySectionState();
}

class _TopPlacesNearbySectionState extends State<TopPlacesNearbySection> {
  final Set<int> _favoriteIndices = {};

  final List<Map<String, dynamic>> _places = [
    {
      'name': 'Grand Palace',
      'category': 'Royal Heritage',
      'distance': '2.1 km',
      'imagePath': 'https://images.unsplash.com/photo-1596402184320-417d7178b2cd?q=80&w=800&auto=format&fit=crop',
      'description': 'A complex of buildings at the heart of Bangkok, the Grand Palace has been the official residence of the Kings of Siam (and later Thailand) since 1782. It is home to the sacred Emerald Buddha temple.',
      'hours': '8:30 AM - 3:30 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1544015759-338276f920f3?q=80&w=400',
        'https://images.unsplash.com/photo-1569424888066-8848db9980d2?q=80&w=400',
        'https://images.unsplash.com/photo-1528642345070-5c62d8544d65?q=80&w=400',
      ],
    },
    {
      'name': 'Wat Arun',
      'category': 'Riverside Temple',
      'distance': '1.8 km',
      'imagePath': 'https://images.unsplash.com/photo-1528127269322-53980194300e?q=80&w=800&auto=format&fit=crop',
      'description': 'Wat Arun, the "Temple of Dawn", is one of Bangkok\'s most iconic symbols. Situated on the west bank of the Chao Phraya River, its porcelain-encrusted spire shines spectacularly at sunrise and sunset.',
      'hours': '8:00 AM - 6:00 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1506953823976-52e1fdc0149a?q=80&w=400',
        'https://images.unsplash.com/photo-1589394815804-964ed0be2eb5?q=80&w=400',
        'https://images.unsplash.com/photo-1552465011-b4e21bf6e79a?q=80&w=400',
      ],
    },
    {
      'name': 'Wat Pho',
      'category': 'Ancient Temple',
      'distance': '3.2 km',
      'imagePath': 'https://images.unsplash.com/photo-1544015759-338276f920f3?q=80&w=800&auto=format&fit=crop',
      'description': 'Wat Pho is one of Bangkok\'s oldest and largest temples, famous for its giant reclining Buddha statue covered in gold leaf. It is also known as the birthplace of traditional Thai massage.',
      'hours': '8:00 AM - 6:30 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1596402184320-417d7178b2cd?q=80&w=400',
        'https://images.unsplash.com/photo-1590001155093-a3c66ab0c3ff?q=80&w=400',
        'https://images.unsplash.com/photo-1562768532-61266b744b82?q=80&w=400',
      ],
    },
    {
      'name': 'Chatuchak Market Weekend Market',
      'category': 'Weekend Market',
      'distance': '5.5 km',
      'imagePath': 'https://images.unsplash.com/photo-1565538810643-b5bdb714032a?q=80&w=800&auto=format&fit=crop',
      'description': 'One of the world\'s largest outdoor markets, Chatuchak features over 15,000 stalls selling everything from fashion and antiques to plants and pets. It\'s a must-visit for shoppers in Bangkok.',
      'hours': 'Sat-Sun 9:00 AM - 6:00 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1510590337019-5ef8d3d32116?q=80&w=400',
        'https://images.unsplash.com/photo-1552465011-b4e21bf6e79a?q=80&w=400',
        'https://images.unsplash.com/photo-1504711432869-b39743a4be9a?q=80&w=400',
      ],
    },
    {
      'name': 'Jim Thompson',
      'category': 'Silk Museum',
      'distance': '0.8 km',
      'imagePath': 'https://images.unsplash.com/photo-1583091931846-574d3fb0678d?q=80&w=800&auto=format&fit=crop',
      'description': 'A beautiful complex of traditional Thai teak houses once owned by American silk tycoon Jim Thompson. The museum showcases his exquisite collection of Asian art and historic architecture.',
      'hours': '10:00 AM - 6:00 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1596402184320-417d7178b2cd?q=80&w=400',
        'https://images.unsplash.com/photo-1528642345070-5c62d8544d65?q=80&w=400',
        'https://images.unsplash.com/photo-1569424888066-8848db9980d2?q=80&w=400',
      ],
    },
    {
      'name': 'Khao San Road',
      'category': 'Historic Hub',
      'distance': '3.0 km',
      'imagePath': 'https://images.unsplash.com/photo-1510590337019-5ef8d3d32116?q=80&w=800&auto=format&fit=crop',
      'description': 'The world-famous backpacker center of Bangkok. Khao San Road is vibrant with street food stalls, budget hostels, nightlife, and a unique atmosphere that attracts travelers from across the globe.',
      'hours': 'Open 24 hours',
      'gallery': [
        'https://images.unsplash.com/photo-1563200774-67d716492931?q=80&w=400',
        'https://images.unsplash.com/photo-1506953823976-52e1fdc0149a?q=80&w=400',
        'https://images.unsplash.com/photo-1562768532-61266b744b82?q=80&w=400',
      ],
    },
    {
      'name': 'Lumpini Park',
      'category': 'Public Park',
      'distance': '1.5 km',
      'imagePath': 'https://images.unsplash.com/photo-1590001140227-ec56d900609a?q=80&w=800&auto=format&fit=crop',
      'description': 'A rare open green space in the middle of Bangkok. Lumpini Park is perfect for walking, jogging, and boat rowing, and is famous for its large resident water monitor lizards.',
      'hours': '4:30 AM - 9:00 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1589394815804-964ed0be2eb5?q=80&w=400',
        'https://images.unsplash.com/photo-1528181304800-2f140819ad1c?q=80&w=400',
        'https://images.unsplash.com/photo-1540973623715-c26644bad1ef?q=80&w=400',
      ],
    },
    {
      'name': 'ICONSIAM',
      'category': 'Modern Luxury',
      'distance': '2.5 km',
      'imagePath': 'https://images.unsplash.com/photo-1582650625119-3a31f8fa2699?q=80&w=800&auto=format&fit=crop',
      'description': 'Bangkok\'s premier riverside shopping and lifestyle destination. ICONSIAM combines luxury brands, a floating market-themed food hall (SookSiam), and spectacular water fountain shows.',
      'hours': '10:00 AM - 10:00 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?q=80&w=400',
        'https://images.unsplash.com/photo-1534067783941-51c9c23ecefd?q=80&w=400',
        'https://images.unsplash.com/photo-1589146194726-25816966f366?q=80&w=400',
      ],
    },
    {
      'name': 'Golden Mount',
      'category': 'Temple Viewpoint',
      'distance': '3.8 km',
      'imagePath': 'https://images.unsplash.com/photo-1562768532-61266b744b82?q=80&w=800&auto=format&fit=crop',
      'description': 'Wat Saket, home to the Golden Mount, offers some of the best panoramic views of old Bangkok. Visitors climb over 300 steps through a misty, shaded path to reach the gleaming golden chedi.',
      'hours': '7:00 AM - 7:00 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1544015759-338276f920f3?q=80&w=400',
        'https://images.unsplash.com/photo-1596402184320-417d7178b2cd?q=80&w=400',
        'https://images.unsplash.com/photo-1528127269322-53980194300e?q=80&w=400',
      ],
    },
    {
      'name': 'Yaowarat Road',
      'category': 'Chinatown',
      'distance': '4.0 km',
      'imagePath': 'https://images.unsplash.com/photo-1563200774-67d716492931?q=80&w=800&auto=format&fit=crop',
      'description': 'The heart of Bangkok\'s Chinatown and one of the best street food destinations in the world. At night, Yaowarat transforms into a neon-lit foodie paradise with endless culinary delights.',
      'hours': 'Open 24 hours (Best food after 6 PM)',
      'gallery': [
        'https://images.unsplash.com/photo-1510590337019-5ef8d3d32116?q=80&w=400',
        'https://images.unsplash.com/photo-1552465011-b4e21bf6e79a?q=80&w=400',
        'https://images.unsplash.com/photo-1506953823976-52e1fdc0149a?q=80&w=400',
      ],
    },
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
          backgroundColor: const Color(0xFFED3A72),
          behavior: SnackBarBehavior.floating,
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaceDetailPage(
                        name: place['name']!,
                        category: place['category']!,
                        distance: place['distance']!,
                        imagePath: place['imagePath']!,
                        description: place['description']!,
                        openingHours: place['hours'],
                        images: List<String>.from(place['gallery']),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
