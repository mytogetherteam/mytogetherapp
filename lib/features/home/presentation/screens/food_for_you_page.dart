import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mytogetherapp/core/auth/guest_auth_guard.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/guest_account_required_section.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
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
  double? _lat;
  double? _lon;

  @override
  void initState() {
    super.initState();
    _loadCoords();
  }

  Future<void> _loadCoords() async {
    final coords =
        await UserLocationRepository.instance.resolveActiveCoordinates();
    if (mounted) {
      setState(() {
        _lat = coords.lat;
        _lon = coords.lon;
      });
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.light,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (GuestAuthGuard.isGuest) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(context),
          body: Center(
            child: GuestAccountRequiredSection(
              title: context.tr('food.for_you_guest_title'),
              subtitle: context.tr('food.for_you_guest_message'),
              height: 240,
            ),
          ),
        ),
      );
    }

    final lat = _lat;
    final lon = _lon;

    if (lat == null || lon == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(context),
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
