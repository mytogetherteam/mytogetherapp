import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'place_card.dart';
import 'view_all_icon_button.dart';
import '../../data/fallback_data.dart';
import '../screens/place_detail_page.dart';
import '../screens/places_list_page.dart';

class TopPlacesNearbySection extends StatefulWidget {
  const TopPlacesNearbySection({super.key});

  @override
  State<TopPlacesNearbySection> createState() => _TopPlacesNearbySectionState();
}

class _TopPlacesNearbySectionState extends State<TopPlacesNearbySection> {
  final Set<int> _favoriteIndices = {};

  List<Map<String, dynamic>> get _places => FallbackData.topPlaces;

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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PlacesListPage()),
                  );
                },
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
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 240,
                  height: 320,
                  child: PlaceCard(
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
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
}
