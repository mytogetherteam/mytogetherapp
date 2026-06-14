import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../order/presentation/screens/order_history_page.dart';

/// Shown after the *user* cancels their own order (as opposed to the shop
/// cancelling it, which uses [OrderCancelPage]). It simply apologises for the
/// inconvenience and routes the user to their cancelled order history.
class OrderCancelByUserPage extends StatelessWidget {
  const OrderCancelByUserPage({super.key});

  /// Replaces the current navigation stack with the cancelled order history so
  /// both the back button and the primary action land in the same place.
  void _goToCancelledHistory(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const OrderHistoryPage(initialTabIndex: 1),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToCancelledHistory(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(PhosphorIcons.arrowLeft, color: Colors.black),
            onPressed: () => _goToCancelledHistory(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              PhosphorIcons.xCircleFill,
                              color: const Color(0xFFEF4444),
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            context.tr('order_cancel_user.title'),
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('order_cancel_user.message'),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              height: 1.5,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 12),
                  child: PrimaryGradientButton(
                    onPressed: () => _goToCancelledHistory(context),
                    child: Text(
                      context.tr('order_cancel_user.action'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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
