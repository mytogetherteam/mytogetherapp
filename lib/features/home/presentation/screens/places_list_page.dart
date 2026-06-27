import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/location/location_service.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/features/wishlist/data/repositories/wishlist_repository.dart';
import 'package:mytogetherapp/features/wishlist/presentation/screens/wishlist_page.dart';
import '../widgets/place_card.dart';
import '../../data/models/place_dto.dart';
import '../../data/repositories/places_repository.dart';
import 'place_detail_page.dart';

class PlacesListPage extends StatefulWidget {
  const PlacesListPage({super.key});

  @override
  State<PlacesListPage> createState() => _PlacesListPageState();
}

class _PlacesListPageState extends State<PlacesListPage> {
  List<PlaceDto> _places = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    try {
      await WishlistRepository.instance.loadAll();
      final pos = await LocationService().getCurrentPosition();
      final feed = await PlacesRepository.instance.fetchPlaces(
        page: 1,
        size: 50,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      if (mounted) {
        final repo = WishlistRepository.instance;
        setState(() {
          // The wishlist is the source of truth for the favorite heart so the
          // saved state survives reloads even when the feed omits `isFavorite`.
          _places = feed.items
              .map((p) => p.copyWith(isFavorite: repo.isPlaceSaved(p.id)))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(PlaceDto place) async {
    final next = !place.isFavorite;
    setState(() {
      final index = _places.indexWhere((p) => p.id == place.id);
      if (index != -1) {
        _places[index] = place.copyWith(isFavorite: next);
      }
    });
    try {
      await WishlistRepository.instance.togglePlace(place.id, next);
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr(next ? 'wishlist.saved' : 'wishlist.removed'),
          actionLabel: next ? context.tr('wishlist.view_action') : null,
          onAction: next
              ? () => WishlistPage.open(context,
                  initialTab: WishlistPage.tabPlaces)
              : null,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final index = _places.indexWhere((p) => p.id == place.id);
          if (index != -1) {
            _places[index] = place.copyWith(isFavorite: !next);
          }
        });
      }
    }
  }

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
          context.tr('place.nearby_places'),
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadPlaces,
        color: Theme.of(context).primaryColor,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _places.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: Center(
                          child: Text(context.tr('place.none_found')),
                        ),
                      ),
                    ],
                  )
                : GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          MediaQuery.of(context).size.width > 600 ? 3 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _places.length,
                    itemBuilder: (context, index) {
                      final place = _places[index];
                      final image = place.coverImage.isNotEmpty
                          ? place.coverImage
                          : (place.galleryUrls.isNotEmpty
                              ? place.galleryUrls.first
                              : '');
                      return PlaceCard(
                        name: place.displayTitle,
                        category: place.locationName,
                        distance: place.formattedDistance,
                        imagePath: image,
                        placeId: place.id,
                        isFavorite: place.isFavorite,
                        onFavoriteToggle: () => _toggleFavorite(place),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PlaceDetailPage(place: place),
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
