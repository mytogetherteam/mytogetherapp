import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/features/wishlist/data/repositories/wishlist_repository.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../../core/location/location_refresh_mixin.dart';
import 'place_card.dart';
import 'view_all_icon_button.dart';
import '../../data/models/place_dto.dart';
import '../../data/repositories/places_repository.dart';
import '../screens/place_detail_page.dart';
import '../screens/places_list_page.dart';
import '../../../../core/auth/guest_auth_guard.dart';
import '../../../../core/presentation/widgets/guest_account_required_section.dart';

class TopPlacesNearbySection extends StatefulWidget {
  const TopPlacesNearbySection({super.key});

  @override
  State<TopPlacesNearbySection> createState() => _TopPlacesNearbySectionState();
}

class _TopPlacesNearbySectionState extends State<TopPlacesNearbySection>
    with LocationRefreshMixin {
  List<PlaceDto> _places = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void onActiveLocationChanged() {
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    try {
      await WishlistRepository.instance.loadAll();
      final coords =
          await UserLocationRepository.instance.resolveActiveCoordinates();
      final feed = await PlacesRepository.instance.fetchPlaces(
        page: 1,
        size: 10,
        latitude: coords.lat,
        longitude: coords.lon,
      );
      if (mounted) {
        setState(() {
          _places = feed.items;
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
    if (GuestAuthGuard.isGuest) {
      return GuestAccountRequiredSection(
        title: context.tr('home.top_places_nearby'),
        subtitle: context.tr('guest.need_account_message'),
        height: 160,
      );
    }

    if (_isLoading) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_places.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('home.top_places_nearby'),
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
                    MaterialPageRoute(
                      builder: (context) => const PlacesListPage(),
                    ),
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
              final image = place.coverImage.isNotEmpty
                  ? place.coverImage
                  : (place.galleryUrls.isNotEmpty
                      ? place.galleryUrls.first
                      : '');
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 240,
                  height: 320,
                  child: PlaceCard(
                    name: place.displayTitle,
                    category: place.locationName,
                    distance: place.formattedDistance,
                    imagePath: image,
                    isFavorite: place.isFavorite,
                    onFavoriteToggle: () => _toggleFavorite(place),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaceDetailPage(place: place),
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
