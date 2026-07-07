import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../cart/data/coupon_service.dart';
import '../widgets/coupon_details_sheet.dart';
import '../widgets/coupon_display.dart';

/// Saved coupons from `GET /user/coupons/wishlist`.
/// Opened from Profile → Saved Coupons (separate from Saved Items wishlist).
class SavedCouponsPage extends StatefulWidget {
  const SavedCouponsPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SavedCouponsPage()),
    );
  }

  @override
  State<SavedCouponsPage> createState() => _SavedCouponsPageState();
}

class _SavedCouponsPageState extends State<SavedCouponsPage> {
  bool _loading = true;
  List<CouponModel> _coupons = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (!AuthService().isLoggedIn) {
        if (!mounted) return;
        setState(() {
          _coupons = const [];
          _loading = false;
        });
        return;
      }
      CouponService.instance.invalidateWishlistCache();
      final coupons = await CouponService.instance.fetchWishlist(size: 100);
      if (!mounted) return;
      setState(() {
        _coupons = coupons;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _browseCoupons() {
    NavigationController.instance.goToHomeTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          context.tr('profile.saved_coupons'),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.black87,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _coupons.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _coupons.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final coupon = _coupons[index];
                      return CouponBrowseCard(
                        coupon: coupon,
                        width: null,
                        onTap: () async {
                          await CouponDetailsSheet.show(context, coupon);
                          if (!mounted) return;
                          _load();
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIconsFill.ticket,
                      size: 56,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('coupon.saved_empty_title'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('coupon.saved_empty'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryGradientButton(
                    onPressed: _browseCoupons,
                    width: 220,
                    child: Text(
                      context.tr('coupon.browse_coupons'),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
