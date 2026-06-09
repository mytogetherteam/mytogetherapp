import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/presentation/widgets/empty_state_view.dart';
import '../../data/models/visa_dto.dart';
import '../../data/repositories/visa_repository.dart';
import 'visa_detail_page.dart';

final _pink = AppColors.primary;
const _orange = Color(0xFFFBA15C);
const _bgColor = Color(0xFFF5F5F5);

const _categoryColors = [
  Color(0xFF6C63FF),
  Color(0xFF10B981),
  Color(0xFFEF7C00),
  Color(0xFF3B82F6),
  Color(0xFFEC4899),
];

class VisaPage extends StatefulWidget {
  const VisaPage({super.key});

  @override
  State<VisaPage> createState() => _VisaPageState();
}

class _VisaPageState extends State<VisaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VisaSectionData? _visaTypes;
  VisaSectionData? _services;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        VisaRepository.instance.loadSection('VISA_TYPES'),
        VisaRepository.instance.loadSection('IMMIGRATION_SERVICES'),
      ]);
      if (mounted) {
        setState(() {
          _visaTypes = results[0];
          _services = results[1];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.tr('visa.load_failed');
          _isLoading = false;
        });
      }
    }
  }

  void _openDetail(VisaDto visa) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VisaDetailPage(
          args: VisaDetailArgs(
            visaId: visa.id,
            title: visa.displayTitle,
            description: visa.displayDescription,
            imageUrl: visa.resolvedImageUrl,
            officialWebsite: visa.linkUrl,
            canTakeAppointmentOnline: visa.linkUrl != null &&
                visa.linkUrl!.toLowerCase().contains('evisa'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _bgColor,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildSliverHeader(innerBoxIsScrolled),
          ],
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _loadData,
                            child: Text(context.tr('common.retry')),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _VisaSectionList(
                          section: _visaTypes!,
                          onTap: _openDetail,
                        ),
                        _VisaSectionList(
                          section: _services!,
                          onTap: _openDetail,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildSliverHeader(bool innerBoxIsScrolled) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      backgroundColor: _pink,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_pink, _orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('🇹🇭', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('visa.title'),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            context.tr('visa.subtitle'),
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            labelColor: _pink,
            unselectedLabelColor: Colors.black54,
            indicatorColor: _pink,
            indicatorWeight: 2.5,
            tabs: [
              Tab(text: context.tr('visa.visa_types')),
              Tab(text: context.tr('visa.immigration_services')),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisaSectionList extends StatelessWidget {
  final VisaSectionData section;
  final void Function(VisaDto visa) onTap;

  const _VisaSectionList({
    required this.section,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Only render categories that actually have visas. If none do (either no
    // categories at all, or categories with no visas mapped to them), show the
    // empty state instead of a blank screen.
    final visibleCategories = section.categories
        .where((c) => (section.visasByCategory[c.id] ?? const []).isNotEmpty)
        .toList();

    if (visibleCategories.isEmpty) {
      return EmptyStateView(
        icon: PhosphorIconsRegular.identificationCard,
        subtitle: context.tr('visa.no_items'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: visibleCategories.length,
      itemBuilder: (context, index) {
        final category = visibleCategories[index];
        final visas = section.visasByCategory[category.id] ?? const [];
        if (visas.isEmpty) return const SizedBox.shrink();

        final color = _categoryColors[index % _categoryColors.length];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Text(
                category.title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            ...visas.map(
              (visa) => _VisaListTile(
                visa: visa,
                accentColor: color,
                onTap: () => onTap(visa),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _VisaListTile extends StatelessWidget {
  final VisaDto visa;
  final Color accentColor;
  final VoidCallback onTap;

  const _VisaListTile({
    required this.visa,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildLeading(),
        title: Text(
          visa.displayTitle,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: visa.displaySubtitle.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  visa.displaySubtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.black45,
                    height: 1.4,
                  ),
                ),
              )
            : null,
        trailing: Icon(
          PhosphorIconsRegular.caretRight,
          size: 14,
          color: Colors.grey.shade400,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLeading() {
    final iconUrl = resolveMediaUrl(visa.iconUrl);
    if (iconUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: iconUrl,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _defaultLeading(),
        ),
      );
    }
    return _defaultLeading();
  }

  Widget _defaultLeading() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        PhosphorIconsRegular.identificationCard,
        color: accentColor,
        size: 20,
      ),
    );
  }
}
