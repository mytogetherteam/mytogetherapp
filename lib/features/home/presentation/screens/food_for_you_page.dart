import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/location/location_service.dart';
import 'package:mytogetherapp/core/presentation/widgets/empty_state_view.dart';
import 'package:mytogetherapp/features/auth/data/repositories/user_location_repository.dart';
import '../widgets/food_feed_section.dart';

/// "For You" details page. Unlike the Trending/Popular pages this one has no
/// search bar — it simply shows the personalised feed (`for-you`).
class FoodForYouPage extends StatefulWidget {
  const FoodForYouPage({super.key});

  @override
  State<FoodForYouPage> createState() => _FoodForYouPageState();
}

class _FoodForYouPageState extends State<FoodForYouPage> {
  bool _isEmpty = false;

  @override
  Widget build(BuildContext context) {
    final activeLoc = UserLocationRepository.instance.activeLocation;
    final pos = LocationService().cachedPosition;
    final lat =
        activeLoc?.latitude ?? pos?.latitude ?? LocationService.defaultLat;
    final lon =
        activeLoc?.longitude ?? pos?.longitude ?? LocationService.defaultLon;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            context.tr('food.for_you'),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                FoodFeedSection(
                  feedType: 'for-you',
                  title: context.tr('food.for_you_now'),
                  latitude: lat,
                  longitude: lon,
                  onEmpty: (empty) {
                    if (mounted && empty != _isEmpty) {
                      setState(() => _isEmpty = empty);
                    }
                  },
                ),
                if (_isEmpty)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: const EmptyStateView(
                      icon: Icons.restaurant_menu_rounded,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
