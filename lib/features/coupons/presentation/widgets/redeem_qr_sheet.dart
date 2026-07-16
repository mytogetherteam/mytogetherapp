import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cart/data/coupon_service.dart';

/// Bottom sheet shown by the "Use now" action. Displays the user's rotating,
/// short-lived redeem QR for in-shop redemption. The shop admin scans it, then
/// picks the coupon to apply on their side — the QR itself is per-user, not
/// per-coupon, which is why the same code is shown from any coupon.
class RedeemQrSheet extends StatefulWidget {
  /// Optional coupon name shown as context above the QR.
  final String? couponName;

  const RedeemQrSheet({super.key, this.couponName});

  static Future<void> show(BuildContext context, {String? couponName}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RedeemQrSheet(couponName: couponName),
    );
  }

  @override
  State<RedeemQrSheet> createState() => _RedeemQrSheetState();
}

class _RedeemQrSheetState extends State<RedeemQrSheet> {
  RedeemTokenResult? _token;
  String? _error;
  bool _loading = true;
  int _remaining = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _issue();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _issue() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await CouponService.instance.issueRedeemToken();
      if (!mounted) return;
      setState(() {
        _token = token;
        _remaining = token.expiresInSec;
        _loading = false;
      });
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _ticker?.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  String get _countdownLabel {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              context.tr('coupon.redeem_title'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('coupon.redeem_hint'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: Colors.grey.shade600,
              ),
            ),
            if (widget.couponName != null &&
                widget.couponName!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.couponName!,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildQrArea(context),
            const SizedBox(height: 24),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildQrArea(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _token == null) {
      return SizedBox(
        height: 240,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.grey.shade400, size: 40),
            const SizedBox(height: 12),
            Text(
              _error ?? context.tr('coupon.redeem_error'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _issue,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.tr('common.retry')),
            ),
          ],
        ),
      );
    }

    final expired = _remaining <= 0;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEDEDED)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: expired ? 0.15 : 1,
                child: SizedBox(
                  width: 220,
                  height: 220,
                  // Same renderer/style as the order pickup QR
                  // (PickupOrderQrCard) so both QRs look identical.
                  child: PrettyQrView.data(
                    data: _token!.qrPayload,
                    // High error correction (~30%) is required so the centered
                    // logo doesn't make the code unscannable, plus a standard
                    // 4-module quiet zone. The coupon payload is denser than the
                    // pickup one, so these margins matter even more here.
                    errorCorrectLevel: QrErrorCorrectLevel.H,
                    decoration: const PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(
                        color: Colors.black,
                        roundFactor: 0.5,
                      ),
                      background: Colors.white,
                      quietZone: PrettyQrQuietZone.standard,
                      image: PrettyQrDecorationImage(
                        image: AssetImage('assets/images/app_icon_small.png'),
                        position: PrettyQrDecorationImagePosition.embedded,
                        scale: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
              if (expired)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        color: AppColors.primary, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('coupon.redeem_expired'),
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (expired)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _issue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                context.tr('coupon.redeem_refresh'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined,
                  size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                context.trArgs('coupon.redeem_expires_in', {
                  'time': _countdownLabel,
                }),
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
