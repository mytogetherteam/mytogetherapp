import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/core/network/media_url.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/image_skeleton_loader.dart';
import '../widgets/restaurant_open_status.dart';
import '../../../../core/location/location_service.dart';
import '../../data/restaurant_data.dart';
import '../../data/models/shop_dto.dart';
import '../../data/repositories/restaurant_repository.dart';

class RestaurantOverviewPage extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantOverviewPage({super.key, required this.restaurant});

  @override
  State<RestaurantOverviewPage> createState() => _RestaurantOverviewPageState();
}

class _RestaurantOverviewPageState extends State<RestaurantOverviewPage> {
  /// Seeded immediately from the passed-in restaurant so the header renders at
  /// once, then replaced with the fully-loaded detail (address, hours, etc.).
  late Restaurant restaurant = widget.restaurant;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  /// The overview is often opened before the parent detail page finishes its
  /// own async load, so it can arrive with only seed data. Fetch the complete
  /// shop here so address/hours/payment/features are always present on first
  /// open instead of only after a refresh/re-entry.
  Future<void> _loadDetails() async {
    final id = int.tryParse(widget.restaurant.id);
    if (id == null) return;
    try {
      final pos = LocationService().cachedPosition;
      final full = await RestaurantRepository.instance.getShopById(
        id,
        lat: pos?.latitude ?? LocationService.defaultLat,
        lon: pos?.longitude ?? LocationService.defaultLon,
      );
      if (mounted) {
        setState(() => restaurant = full);
      }
    } catch (_) {
      // Keep the seed data on failure; payment section still self-loads.
    }
  }

  String _localizedAddress(BuildContext context) {
    final localized = context.localized(
      en: restaurant.addressEn,
      mm: restaurant.addressMm,
      th: restaurant.addressTh,
    );
    if (localized.isNotEmpty) return localized;
    final fallback = restaurant.address?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return context.tr('restaurant.no_address');
  }

