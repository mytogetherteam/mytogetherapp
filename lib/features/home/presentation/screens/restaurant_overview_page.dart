import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/image_skeleton_loader.dart';
import '../../data/restaurant_data.dart';
import '../../data/models/shop_dto.dart';

class RestaurantOverviewPage extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantOverviewPage({super.key, required this.restaurant});

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
                  child: restaurant.imagePath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: restaurant.imagePath,
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
                        child: restaurant.logoPath.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: restaurant.logoPath,
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
                        context.localizedStatus(restaurant.status),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
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
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    icon: 'assets/images/detail_overview.png',
                    title: context.tr('restaurant.hours_title'),
                    customContent: Column(
                      children: _buildOperatingHours(context),
                    ),
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
    required String icon,
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
              Image.asset(icon, width: 32, height: 32),
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
