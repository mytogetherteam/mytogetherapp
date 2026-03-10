import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/image_skeleton_loader.dart';
import '../../data/restaurant_data.dart';


class RestaurantOverviewPage extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantOverviewPage({super.key, required this.restaurant});

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
          'Restaurant Overview',
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
            // Hero Image Section
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
                          placeholder: (context, url) => const ImageSkeletonLoader(),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.restaurant, size: 50, color: Colors.grey),
                        ),
                ),
                // Overlapping Logo
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
                        border: Border.all(color: const Color(0xFFED3973), width: 2.5),
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
                                placeholder: (context, url) => const ImageSkeletonLoader(),
                                errorWidget: (context, url, error) => _buildLogoFallback(restaurant.name),
                              )
                            : _buildLogoFallback(restaurant.name),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // Header Info
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
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoItem(PhosphorIcons.car(), restaurant.distance),
                      _buildDot(),
                      _buildInfoItem(PhosphorIcons.clock(), restaurant.deliveryTime),
                      _buildDot(),
                      Text(
                        restaurant.status,
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

            // Info Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildSectionCard(
                    icon: 'assets/images/detail_overview.png',
                    title: 'Restaurant Address',
                    content: restaurant.addressMm ?? restaurant.address ?? 'No address available',
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    icon: 'assets/images/detail_chat.png', // Using bell for hours ref image if needed, or custom icon
                    title: 'Service Hours',
                    customContent: Column(
                      children: restaurant.operatingHours
                          .where((h) => !h.isClosed)
                          .take(1) // Usually shops have same hours, or show the first one
                          .map((h) => Text(
                                h.displayTime,
                                style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[800]),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    icon: 'assets/images/order_confirmed.png', // Ref for closing icon
                    title: 'Regular Closing Day',
                    customContent: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: restaurant.operatingHours
                          .where((h) => h.isClosed)
                          .map((h) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      h.dayOfWeek,
                                      style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[800]),
                                    ),
                                    Text(
                                      '10:00 AM - 9:00 PM', // Matches reference style where even closed days show range? Wait.
                                      style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[800]),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
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
                  fontSize: 17,
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFED3973),
            Color(0xFFF97316),
          ],
        ),
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
