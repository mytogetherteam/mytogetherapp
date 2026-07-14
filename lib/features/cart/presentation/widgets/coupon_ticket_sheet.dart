import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../data/coupon_service.dart';
import '../../../coupons/presentation/widgets/coupon_display.dart';

/// Shows the movie-ticket style coupon picker as a bottom sheet.
///
/// Returns the chosen [CouponModel] when the user selects one (the coupon is
/// applied to the order later, at "Place Order"), or `null` when they skip /
/// dismiss. Pass [selectedId] to pre-highlight a previously chosen coupon.
Future<CouponModel?> showCouponTicketSheet({
  required BuildContext context,
  required List<CouponModel> coupons,
  int? selectedId,
}) {
  return showModalBottomSheet<CouponModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) =>
        CouponTicketSheet(coupons: coupons, initialSelectedId: selectedId),
  );
}

class CouponTicketSheet extends StatefulWidget {
  final List<CouponModel> coupons;
  final int? initialSelectedId;

  const CouponTicketSheet({
    super.key,
    required this.coupons,
    this.initialSelectedId,
  });

  @override
  State<CouponTicketSheet> createState() => _CouponTicketSheetState();
}

class _CouponTicketSheetState extends State<CouponTicketSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tearController;
  int? _selectedId;
  int? _tearingId;

  @override
  void initState() {
    super.initState();
    _tearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _selectedId = widget.initialSelectedId ??
        (widget.coupons.length == 1 ? widget.coupons.first.id : null);
  }

  @override
  void dispose() {
    _tearController.dispose();
    super.dispose();
  }

  CouponModel? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final c in widget.coupons) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Plays the ticket-tear animation as the "this is my coupon" gesture, then
  /// returns the chosen coupon to the summary page (no network call here — the
  /// coupon is applied to the real order when the user places it).
  Future<void> _confirmSelected() async {
    final coupon = _selected;
    if (coupon == null || _tearingId != null) return;

    setState(() => _tearingId = coupon.id);
    HapticFeedback.mediumImpact();
    await _tearController.forward();
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    Navigator.of(context).pop(coupon);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.82;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    PhosphorIconsFill.ticket,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('coupon.sheet_title'),
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        context.tr('coupon.sheet_subtitle'),
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.coupons.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final coupon = widget.coupons[index];
                final isSelected = coupon.id == _selectedId;
                final isTearing = coupon.id == _tearingId;
                return AnimatedBuilder(
                  animation: _tearController,
                  builder: (context, _) {
                    return CouponTicket(
                      coupon: coupon,
                      selected: isSelected,
                      tearProgress: isTearing ? _tearController.value : 0,
                      dimmed: _tearingId != null && !isTearing,
                      onTap: (_tearingId != null)
                          ? null
                          : () => setState(() {
                                _selectedId =
                                    isSelected ? null : coupon.id;
                              }),
                    );
                  },
                );
              },
            ),
          ),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final hasSelection = _selected != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: TextButton(
                onPressed: (_tearingId != null)
                    ? null
                    : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Text(
                  context.tr('coupon.skip'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Opacity(
                opacity: hasSelection ? 1 : 0.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextButton(
                    onPressed: (!hasSelection || _tearingId != null)
                        ? null
                        : _confirmSelected,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      context.tr('coupon.use_coupon'),
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single movie-ticket style coupon card with a horizontal "tear" animation.
class CouponTicket extends StatelessWidget {
  final CouponModel coupon;
  final bool selected;
  final double tearProgress; // 0 = intact, 1 = fully torn
  final bool dimmed;
  final VoidCallback? onTap;

  static const double _height = 138;
  static const double _stubWidth = 104;
  static const Color _bodyColor = Color(0xFFFBF7EF);
  static const Color _holeColor = Colors.white;

  const CouponTicket({
    super.key,
    required this.coupon,
    this.selected = false,
    this.tearProgress = 0,
    this.dimmed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tearing = tearProgress > 0;

    Widget ticket;
    if (!tearing) {
      ticket = _buildTicketBody(context);
    } else {
      // Split the ticket into two jagged halves and pull them apart.
      final t = Curves.easeInCubic.transform(tearProgress);
      final body = _buildTicketBody(context);
      ticket = SizedBox(
        height: _height,
        child: Stack(
          children: [
            // success badge revealed underneath the torn pieces
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: Curves.easeIn.transform(tearProgress),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr('coupon.selected'),
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(-22 * t, -34 * t),
                child: Transform.rotate(
                  alignment: Alignment.bottomLeft,
                  angle: -0.06 * t,
                  child: Opacity(
                    opacity: 1 - (t * 0.95),
                    child: ClipPath(
                      clipper: _TearClipper(top: true),
                      child: body,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(22 * t, 38 * t),
                child: Transform.rotate(
                  alignment: Alignment.topRight,
                  angle: 0.06 * t,
                  child: Opacity(
                    opacity: 1 - (t * 0.95),
                    child: ClipPath(
                      clipper: _TearClipper(top: false),
                      child: body,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: dimmed ? 0.35 : 1,
        child: ticket,
      ),
    );
  }

  Widget _buildTicketBody(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Row(
                children: [
                  Expanded(child: _buildLeftBody(context)),
                  _buildStub(context),
                ],
              ),
            ),
          ),
          // Punch-hole notches over the perforation line.
          Positioned(
            right: _stubWidth - 9,
            top: -9,
            child: _hole(),
          ),
          Positioned(
            right: _stubWidth - 9,
            bottom: -9,
            child: _hole(),
          ),
          // Dashed perforation line.
          Positioned(
            right: _stubWidth - 0.5,
            top: 12,
            bottom: 12,
            child: CustomPaint(
              size: const Size(1, double.infinity),
              painter: _DashedLinePainter(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          // Selection ring.
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hole() {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: _holeColor,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildLeftBody(BuildContext context) {
    return Container(
      color: _bodyColor,
      padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                context.tr('coupon.label'),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppColors.primary,
                ),
              ),
              if (coupon.isEarlyBird) ...[
                const SizedBox(width: 6),
                _miniBadge(context.tr('coupon.early_bird')),
              ],
              if (coupon.isFreeItem && coupon.isBogoAllItems) ...[
                const SizedBox(width: 6),
                _miniBadge(context.tr('coupon.bogo_all')),
              ] else if (coupon.isFreeItem && coupon.freeItems.isNotEmpty) ...[
                const SizedBox(width: 6),
                _miniBadge(context.tr('coupon.gift_menu')),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            coupon.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitleText(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: const Color(0xFF94A3B8),
              height: 1.25,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(PhosphorIconsRegular.tag,
                  size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  _footerHint(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitleText(BuildContext context) {
    if (coupon.isFreeItem) return couponBogoGiftSummary(context, coupon);
    final desc = coupon.description?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    return context.tr('coupon.discount_generic');
  }

  String _footerHint(BuildContext context) {
    if (coupon.discountPreview > 0) {
      return context.trArgs('coupon.you_save', {
        'amount': coupon.discountPreview.toFormattedPrice(),
      });
    }
    // Free-item / BOGO: no invented ฿-off; show the gift summary instead of
    // "add items" (that hint is only for coupons that do not yet qualify).
    if (coupon.isFreeItem) {
      final gift = couponBogoGiftSummary(context, coupon);
      return gift.isNotEmpty ? gift : context.tr('coupon.free');
    }
    return coupon.code;
  }

  Widget _miniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildStub(BuildContext context) {
    return Container(
      width: _stubWidth,
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.tr('coupon.voucher'),
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              coupon.stubHeadline,
              style: GoogleFonts.poppins(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            coupon.isFreeItem
                ? (coupon.isBogoAllItems
                    ? context.tr('coupon.bogo_stub')
                    : context.tr('coupon.item'))
                : context.tr('coupon.off'),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clips a ticket to its top or bottom half along a zig-zag (perforated) line
/// through the vertical centre, so the two halves visually "tear" apart.
class _TearClipper extends CustomClipper<Path> {
  final bool top;
  const _TearClipper({required this.top});

  @override
  Path getClip(Size size) {
    final mid = size.height / 2;
    const teeth = 26;
    final segW = size.width / teeth;
    final path = Path();

    final points = <Offset>[];
    for (var i = 0; i <= teeth; i++) {
      final x = i * segW;
      final y = mid + (i.isEven ? -3.5 : 3.5);
      points.add(Offset(x, y));
    }

    if (top) {
      path.moveTo(0, 0);
      path.lineTo(0, points.first.dy);
      for (final p in points) {
        path.lineTo(p.dx, p.dy);
      }
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(0, points.first.dy);
      for (final p in points) {
        path.lineTo(p.dx, p.dy);
      }
      path.lineTo(size.width, size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _TearClipper oldClipper) => oldClipper.top != top;
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 4.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

