import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/features/home/data/fallback_data.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/place_card.dart';
import 'package:mytogetherapp/features/home/presentation/screens/place_detail_page.dart';

class TopPlacesNearbyPage extends StatefulWidget {
  const TopPlacesNearbyPage({super.key});

  @override
  State<TopPlacesNearbyPage> createState() => _TopPlacesNearbyPageState();
}

class _TopPlacesNearbyPageState extends State<TopPlacesNearbyPage> {
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
    return Scaffold(
      backgroundColor: const Color(0xFFEDF3F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Top Places Nearby',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        physics: const BouncingScrollPhysics(),
        itemCount: _places.length,
        itemBuilder: (context, index) {
          final place = _places[index];
          return PlaceCard(
            width: double.infinity,
            height: 380, // slightly larger height for vertical list as in design 
            margin: const EdgeInsets.only(bottom: 16),
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
    );
  }
}
