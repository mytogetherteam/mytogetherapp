import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/location/location_service.dart';
import 'package:mytogetherapp/core/presentation/utils/paginated_list_controller.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/pagination_list_footer.dart';
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
  static const int _pageSize = 20;

  late final PaginatedListController<PlaceDto> _pagination;
  final ScrollController _scrollController = ScrollController();
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _pagination = PaginatedListController<PlaceDto>(
      pageSize: _pageSize,
      initialPage: 1,
      itemKey: (place) => place.id,
      fetchPage: _fetchPage,
    )..addListener(_onPaginationChanged);
    _pagination.attachScrollController(_scrollController);
    _bootstrap();
  }

  void _onPaginationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await WishlistRepository.instance.loadAll();
    final pos = await LocationService().getCurrentPosition();
    _latitude = pos.latitude;
    _longitude = pos.longitude;
    await _pagination.loadInitial();
  }

  Future<PaginatedPage<PlaceDto>> _fetchPage(int page) async {
    final lat = _latitude;
    final lon = _longitude;
    if (lat == null || lon == null) {
      return const PaginatedPage(items: [], hasMore: false);
    }

    final feed = await PlacesRepository.instance.fetchPlaces(
      page: page,
      size: _pageSize,
      latitude: lat,
      longitude: lon,
    );
    final repo = WishlistRepository.instance;
    final items = feed.items
        .map((p) => p.copyWith(isFavorite: repo.isPlaceSaved(p.id)))
        .toList();
    final loadedCount = (page - 1) * _pageSize + items.length;
    return PaginatedPage(
      items: items,
      hasMore: loadedCount < feed.total,
    );
  }

  @override
  void dispose() {
    _pagination
      ..removeListener(_onPaginationChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await WishlistRepository.instance.loadAll();
    await _pagination.refresh();
  }

  Future<void> _toggleFavorite(PlaceDto place) async {
    final next = !place.isFavorite;
    final index = _pagination.items.indexWhere((p) => p.id == place.id);
    if (index != -1) {
      setState(() {
        _pagination.items[index] = place.copyWith(isFavorite: next);
      });
    }
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
      if (mounted && index != -1) {
        setState(() {
          _pagination.items[index] = place.copyWith(isFavorite: !next);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final places = _pagination.items;
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
        onRefresh: _refresh,
        color: Theme.of(context).primaryColor,
        child: _pagination.isInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : places.isEmpty
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
                    controller: _scrollController,
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
                    itemCount: places.length + (_pagination.showFooter ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= places.length) {
                        return PaginationListFooter(
                          isLoading: _pagination.isLoadingMore,
                          showEndMessage: !_pagination.hasMore,
                        );
                      }
                      _pagination.onItemVisible(index);
                      final place = places[index];
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
