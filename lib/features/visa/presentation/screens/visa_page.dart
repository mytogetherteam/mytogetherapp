import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_icon.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/haptic_splash_factory.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/presentation/widgets/empty_state_view.dart';
import '../../data/models/visa_dto.dart';
import '../../data/repositories/visa_repository.dart';
import 'visa_detail_page.dart';

class VisaPage extends StatefulWidget {
  const VisaPage({super.key});

  @override
  State<VisaPage> createState() => _VisaPageState();
}

class _VisaPageState extends State<VisaPage> {
  static const int _pageSize = 6;

  VisaSectionData? _visaTypes;
  VisaSectionData? _services;
  bool _isLoadingVisas = false;
  bool _isLoadingServices = false;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  int _selectedTab = 0; // 0: Visa Types, 1: Immigration Services
  String _selectedVisaFilter = 'ALL';
  String _selectedServiceFilter = 'ALL';
  int _visibleCount = _pageSize;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _visaTypes = VisaRepository.instance.getCachedSection('VISA_TYPES');
    _services =
        VisaRepository.instance.getCachedSection('IMMIGRATION_SERVICES');
    _scrollController.addListener(_onScroll);
    _loadActiveTab();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final scrolled = pos.pixels > 165;
    bool needsRebuild = false;
    if (scrolled != _isScrolled) {
      _isScrolled = scrolled;
      needsRebuild = true;
    }
    if (pos.pixels >= pos.maxScrollExtent - 260) {
      final total = _currentFilteredLength();
      if (_visibleCount < total) {
        _visibleCount = (_visibleCount + _pageSize).clamp(0, total);
        needsRebuild = true;
      }
    }
    if (needsRebuild) {
      setState(() {});
    }
  }

  int _currentFilteredLength() {
    final section = _selectedTab == 0 ? _visaTypes : _services;
    final selectedFilter =
        _selectedTab == 0 ? _selectedVisaFilter : _selectedServiceFilter;
    if (section == null) return 0;
    int count = 0;
    for (final cat in section.categories) {
      if (selectedFilter != 'ALL' && selectedFilter != cat.id.toString()) {
        continue;
      }
      count += (section.visasByCategory[cat.id] ?? const <VisaDto>[]).length;
    }
    return count;
  }

  String _l(String en, String mm, String th) =>
      LocaleController.instance.localized(en: en, mm: mm, th: th);

  Future<void> _loadActiveTab({bool forceRefresh = false}) async {
    if (_selectedTab == 0) {
      await _loadVisasSection(forceRefresh: forceRefresh);
    } else {
      await _loadServicesSection(forceRefresh: forceRefresh);
    }
  }

  Future<void> _loadVisasSection({bool forceRefresh = false}) async {
    if (!forceRefresh && _visaTypes != null) return;
    setState(() {
      _isLoadingVisas = _visaTypes == null;
      _error = null;
    });
    try {
      final data = await VisaRepository.instance.loadSection(
        'VISA_TYPES',
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _visaTypes = data;
          _isLoadingVisas = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_visaTypes == null) _error = context.tr('visa.load_failed');
          _isLoadingVisas = false;
        });
      }
    }
  }

  Future<void> _loadServicesSection({bool forceRefresh = false}) async {
    if (!forceRefresh && _services != null) return;
    setState(() {
      _isLoadingServices = _services == null;
      _error = null;
    });
    try {
      final data = await VisaRepository.instance.loadSection(
        'IMMIGRATION_SERVICES',
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _services = data;
          _isLoadingServices = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_services == null) _error = context.tr('visa.load_failed');
          _isLoadingServices = false;
        });
      }
    }
  }

  Future<void> _ensureBothLoadedForSearch() async {
    if (_visaTypes == null) _loadVisasSection();
    if (_services == null) _loadServicesSection();
  }

  Future<void> _openUrl(String url) async {
    AppHaptics.buttonTap();
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
        );
        if (!launched) {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        }
      } catch (_) {
        try {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        } catch (_) {}
      }
    }
  }

  void _openDetail(VisaDto visa, {String? categoryTitle}) {
    AppHaptics.buttonTap();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VisaDetailPage(
          args: VisaDetailArgs(
            visaId: visa.id,
            title: visa.displayTitle,
            subtitle: visa.displaySubtitle,
            description: visa.displayDescription,
            categoryTitle: categoryTitle ?? visa.visaCategory?.title,
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
      value: (_isScrolled
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        bottomNavigationBar: _query.isNotEmpty ? null : _buildBottomTabBar(),
        body: Stack(
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: (notification) {
                final scrolled = notification.metrics.pixels > 165;
                if (scrolled != _isScrolled) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && scrolled != _isScrolled) {
                      setState(() => _isScrolled = scrolled);
                    }
                  });
                }
                return false;
              },
              child: RefreshIndicator(
                color: AppColors.primary,
                edgeOffset: MediaQuery.of(context).padding.top + 40,
                onRefresh: () => _loadActiveTab(forceRefresh: true),
                child: ListView(
                  controller: _scrollController,
                  cacheExtent: 250,
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildHeader(),
                    if (_query.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 32),
                        child: _buildSearchResults(),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 36),
                        child: _selectedTab == 0
                            ? _buildVisasTabContent()
                            : _buildImmigrationServicesTabContent(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildFloatingTopBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingTopBar() {
    final top = MediaQuery.of(context).padding.top;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.only(top: top, left: 12, right: 16),
      height: top + 56,
      decoration: BoxDecoration(
        color: _isScrolled ? Colors.white : Colors.transparent,
        border: _isScrolled
            ? Border(
                bottom: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              AppHaptics.buttonTap();
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isScrolled
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIconsRegular.arrowLeft,
                color: _isScrolled ? Colors.black : Colors.white,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isScrolled ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _l(
                    'Thai Visa Info',
                    'သိထားသင့်သော ထိုင်းဗီဇာ',
                    'ข้อมูลวีซ่าไทยที่ควรรู้',
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          if (!_isScrolled)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsFill.shieldCheck,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _l(
                      'Official Guide 2026',
                      'တရားဝင် လမ်းညွှန် ၂၀၂၆',
                      'คู่มือทางการ 2026',
                    ),
                    style: AppFonts.poppins(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 1. Header Hero with Background Image & Bottom White Fade
  // ---------------------------------------------------------------------

  Widget _buildHeader() {
    final top = MediaQuery.of(context).padding.top;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final headerHeight = (isIOS ? 255.0 : 240.0) + top;

    return SizedBox(
      width: double.infinity,
      height: headerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Illustration Image (1024x576)
          Image.asset(
            'assets/images/visa_header_bg.webp',
            width: double.infinity,
            height: headerHeight,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          // Subtle top/left scrim for white text & button readability
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.32),
                  Colors.black.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Smooth bottom fade-to-white gradient style
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 115,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.58, 1.0],
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    const Color(0xFFF8F9FB).withValues(alpha: 0.78),
                    const Color(0xFFF8F9FB),
                  ],
                ),
              ),
            ),
          ),
          // Header Foreground Content
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 56, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  _l(
                    'Thai Visa Info You Must Know',
                    'သိထားသင့်သော ထိုင်းဗီဇာ',
                    'ข้อมูลวีซ่าไทยที่ควรรู้',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    color: Colors.white,
                    fontSize: 19.5,
                    fontWeight: FontWeight.w800,
                  ).copyWith(
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _l(
                    'Essential visa & stay rules',
                    'ဗီဇာနှင့် လူဝင်မှု အချက်အလက်များ',
                    'คู่มือวีซ่าและการพำนักสำคัญ',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ).copyWith(
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1.5),
                        blurRadius: 6,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildSearch(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF64748B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                final next = v.trim();
                if (next.isNotEmpty) _ensureBothLoadedForSearch();
                setState(() => _query = next);
              },
              cursorColor: AppColors.primary,
              style: AppFonts.poppins(
                color: const Color(0xFF1E293B),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: _l(
                  'Search visa knowledges ...',
                  'ဗီဇာအမျိုးအစားများအကြောင်း ရှာရန်...',
                  'ค้นหาวีซ่า Non-B, ท่องเที่ยว, DTV และแบบฟอร์ม ตม....',
                ),
                hintStyle: AppFonts.poppins(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFF64748B),
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 2. Bottom Tab Bar: "Visa Types" vs "Immigration Services"
  // ---------------------------------------------------------------------

  Widget _buildBottomTabBar() {
    final inactiveColor = Colors.grey.shade400;
    final bottomInset = Theme.of(context).platform == TargetPlatform.iOS
        ? MediaQuery.of(context).padding.bottom * 0.5
        : MediaQuery.of(context).padding.bottom;
    const barBodyHeight = 60.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: barBodyHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _tabButton(
                    index: 0,
                    icon: PhosphorIconsRegular.identificationCard,
                    activeIcon: PhosphorIconsFill.identificationCard,
                    title:
                        _l('Visa Types', 'ဗီဇာအမျိုးအစားများ', 'ประเภทวีซ่า'),
                    inactiveColor: inactiveColor,
                    height: barBodyHeight,
                  ),
                  _tabButton(
                    index: 1,
                    icon: PhosphorIconsRegular.stamp,
                    activeIcon: PhosphorIconsFill.stamp,
                    title:
                        _l('TM Services', 'လူဝင်မှု ဝန်ဆောင်မှု', 'บริการ ตม.'),
                    inactiveColor: inactiveColor,
                    height: barBodyHeight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required Color inactiveColor,
    required double height,
  }) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.buttonTap();
          if (_selectedTab == index) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              );
            }
            return;
          }
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
          setState(() {
            _selectedTab = index;
            _visibleCount = _pageSize;
            _isScrolled = false;
          });
          _loadActiveTab();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: AppColors.primaryGradient.colors,
                      ).createShader(bounds),
                      child: Icon(
                        activeIcon,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: AppColors.primaryGradient.colors,
                      ).createShader(bounds),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          style: AppFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: inactiveColor, size: 26),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: AppFonts.poppins(
                          color: inactiveColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 3. Tab 1: Visa Types Content (1 Row in 2 Rectangles)
  // ---------------------------------------------------------------------

  Widget _buildVisasTabContent() {
    if (_isLoadingVisas && _visaTypes == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    if (_error != null && _visaTypes == null) return _buildErrorView();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: _l(
            'Official Visa Types',
            'တရားဝင် ထိုင်းဗီဇာ အမျိုးအစားများ',
            'ประเภทวีซ่าทางการของไทย',
          ),
          icon: PhosphorIconsFill.identificationCard,
        ),
        _buildCategoryFilterChips(
          section: _visaTypes,
          selectedFilter: _selectedVisaFilter,
          allLabel: _l('All Visas', 'ဗီဇာအားလုံး', 'วีซ่าทั้งหมด'),
          onSelect: (id) => setState(() {
            _selectedVisaFilter = id;
            _visibleCount = _pageSize;
          }),
        ),
        _buildSectionGrid2Cols(
          section: _visaTypes,
          selectedFilter: _selectedVisaFilter,
          childAspectRatio: 1.08,
          maxTitleLines: 2,
        ),
        const SizedBox(height: 20),
        _buildDisclaimer(),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 4. Tab 2: Immigration Services Content (1 Row in 2 Rectangles)
  // ---------------------------------------------------------------------

  Widget _buildImmigrationServicesTabContent() {
    if (_isLoadingServices && _services == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    if (_error != null && _services == null) return _buildErrorView();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: _l(
            'Knowledge Immigration Services',
            'လူဝင်မှုကြီးကြပ်ရေး အကြောင်း',
            'บริการตรวจคนเข้าเมือง (ตม.)',
          ),
          icon: PhosphorIconsFill.stamp,
        ),
        _buildCategoryFilterChips(
          section: _services,
          selectedFilter: _selectedServiceFilter,
          allLabel: _l('All Services', 'အားလုံး', 'บริการทั้งหมด'),
          onSelect: (id) => setState(() {
            _selectedServiceFilter = id;
            _visibleCount = _pageSize;
          }),
        ),
        _buildSectionGrid2Cols(
          section: _services,
          selectedFilter: _selectedServiceFilter,
        ),
        const SizedBox(height: 20),
        _buildDisclaimer(),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 5. Filter Chips & 2-Column Cards Grid
  // ---------------------------------------------------------------------

  Widget _buildCategoryFilterChips({
    required VisaSectionData? section,
    required String selectedFilter,
    required String allLabel,
    required ValueChanged<String> onSelect,
  }) {
    if (section == null || section.categories.length <= 1) {
      return const SizedBox.shrink();
    }

    final categories = section.categories;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _filterChip(
            label: allLabel,
            isSelected: selectedFilter == 'ALL',
            onTap: () => onSelect('ALL'),
          ),
          for (final cat in categories)
            _filterChip(
              label: cat.title,
              isSelected: selectedFilter == cat.id.toString(),
              onTap: () => onSelect(cat.id.toString()),
            ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          AppHaptics.buttonTap();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppFonts.poppins(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionGrid2Cols({
    required VisaSectionData? section,
    required String selectedFilter,
    double childAspectRatio = 0.86,
    int maxTitleLines = 4,
  }) {
    if (section == null) return const SizedBox.shrink();

    final filtered = <(VisaDto, String)>[];
    for (final cat in section.categories) {
      if (selectedFilter != 'ALL' && selectedFilter != cat.id.toString()) {
        continue;
      }
      for (final visa in section.visasByCategory[cat.id] ?? const <VisaDto>[]) {
        filtered.add((visa, cat.title));
      }
    }

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            context.tr('visa.no_items'),
            style: AppFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    final visibleItems = filtered.take(_visibleCount).toList();
    final hasMore = visibleItems.length < filtered.length;

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, i) {
            final item = visibleItems[i];
            return _buildVisaCard2Col(
              visa: item.$1,
              categoryTitle: item.$2,
              index: i,
              maxTitleLines: maxTitleLines,
              onTap: () => _openDetail(item.$1, categoryTitle: item.$2),
            );
          },
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _visibleCount =
                      (_visibleCount + _pageSize).clamp(0, filtered.length);
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _l(
                        'Scroll or tap for more (${filtered.length - visibleItems.length})',
                        'နောက်ထပ်ကြည့်ရန် (${filtered.length - visibleItems.length})',
                        'ดูเพิ่มเติม (${filtered.length - visibleItems.length})',
                      ),
                      style: AppFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVisaCard2Col({
    required VisaDto visa,
    required String categoryTitle,
    required VoidCallback onTap,
    int index = 0,
    int maxTitleLines = 4,
  }) {
    final bannerUrl = resolveMediaUrl(visa.bannerUrl);
    final iconUrl = resolveMediaUrl(visa.iconUrl);
    final imageUrl = bannerUrl.isNotEmpty ? bannerUrl : iconUrl;
    final hasCustomIcon = iconUrl.isNotEmpty && iconUrl != imageUrl;
    final theme = _resolveCardTheme(visa, categoryTitle, index: index);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: theme.accent.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Banner / Thumbnail Header
              SizedBox(
                height: 98,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        cacheKey: imageUrl,
                        imageUrl: imageUrl,
                        maxWidthDiskCache: 600,
                        maxHeightDiskCache: 400,
                        memCacheWidth: 420,
                        fadeInDuration: const Duration(milliseconds: 180),
                        fit: BoxFit.cover,
                        placeholder: (_, _) => _buildGradientHeaderBanner(
                          theme: theme,
                        ),
                        errorWidget: (_, _, _) => _buildGradientHeaderBanner(
                          theme: theme,
                        ),
                      )
                    else
                      _buildGradientHeaderBanner(theme: theme),
                    // Show bottom-left icon badge when gradient banner is used or when a separate iconUrl exists
                    if (imageUrl.isEmpty || hasCustomIcon)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: hasCustomIcon
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: CachedNetworkImage(
                                    cacheKey: iconUrl,
                                    imageUrl: iconUrl,
                                    maxWidthDiskCache: 120,
                                    maxHeightDiskCache: 120,
                                    memCacheWidth: 96,
                                    fadeInDuration:
                                        const Duration(milliseconds: 150),
                                    width: 30,
                                    height: 30,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => Icon(
                                      theme.icon,
                                      size: 20,
                                      color: theme.accent,
                                    ),
                                    errorWidget: (_, _, _) => Icon(
                                      theme.icon,
                                      size: 20,
                                      color: theme.accent,
                                    ),
                                  ),
                                )
                              : Icon(
                                  theme.icon,
                                  size: 20,
                                  color: theme.accent,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              // Bottom Content Section (Title Only)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    maxTitleLines <= 2 ? 6 : 10,
                    12,
                    maxTitleLines <= 2 ? 6 : 10,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      visa.displayTitle,
                      maxLines: maxTitleLines,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.poppins(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                        height: 1.34,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientHeaderBanner({
    required ({
      Color accent,
      Color bgStart,
      Color bgEnd,
      IconData icon,
    }) theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.bgStart, theme.bgEnd],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            bottom: -16,
            child: Icon(
              theme.icon,
              size: 74,
              color: theme.accent.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            left: -18,
            top: -18,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ({
    Color accent,
    Color bgStart,
    Color bgEnd,
    IconData icon,
  }) _resolveCardTheme(VisaDto visa, String categoryTitle, {int index = 0}) {
    final text =
        '${visa.titleEn} ${visa.displayTitle} $categoryTitle'.toLowerCase();
    if (text.contains('overstay') || text.contains('ဒဏ်ကြေး')) {
      return (
        accent: const Color(0xFFD97706),
        bgStart: const Color(0xFFFEF3C7),
        bgEnd: const Color(0xFFFFFBEB),
        icon: PhosphorIconsFill.warningCircle,
      );
    }
    if (text.contains('72') ||
        text.contains('tdac') ||
        text.contains('arrival') ||
        text.contains('90')) {
      return (
        accent: const Color(0xFF2563EB),
        bgStart: const Color(0xFFDBEAFE),
        bgEnd: const Color(0xFFEFF6FF),
        icon: PhosphorIconsFill.fileText,
      );
    }
    if (text.contains('work') ||
        text.contains('business') ||
        text.contains('non-b') ||
        text.contains('ltr')) {
      return (
        accent: const Color(0xFF059669),
        bgStart: const Color(0xFFD1FAE5),
        bgEnd: const Color(0xFFECFDF5),
        icon: PhosphorIconsFill.briefcase,
      );
    }
    if (text.contains('edu') ||
        text.contains('student') ||
        text.contains('non-ed')) {
      return (
        accent: const Color(0xFF7C3AED),
        bgStart: const Color(0xFFEDE9FE),
        bgEnd: const Color(0xFFF5F3FF),
        icon: PhosphorIconsFill.graduationCap,
      );
    }
    if (text.contains('tourist') ||
        text.contains('travel') ||
        text.contains('dtv') ||
        text.contains('tr visa')) {
      return (
        accent: AppColors.primary,
        bgStart: const Color(0xFFFFE4EC),
        bgEnd: const Color(0xFFFFF1F5),
        icon: PhosphorIconsFill.airplaneTilt,
      );
    }

    final palettes = [
      (
        accent: AppColors.primary,
        bgStart: const Color(0xFFFFE4EC),
        bgEnd: const Color(0xFFFFF1F5),
        icon: PhosphorIconsFill.identificationCard,
      ),
      (
        accent: const Color(0xFF2563EB),
        bgStart: const Color(0xFFDBEAFE),
        bgEnd: const Color(0xFFEFF6FF),
        icon: PhosphorIconsFill.globeHemisphereEast,
      ),
      (
        accent: const Color(0xFF0D9488),
        bgStart: const Color(0xFFCCFBF1),
        bgEnd: const Color(0xFFF0FDFA),
        icon: PhosphorIconsFill.shieldCheck,
      ),
      (
        accent: const Color(0xFF7C3AED),
        bgStart: const Color(0xFFEDE9FE),
        bgEnd: const Color(0xFFF5F3FF),
        icon: PhosphorIconsFill.bookBookmark,
      ),
      (
        accent: const Color(0xFFD97706),
        bgStart: const Color(0xFFFEF3C7),
        bgEnd: const Color(0xFFFFFBEB),
        icon: PhosphorIconsFill.stamp,
      ),
    ];
    return palettes[(index + visa.id.abs()) % palettes.length];
  }

  // ---------------------------------------------------------------------
  // 6. Search Results View
  // ---------------------------------------------------------------------

  Widget _buildSearchResults() {
    final q = _query.toLowerCase();
    final matches = <(VisaDto, String)>[];
    for (final section in [_visaTypes, _services]) {
      if (section == null) continue;
      for (final category in section.categories) {
        for (final visa
            in section.visasByCategory[category.id] ?? const <VisaDto>[]) {
          if (visa.displayTitle.toLowerCase().contains(q) ||
              visa.displaySubtitle.toLowerCase().contains(q)) {
            matches.add((visa, category.title));
          }
        }
      }
    }

    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: EmptyStateView(
          icon: PhosphorIconsRegular.identificationCard,
          subtitle: context.tr('visa.no_items'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            '${matches.length} ${_l('results found', 'ခု တွေ့ရှိပါသည်', 'รายการที่พบ')}',
            style: AppFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: matches.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, i) {
            final m = matches[i];
            return _buildVisaCard2Col(
              visa: m.$1,
              categoryTitle: m.$2,
              index: i,
              onTap: () => _openDetail(m.$1, categoryTitle: m.$2),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 7. Section Header & Helpers
  // ---------------------------------------------------------------------

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradientVertical,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            icon,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: AppFonts.poppins(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsFill.info,
                size: 16,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                _l(
                  'Official Immigration Notice',
                  'တရားဝင် သတိပြုရန် အချက်များ',
                  'ข้อสงวนสิทธิ์ทางการ',
                ),
                style: AppFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _l(
              'Visa requirements and fees are subject to official regulations of the Royal Thai Embassy and Thai Immigration Bureau.',
              'ဗီဇာလိုအပ်ချက်များနှင့် ဝန်ဆောင်ခများသည် ထိုင်းသံရုံးနှင့် ထိုင်းလူဝင်မှုကြီးကြပ်ရေးဌာန၏ တရားဝင်သတ်မှတ်ချက်များအတိုင်း ဖြစ်ပါသည်။',
              'ข้อกำหนดและค่าธรรมเนียมวีซ่าเป็นไปตามระเบียบทางการของสถานทูตไทยและสำนักงานตรวจคนเข้าเมือง',
            ),
            style: AppFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _linkChip('thaievisa.go.th', 'https://www.thaievisa.go.th'),
              _linkChip('immigration.go.th', 'https://www.immigration.go.th'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _linkChip(String label, String url) {
    return ActionChip(
      onPressed: () => _openUrl(url),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      avatar: const GradientIcon(
        icon: PhosphorIcons.arrowSquareOut,
        size: 12,
      ),
      label: Text(
        label,
        style: AppFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsRegular.warningCircle,
                color: Colors.red,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _loadActiveTab(forceRefresh: true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 18),
              label: Text(
                context.tr('common.retry'),
                style: AppFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
