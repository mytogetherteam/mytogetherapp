import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/place_card.dart';
import '../widgets/top_places_nearby_section.dart'; // Just to check how they use it
import '../../data/fallback_data.dart';
import 'place_detail_page.dart';

class PlacesListPage extends StatefulWidget {
  const PlacesListPage({super.key});

  @override
  State<PlacesListPage> createState() => _PlacesListPageState();
}

class _PlacesListPageState extends State<PlacesListPage> {
  final Set<String> _favoritePlaces = {};
  
  // Extend fallback data with specific Bangkok landmarks
  late List<Map<String, dynamic>> _allPlaces;

  @override
  void initState() {
    super.initState();
    _allPlaces = [
      ...FallbackData.topPlaces,
    ];
  }

  void _toggleFavorite(String name) {
    setState(() {
      if (_favoritePlaces.contains(name)) {
        _favoritePlaces.remove(name);
      } else {
        _favoritePlaces.add(name);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_favoritePlaces.contains(name) ? 'Added to favorites' : 'Removed from favorites', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFED3973),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Famous Places',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.magnifyingGlass(), color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discover Bangkok',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Explore the best landmarks and shopping spots near you.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1, // Single column for better focus
                mainAxisSpacing: 24,
                crossAxisSpacing: 0,
                mainAxisExtent: 320, // Increased height for full-width focus
              ),
              itemCount: _allPlaces.length,
              itemBuilder: (context, index) {
                final place = _allPlaces[index];
                final name = place['name']!;
                
                return PlaceCard(
                  name: name,
                  category: place['category']!,
                  distance: place['distance']!,
                  imagePath: place['imagePath']!,
                  isFavorite: _favoritePlaces.contains(name),
                  onFavoriteToggle: () => _toggleFavorite(name),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlaceDetailPage(
                          name: name,
                          category: place['category']!,
                          distance: place['distance']!,
                          imagePath: place['imagePath']!,
                          description: place['description']!,
                          openingHours: place['hours'],
                          images: List<String>.from(place['gallery'] ?? []),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
