import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../../home/data/models/home_discount_section_dto.dart';
import '../../../home/data/models/shop_feed_item_dto.dart';
import '../../../home/data/repositories/restaurant_repository.dart';
import '../../../home/presentation/screens/today_overview_detail_page.dart';
import '../../../home/presentation/widgets/discount_deal_card.dart';
import '../../../home/presentation/widgets/image_skeleton_loader.dart';
import '../../../home/presentation/widgets/view_all_icon_button.dart';

/// Food-tab discount rail driven by admin config from
/// `GET /api/user/home-discount-section`, with selectable chips when more than
/// one section is currently active.
class FoodDiscountSelectionSection extends StatefulWidget {
  const FoodDiscountSelectionSection({super.key});

  static const int previewItemLimit = 8;

  @override
  State<FoodDiscountSelectionSection> createState() =>
      _FoodDiscountSelectionSectionState();
}

class _FoodDiscountSelectionSectionState
    extends State<FoodDiscountSelectionSection> {
  bool _loadingConfig = true;
  bool _loadingDeals = false;
  List<HomeDiscountSectionDto> _activeSections = [];
  HomeDiscountSectionDto? _selected;
  DiscountDealsDto? _deals;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    if (!AuthService().isLoggedIn) {
      if (mounted) setState(() => _loadingConfig = false);
      return;
    }

    try {
      final config = await RestaurantRepository.instance
          .getHomeDiscountSectionConfig(forceRefresh: true)
          .timeout(const Duration(seconds: 5));

      final active = config.sections.where((s) => s.isActive).toList();
      if (active.isEmpty) {
        if (mounted) {
          setState(() {
            _loadingConfig = false;
            _activeSections = [];
          });
        }
        return;
      }

      final initial = config.activeSection != null &&
              config.activeSection!.isActive
          ? config.activeSection!
          : active.first;

      if (mounted) {
        setState(() {
          _activeSections = active;
          _selected = initial;
          _loadingConfig = false;
        });
      }
      await _loadDeals(initial);
    } catch (e) {
      debugPrint('FoodDiscountSelectionSection: config error: $e');
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  Future<void> _loadDeals(HomeDiscountSectionDto section) async {
    final location = await _resolveLocation();
    if (location == null) return;

    if (mounted) setState(() => _loadingDeals = true);

    try {
      final deals = await RestaurantRepository.instance
          .getDiscountDeals(
            lat: location.lat,
            lon: location.lon,
            percentage: section.discountPercent,
            size: FoodDiscountSelectionSection.previewItemLimit,
            sectionTitle: section.hasTitle ? section.title : null,
            forceRefresh: true,
          )
          .timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          _deals = deals;
          _loadingDeals = false;
        });
      }
    } catch (e) {
      debugPrint('FoodDiscountSelectionSection: deals error: $e');
      if (mounted) setState(() => _loadingDeals = false);
    }
  }

  Future<_LatLng?> _resolveLocation() async {
    final activeLoc = UserLocationRepository.instance.activeLocation;
    final savedLat = activeLoc?.latitude;
    final savedLon = activeLoc?.longitude;
    if (savedLat != null && savedLon != null) {
      return _LatLng(savedLat, savedLon);
    }

    final service = LocationService();
    await service.getCurrentPosition();
    final pos = service.cachedPosition;
    if (pos == null) return null;
    return _LatLng(pos.latitude, pos.longitude);
  }

  Future<void> _onSectionSelected(HomeDiscountSectionDto section) async {
    if (_selected?.id == section.id) return;
    setState(() => _selected = section);
    await _loadDeals(section);
  }

  void _openDiscountDetail(String headerTitle) {
    final section = _selected;
    if (section == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TodayOverviewDetailPage(
          feedType: 'hot-deals',
          title: headerTitle,
          discountPercentage: section.discountPercent,
          discountSectionTitle: section.hasTitle ? section.title : null,
        ),
      ),
    );
  }

  String _sectionChipLabel(
    BuildContext context,
    HomeDiscountSectionDto section,
  ) {
    final title = section.title?.trim();
    if (title != null && title.isNotEmpty) {
      return title.replaceAll('{}', '${section.discountPercent}%');
    }
    return context.trArgs(
      'home.up_to_off_pct',
      {'percent': '${section.discountPercent}'},
    );
  }

  bool _hasMoreDeals(DiscountDealsDto deals) {
    return deals.totalCount > FoodDiscountSelectionSection.previewItemLimit;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingConfig) return _buildSkeleton(context);
    if (_activeSections.isEmpty || _selected == null) {
      return const SizedBox.shrink();
    }

    final dealsDto = _deals;
    final deals = (dealsDto?.items ?? [])
        .take(FoodDiscountSelectionSection.previewItemLimit)
        .toList();
    if (!_loadingDeals && deals.isEmpty) return const SizedBox.shrink();

    final apiTitle = dealsDto?.sectionTitle.trim() ?? '';
    final headerTitle = apiTitle.isNotEmpty
        ? apiTitle
        : _sectionChipLabel(context, _selected!);
    final maxPercent = (dealsDto?.maxDiscountPercentage ?? 0) > 0
        ? dealsDto!.maxDiscountPercentage
        : _selected!.discountPercent;
    final showViewAll =
        dealsDto != null && _hasMoreDeals(dealsDto) && !_loadingDeals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        headerTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (maxPercent > 0) ...[
                      const SizedBox(width: 8),
                      _UpToBadge(percent: maxPercent),
                    ],
                  ],
                ),
              ),
              if (showViewAll)
                ViewAllIconButton(
                  onPressed: () => _openDiscountDetail(headerTitle),
                ),
            ],
          ),
        ),
        if (_activeSections.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _activeSections.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final section = _activeSections[index];
                final selected = section.id == _selected!.id;
                return FilterChip(
                  label: Text(
                    _sectionChipLabel(context, section),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: const Color(0xFFF3F4F6),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onSelected: (_) => _onSectionSelected(section),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_loadingDeals)
          _buildDealsSkeleton()
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20, right: 20),
              itemCount: deals.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  DiscountDealCard(deal: deals[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const ImageSkeletonLoader(width: 160, height: 18),
          ),
        ),
        const SizedBox(height: 12),
        _buildDealsSkeleton(),
      ],
    );
  }

  Widget _buildDealsSkeleton() {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 20),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => SizedBox(
          width: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: const ImageSkeletonLoader(
                  width: 130,
                  height: 120,
                  showLogo: true,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const ImageSkeletonLoader(width: 60, height: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpToBadge extends StatelessWidget {
  final int percent;
  const _UpToBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        context.trArgs('home.up_to_off_pct', {'percent': '$percent'}).trim(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LatLng {
  final double lat;
  final double lon;
  const _LatLng(this.lat, this.lon);
}
