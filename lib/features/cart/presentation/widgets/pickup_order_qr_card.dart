import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

/// Branded pickup QR shown when the shop marks the order ready for pickup.
/// Payload is the numeric order id so myshop's [OrderQrParser] can resolve it.
class PickupOrderQrCard extends StatelessWidget {
  final String orderId;
  final String? lastOrderNo;

  const PickupOrderQrCard({
    super.key,
    required this.orderId,
    this.lastOrderNo,
  });

  String get _qrPayload => orderId.replaceAll('#', '').trim();

  String get _displayOrderNo {
    final ref = lastOrderNo?.trim();
    if (ref != null && ref.isNotEmpty) return ref;
    return orderId;
  }

  @override
  Widget build(BuildContext context) {
    if (_qrPayload.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            context.tr('order_status.pickup_qr_title'),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('order_status.pickup_qr_subtitle'),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: PrettyQrView.data(
              data: _qrPayload,
              decoration: const PrettyQrDecoration(
                shape: PrettyQrSmoothSymbol(
                  color: Colors.black,
                  roundFactor: 0.5,
                ),
                background: Colors.white,
                image: PrettyQrDecorationImage(
                  image: AssetImage('assets/images/app_icon_small.png'),
                  position: PrettyQrDecorationImagePosition.embedded,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _displayOrderNo,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
