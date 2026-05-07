import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/place_card.dart';
import '../../data/fallback_data.dart';
import 'place_detail_page.dart';

class PlacesListPage extends StatelessWidget {
  const PlacesListPage({super.key});

  List<Map<String, dynamic>> get _places => FallbackData.topPlaces;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nearby Places',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: _places.length,
        itemBuilder: (context, index) {
          final place = _places[index];
          return PlaceCard(
            name: place['name']!,
            category: place['category']!,
            distance: place['distance']!,
            imagePath: place['imagePath']!,
            isFavorite: false, // Default for list page
            onFavoriteToggle: () {},
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
