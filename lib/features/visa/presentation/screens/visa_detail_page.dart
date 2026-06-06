import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/repositories/visa_repository.dart';

class VisaDetailArgs {
  final int? visaId;
  final String title;
  final String description;
  final String? imageUrl;
  final String? officialWebsite;
  final bool canTakeAppointmentOnline;

  VisaDetailArgs({
    this.visaId,
    required this.title,
    required this.description,
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
            description: visa.displayDescription,
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
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trArgs('visa.could_not_launch', {'url': urlString}))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pink = AppColors.primary;
    final orange = AppColors.secondary;
    const bgColor = Color(0xFFF5F5F5);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: pink,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildSliverHeader(pink, orange),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _isLoading ? _buildSkeleton() : _buildContent(pink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverHeader(Color pink, Color orange) {
    final hasImage =
        _args.imageUrl != null && _args.imageUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      stretch: true,
      backgroundColor: pink,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        collapseMode: CollapseMode.parallax,
        background: _isLoading
            ? Container(color: Colors.grey.shade200)
            : Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    CachedNetworkImage(
                      imageUrl: _args.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey.shade200),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [pink, orange],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.image,
                          color: Colors.white54,
                          size: 50,
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [pink, orange],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  // Dark overlay gradient so back button is visible
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.1),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
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

  Widget _buildContent(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _args.title,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _args.description,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.black54,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        if (_args.canTakeAppointmentOnline) ...[
          _buildInfoCard(
            icon: PhosphorIconsRegular.calendarPlus,
            title: context.tr('visa.online_appointment'),
            subtitle: context.tr('visa.online_appointment_sub'),
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 16),
        ],
        if (_args.officialWebsite != null &&
            _args.officialWebsite!.isNotEmpty) ...[
          _buildActionCard(
            icon: PhosphorIconsRegular.globe,
            title: context.tr('visa.official_website'),
            subtitle: context.tr('visa.official_website_sub'),
            color: primaryColor,
            onTap: () => _launchUrl(_args.officialWebsite!),
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIconsRegular.caretRight, color: color, size: 20),
            ],
          ),
        ),
      ),
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