  @override
  Widget build(BuildContext context) {
    final openStatus = RestaurantOpenStatus.of(context, restaurant);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('restaurant.overview_title'),
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                  ),
                  child: resolveMediaUrl(restaurant.imagePath).isNotEmpty
                      ? CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                          imageUrl: resolveMediaUrl(restaurant.imagePath),
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const ImageSkeletonLoader(),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.restaurant,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                ),
                Positioned(
                  bottom: -40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: resolveMediaUrl(restaurant.logoPath).isNotEmpty
                            ? CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                imageUrl: resolveMediaUrl(restaurant.logoPath),
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    const ImageSkeletonLoader(),
                                errorWidget: (context, url, error) =>
                                    _buildLogoFallback(restaurant.name),
                              )
                            : _buildLogoFallback(restaurant.name),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Center(
                    child: Text(
                      restaurant.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          restaurant.category,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (restaurant.rating > 0) ...[
                          Text('  •  ', style: TextStyle(color: Colors.grey[400])),
                          Text(
                            '${restaurant.rating}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoItem(PhosphorIcons.car, restaurant.distance),
                      _buildDot(),
                      _buildInfoItem(PhosphorIcons.clock, restaurant.deliveryTime),
                      _buildDot(),
                      Text(
                        openStatus.text,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: openStatus.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (openStatus.nextOpenText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      openStatus.nextOpenText!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildSectionCard(
                    icon: 'assets/images/detail_direction.png',
                    title: context.tr('restaurant.address_title'),
                    content: _localizedAddress(context),
                  ),
                  if (restaurant.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      iconData: PhosphorIcons.info,
                      title: context.tr('restaurant.description_title'),
                      content: restaurant.description.trim(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    icon: 'assets/images/detail_overview.png',
                    title: context.tr('restaurant.hours_title'),
                    customContent: Column(
                      children: _buildOperatingHours(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    iconData: PhosphorIcons.wallet,
                    title: context.tr('restaurant.payment_title'),
                    customContent: _PaymentMethodsSection(
                      shopId: int.tryParse(restaurant.id),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    iconData: PhosphorIcons.sparkle,
                    title: context.tr('restaurant.features_title'),
                    customContent: _buildFeatures(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOperatingHours(BuildContext context) {
    if (restaurant.operatingHours.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Text(
            context.tr('restaurant.hours_unavailable'),
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[800]),
          ),
        ),
      ];
    }

    int mondayFirstIndex(String day) {
      final number = int.tryParse(day);
      if (number != null) {
        if (number == 0) return 7;
        if (number >= 1 && number <= 7) return number;
        return 8;
      }

      switch (day.toUpperCase()) {
        case 'MONDAY':
          return 1;
        case 'TUESDAY':
          return 2;
        case 'WEDNESDAY':
          return 3;
        case 'THURSDAY':
          return 4;
        case 'FRIDAY':
          return 5;
        case 'SATURDAY':
          return 6;
        case 'SUNDAY':
          return 7;
        default:
          return 8;
      }
    }

    final dayNames = <int, String>{
      1: context.tr('common.day_monday'),
      2: context.tr('common.day_tuesday'),
      3: context.tr('common.day_wednesday'),
      4: context.tr('common.day_thursday'),
      5: context.tr('common.day_friday'),
      6: context.tr('common.day_saturday'),
      7: context.tr('common.day_sunday'),
    };

    String formatDayName(String day) {
      final name = dayNames[mondayFirstIndex(day)];
      if (name != null) return name;
      if (day.isEmpty) return '';
      return day[0].toUpperCase() + day.substring(1).toLowerCase();
    }

    final sortedHours = List<OperatingHourDto>.from(restaurant.operatingHours)
      ..sort(
        (a, b) => mondayFirstIndex(a.dayOfWeek)
            .compareTo(mondayFirstIndex(b.dayOfWeek)),
      );

    final currentDay = DateTime.now().weekday;

    return sortedHours.asMap().entries.map((entry) {
      final int index = entry.key;
      final h = entry.value;
      final bool isLast = index == sortedHours.length - 1;
      final bool isToday = mondayFirstIndex(h.dayOfWeek) == currentDay;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDayName(h.dayOfWeek),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: isToday
                            ? AppColors.primary
                            : const Color(0xFF2D3748),
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    if (isToday)
                      Text(
                        h.isClosed
                            ? context.tr('restaurant.closed_today')
                            : context.tr('restaurant.open_today'),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: h.isClosed ? Colors.red : const Color(0xFF10B981),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: Text(
                    h.isClosed
                        ? context.tr('common.closed')
                        : h.displayTime24h.replaceAll('-', '–'),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: h.isClosed
                          ? AppColors.primary
                          : const Color(0xFF718096),
                      fontWeight:
                          h.isClosed ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(
              color: Colors.grey[200],
              height: 1,
              thickness: 1,
            ),
        ],
      );
    }).toList();
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('•', style: TextStyle(color: Colors.grey[400])),
    );
  }

  Widget _buildSectionCard({
    String? icon,
    IconData? iconData,
    required String title,
    String? content,
    Widget? customContent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Image.asset(icon, width: 32, height: 32)
              else if (iconData != null)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(iconData, size: 24, color: AppColors.primary),
                ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (content != null)
            Text(
              content,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
          customContent ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildFeatures(BuildContext context) {
    final features = <_Feature>[
      _Feature(
        PhosphorIcons.car,
        context.tr('restaurant.feature_parking'),
        restaurant.hasParking,
      ),
      _Feature(
        PhosphorIcons.wifiHigh,
        context.tr('restaurant.feature_wifi'),
        restaurant.hasWifi,
      ),
      _Feature(
        PhosphorIcons.forkKnife,
        context.tr('restaurant.feature_halal'),
        restaurant.isHalal,
      ),
      _Feature(
        PhosphorIcons.leaf,
        context.tr('restaurant.feature_vegetarian'),
        restaurant.isVegetarian,
      ),
    ];

    return Column(
      children: features.asMap().entries.map((entry) {
        final f = entry.value;
        final bool isLast = entry.key == features.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
          child: Row(
            children: [
              _buildFeatureToggle(f.enabled),
              const SizedBox(width: 14),
              Icon(
                f.icon,
                size: 20,
                color: f.enabled ? AppColors.primary : Colors.grey[400],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  f.label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: f.enabled
                        ? const Color(0xFF2D3748)
                        : Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Read-only pill toggle mirroring the shop's amenity state. The customer
  /// can see whether a feature is offered but cannot change it here.
  Widget _buildFeatureToggle(bool enabled) {
    const double width = 42;
    const double height = 24;
    const double knob = 18;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: enabled ? AppColors.primary : Colors.grey[300],
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Align(
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: knob,
            height: knob,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoFallback(String name) {
    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String label;
  final bool enabled;

  const _Feature(this.icon, this.label, this.enabled);
}

/// Shows the payment methods configured for a specific shop.
///
/// Loads from the dedicated `GET /user/shops/:shopId/payment-methods`
/// endpoint so only the restaurant's own (active) methods are shown, instead
/// of the full catalogue that the shop-detail payload sometimes carries.
class _PaymentMethodsSection extends StatefulWidget {
  final int? shopId;

  const _PaymentMethodsSection({required this.shopId});

  @override
  State<_PaymentMethodsSection> createState() => _PaymentMethodsSectionState();
}

class _PaymentMethodsSectionState extends State<_PaymentMethodsSection> {
  late final Future<List<ShopPaymentTypeDto>> _future = _load();

  Future<List<ShopPaymentTypeDto>> _load() async {
    final id = widget.shopId;
    if (id == null) return const [];
    final methods =
        await RestaurantRepository.instance.getShopPaymentMethods(id);
    return methods.where((m) => m.isActive).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShopPaymentTypeDto>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final methods = snapshot.data ?? const [];
        if (methods.isEmpty) {
          return Text(
            context.tr('restaurant.payment_unavailable'),
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          );
        }

        return Column(
          children: methods.asMap().entries.map((entry) {
            final bool isLast = entry.key == methods.length - 1;
            final method = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      _buildPaymentIcon(method),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          method.displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2D3748),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(color: Colors.grey[200], height: 1, thickness: 1),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPaymentIcon(ShopPaymentTypeDto method) {
    final iconUrl = _normalizeImageUrl(method.iconUrl);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: iconUrl != null
          ? Image.network(
              iconUrl,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) =>
                  _fallbackPaymentIcon(method),
            )
          : _fallbackPaymentIcon(method),
    );
  }

  Widget _fallbackPaymentIcon(ShopPaymentTypeDto method) {
    return Center(
      child: Icon(
        method.isCashOnDelivery
            ? PhosphorIcons.money
            : (method.qrImageUrl != null && method.qrImageUrl!.isNotEmpty)
                ? PhosphorIcons.qrCode
                : PhosphorIcons.creditCard,
        color: const Color(0xFF64748B),
        size: 20,
      ),
    );
  }

  /// Rewrites a stored image path/URL to an absolute, reachable URL.
  String? _normalizeImageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var imageUrl = raw.replaceAll('\\', '/');
    if (imageUrl.startsWith('http://localhost') ||
        imageUrl.startsWith('http://10.0.2.2')) {
      imageUrl = imageUrl.replaceAll(
        RegExp(r'http://(localhost|10\.0\.2\.2)(:\d+)?'),
        ApiClient.baseUrl,
      );
    } else if (!imageUrl.startsWith('http')) {
      imageUrl = imageUrl.startsWith('/')
          ? '${ApiClient.baseUrl}$imageUrl'
          : '${ApiClient.baseUrl}/$imageUrl';
    }
    return imageUrl;
  }
}

