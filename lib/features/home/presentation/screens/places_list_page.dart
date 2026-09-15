import "package:flutter/material.dart";
import "package:mytogetherapp/core/localization/app_translations.dart";
import "package:google_fonts/google_fonts.dart";
import "package:mytogetherapp/core/location/location_service.dart";
import "package:mytogetherapp/core/presentation/utils/paginated_list_controller.dart";
import "package:mytogetherapp/core/presentation/widgets/app_dialog.dart";
import "package:mytogetherapp/core/presentation/widgets/pagination_list_footer.dart";
import "package:mytogetherapp/core/theme/app_colors.dart";
import "package:mytogetherapp/features/wishlist/data/repositories/wishlist_repository.dart";
import "package:mytogetherapp/features/wishlist/presentation/screens/wishlist_page.dart";
import "../widgets/place_card.dart";
import "../../data/models/place_dto.dart";
import "../../data/repositories/places_repository.dart";
import "place_detail_page.dart";

class _ActivityFilterItem {
  final String key;
  final String labelKey;
  final String defaultLabel;
  final String icon;

  const _ActivityFilterItem({
    required this.key,
    required this.labelKey,
    required this.defaultLabel,
    required this.icon,
  });
}

const List<_ActivityFilterItem> _activityFilters = [
  _ActivityFilterItem(key: "ALL", labelKey: "place.filter_all", defaultLabel: "All", icon: "✨"),
  _ActivityFilterItem(key: "BADMINTON", labelKey: "place.activity_badminton", defaultLabel: "Badminton", icon: "🏸"),
  _ActivityFilterItem(key: "SWIMMING", labelKey: "place.activity_swimming", defaultLabel: "Swimming", icon: "🏊"),
  _ActivityFilterItem(key: "FOOTBALL", labelKey: "place.activity_football", defaultLabel: "Football", icon: "⚽"),
  _ActivityFilterItem(key: "FUTSAL", labelKey: "place.activity_futsal", defaultLabel: "Futsal", icon: "🥅"),
  _ActivityFilterItem(key: "GYM", labelKey: "place.activity_gym", defaultLabel: "Gym", icon: "🏋️"),
  _ActivityFilterItem(key: "MUAY_THAI", labelKey: "place.activity_muay_thai", defaultLabel: "Muay Thai", icon: "🥊"),
  _ActivityFilterItem(key: "TENNIS", labelKey: "place.activity_tennis", defaultLabel: "Tennis", icon: "🎾"),
  _ActivityFilterItem(key: "ICE_SKATING", labelKey: "place.activity_ice_skating", defaultLabel: "Ice Skating", icon: "🧊"),
  _ActivityFilterItem(key: "GAMES", labelKey: "place.activity_games", defaultLabel: "Games", icon: "🎳"),
  _ActivityFilterItem(key: "ROOFTOP_VIEW", labelKey: "place.activity_rooftop", defaultLabel: "Rooftop", icon: "🏙️"),
  _ActivityFilterItem(key: "NIGHT_MARKET", labelKey: "place.activity_night_market", defaultLabel: "Night Market", icon: "🏮"),
];

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
  String _selectedActivity = "ALL";

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
      activity: _selectedActivity == "ALL" ? null : _selectedActivity,
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

  void _onSelectActivity(String key) {
    if (_selectedActivity == key) return;
    setState(() {
      _selectedActivity = key;
    });
    _pagination.refresh();
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
          context.tr(next ? "wishlist.saved" : "wishlist.removed"),
          actionLabel: next ? context.tr("wishlist.view_action") : null,
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

  Widget _buildActivityChips(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _activityFilters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _activityFilters[index];
          final isSelected = _selectedActivity == filter.key;
          final localizedLabel = context.tr(filter.labelKey);
          final label = localizedLabel != filter.labelKey
              ? localizedLabel
              : filter.defaultLabel;

          return GestureDetector(
            onTap: () => _onSelectActivity(filter.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter.icon,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
          context.tr("place.nearby_places"),
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildActivityChips(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: Theme.of(context).primaryColor,
              child: _pagination.isInitialLoading
                  ? const Center(child: CircularProgressIndicator())
                  : places.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Center(
                                child: Text(context.tr("place.none_found")),
                              ),
                            ),
                          ],
                        )
                      : GridView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                MediaQuery.of(context).size.width > 600 ? 3 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.72,
                          ),
                          itemCount:
                              places.length + (_pagination.showFooter ? 1 : 0),
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
                                    : "");
                            return PlaceCard(
                              name: place.displayTitle,
                              category: place.locationName,
                              distance: place.formattedDistance,
                              imagePath: image,
                              primaryActivity: place.primaryActivity,
                              startingPrice: place.startingPrice,
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
          ),
        ],
      ),
    );
  }
}
