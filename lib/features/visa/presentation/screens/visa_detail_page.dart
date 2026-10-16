import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/haptic_splash_factory.dart';
import '../../data/repositories/visa_repository.dart';

class VisaDetailArgs {
  final int? visaId;
  final String title;
  final String description;
  final String? subtitle;
  final String? categoryTitle;
  final String? imageUrl;
  final String? officialWebsite;
  final bool canTakeAppointmentOnline;

  VisaDetailArgs({
    this.visaId,
    required this.title,
    required this.description,
    this.subtitle,
    this.categoryTitle,
    this.imageUrl,
    this.officialWebsite,
    this.canTakeAppointmentOnline = false,
  });
}

class VisaDetailPage extends StatefulWidget {
  final VisaDetailArgs args;

  const VisaDetailPage({super.key, required this.args});

  @override
  State<VisaDetailPage> createState() => _VisaDetailPageState();
}

class _VisaDetailPageState extends State<VisaDetailPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _shimmerController;
  late VisaDetailArgs _args;

  @override
  void initState() {
    super.initState();
    _args = widget.args;
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    if (_args.visaId != null) {
      try {
        final visa = await VisaRepository.instance.fetchOne(_args.visaId!);
        if (visa != null && mounted) {
          _args = VisaDetailArgs(
            visaId: visa.id,
            title: visa.displayTitle,
            subtitle: visa.displaySubtitle,
            description: visa.displayDescription,
            categoryTitle: visa.visaCategory?.title ?? _args.categoryTitle,
            imageUrl: visa.resolvedImageUrl,
            officialWebsite: visa.linkUrl,
            canTakeAppointmentOnline: visa.linkUrl != null &&
                visa.linkUrl!.toLowerCase().contains('evisa'),
          );
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() async {
    await _loadData();
  }

  Future<void> _launchUrl(String urlString) async {
    AppHaptics.buttonTap();
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.trArgs('visa.could_not_launch', {'url': urlString}),
          isError: true,
        );
      }
    }
  }

  void _copyOfficialLink(String urlString) {
    AppHaptics.buttonTap();
    Clipboard.setData(ClipboardData(text: urlString));
    AppDialog.showToast(context, 'Official website link copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildSliverHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                  child: _isLoading ? _buildSkeleton() : _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverHeader() {
    final hasImage = _args.imageUrl != null && _args.imageUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 270,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: _buildFrostedCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () {
              AppHaptics.buttonTap();
              Navigator.pop(context);
            },
          ),
        ),
      ),
      actions: [
        if (_args.officialWebsite != null &&
            _args.officialWebsite!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: _buildFrostedCircleButton(
                icon: PhosphorIconsRegular.copy,
                onTap: () => _copyOfficialLink(_args.officialWebsite!),
              ),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              CachedNetworkImage(
                imageUrl: _args.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFF1E293B),
                ),
                errorWidget: (context, url, error) => _buildFallbackHeroBackground(),
              )
            else
              _buildFallbackHeroBackground(),

            // Top and Bottom Ambient Gradient Overlays for contrast & elegance
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // Bottom Hero Banner Pill
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🇹🇭', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          _args.categoryTitle?.isNotEmpty == true
                              ? _args.categoryTitle!
                              : 'Thailand Official Visa',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrostedCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Center(
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackHeroBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFE91E63),
            Color(0xFFFF5722),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          PhosphorIconsFill.identificationCard,
          color: Colors.white.withValues(alpha: 0.25),
          size: 96,
        ),
      ),
    );
  }

  Widget _buildContent() {
    final isOnline = _args.canTakeAppointmentOnline ||
        (_args.officialWebsite != null &&
            _args.officialWebsite!.toLowerCase().contains('evisa'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Category Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFEDF2F7),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge tag row
              Row(
                children: [
                  if (isOnline)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            PhosphorIconsFill.lightning,
                            color: Color(0xFF059669),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'E-Visa Online Portal',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF059669),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            PhosphorIconsFill.buildings,
                            color: Color(0xFF2563EB),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Official Bureau Service',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF2563EB),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '2026 Active',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                _args.title,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  height: 1.3,
                  letterSpacing: -0.4,
                ),
              ),

              // Subtitle
              if (_args.subtitle != null && _args.subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _args.subtitle!,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quick Highlights Row (3 Info Tiles)
        Row(
          children: [
            Expanded(
              child: _buildHighlightTile(
                icon: isOnline
                    ? PhosphorIconsFill.laptop
                    : PhosphorIconsFill.identificationCard,
                title: 'Application',
                value: isOnline ? 'Online / E-Visa' : 'In-Person',
                color: isOnline ? const Color(0xFF059669) : const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHighlightTile(
                icon: PhosphorIconsFill.shieldCheck,
                title: 'Authority',
                value: 'Immigration',
                color: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHighlightTile(
                icon: PhosphorIconsFill.globeHemisphereEast,
                title: 'Country',
                value: 'Thailand',
                color: const Color(0xFFEA580C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Description / Overview Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFEDF2F7),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      PhosphorIconsFill.article,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Overview & Guidelines',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _args.description,
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  color: const Color(0xFF334155),
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Online Appointment Info Card
        if (_args.canTakeAppointmentOnline) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    PhosphorIconsFill.calendarCheck,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('visa.online_appointment'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.tr('visa.online_appointment_sub'),
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Official Portal Action Button (Primary CTA)
        if (_args.officialWebsite != null &&
            _args.officialWebsite!.trim().isNotEmpty) ...[
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: () => _launchUrl(_args.officialWebsite!),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        PhosphorIconsFill.globe,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          context.tr('visa.official_website'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        PhosphorIconsBold.arrowUpRight,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => _copyOfficialLink(_args.officialWebsite!),
              icon: const Icon(
                PhosphorIconsRegular.copy,
                size: 15,
                color: Color(0xFF64748B),
              ),
              label: Text(
                'Copy Portal Address',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],

        // Official Advisory Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFDE68A),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  PhosphorIconsFill.warningCircle,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Official Government Advisory',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Visa regulations, requirements, and fees are subject to Thai Immigration Bureau policies. Always verify with official authorities before travel.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFFB45309),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEDF2F7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _skeletonBox(width: 250, height: 28),
        const SizedBox(height: 16),
        _skeletonBox(width: double.infinity, height: 16),
        const SizedBox(height: 8),
        _skeletonBox(width: double.infinity, height: 16),
        const SizedBox(height: 8),
        _skeletonBox(width: double.infinity, height: 16),
        const SizedBox(height: 8),
        _skeletonBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: 16,
        ),
        const SizedBox(height: 32),
        _skeletonBox(width: double.infinity, height: 80, borderRadius: 16),
      ],
    );
  }

  Widget _skeletonBox({
    required double width,
    required double height,
    double borderRadius = 8,
  }) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: const FractionalOffset(-1.0, -0.5),
              end: const FractionalOffset(2.0, 0.5),
              transform: _SlidingGradientTransform(
                slidePercent: _shimmerController.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
