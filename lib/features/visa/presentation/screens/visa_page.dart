import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _VisaItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _VisaItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

class _ServiceItem {
  final String title;
  final String description;
  final IconData icon;

  const _ServiceItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _VisaCategory {
  final String label;
  final String emoji;
  final Color color;
  final List<_VisaItem> items;

  const _VisaCategory({
    required this.label,
    required this.emoji,
    required this.color,
    required this.items,
  });
}

class _ServiceCategory {
  final String label;
  final String emoji;
  final Color color;
  final List<_ServiceItem> items;

  const _ServiceCategory({
    required this.label,
    required this.emoji,
    required this.color,
    required this.items,
  });
}

// ---------------------------------------------------------------------------
// Static data
// ---------------------------------------------------------------------------

const _pink = Color(0xFFED3973);
const _orange = Color(0xFFFBA15C);
const _bgColor = Color(0xFFF5F5F5);

final List<_VisaCategory> _visaCategories = [
  _VisaCategory(
    label: 'Short-Term & Tourist',
    emoji: '✈️',
    color: const Color(0xFF6C63FF),
    items: [
      _VisaItem(
        title: '60-Day Visa Exemption',
        subtitle: '93 nationalities • No visa required on arrival',
        icon: PhosphorIconsRegular.airplaneTakeoff,
        accentColor: const Color(0xFF6C63FF),
      ),
      _VisaItem(
        title: 'Tourist Visa (TR)',
        subtitle: '60 days • Applied at embassy / online',
        icon: PhosphorIconsRegular.identificationCard,
        accentColor: const Color(0xFF6C63FF),
      ),
      _VisaItem(
        title: 'Multiple Entry Tourist Visa (METV)',
        subtitle: '6 months • Unlimited 60-day entries',
        icon: PhosphorIconsRegular.arrowsClockwise,
        accentColor: const Color(0xFF6C63FF),
      ),
      _VisaItem(
        title: 'Visa on Arrival (VoA)',
        subtitle: '15 days • Select nationalities at airport',
        icon: PhosphorIconsRegular.airplaneLanding,
        accentColor: const Color(0xFF6C63FF),
      ),
    ],
  ),
  _VisaCategory(
    label: 'Long-Term & Special',
    emoji: '🏡',
    color: const Color(0xFF10B981),
    items: [
      _VisaItem(
        title: 'DTV (Destination Thailand Visa)',
        subtitle: '5-year digital nomad visa • 180 days/entry',
        icon: PhosphorIconsRegular.laptop,
        accentColor: const Color(0xFF10B981),
      ),
      _VisaItem(
        title: 'Non-Immigrant B (Business)',
        subtitle: 'Legal employment / business • Requires Work Permit',
        icon: PhosphorIconsRegular.briefcase,
        accentColor: const Color(0xFF10B981),
      ),
      _VisaItem(
        title: 'Non-Immigrant ED (Education)',
        subtitle: 'Students at schools, universities, language centers',
        icon: PhosphorIconsRegular.graduationCap,
        accentColor: const Color(0xFF10B981),
      ),
      _VisaItem(
        title: 'Non-Immigrant O (Family/Marriage)',
        subtitle: 'Thai spouses, children, or dependents',
        icon: PhosphorIconsRegular.heart,
        accentColor: const Color(0xFF10B981),
      ),
      _VisaItem(
        title: 'Non-Immigrant O-A / O-X (Retirement)',
        subtitle: '50+ years old • O-A: 1 year • O-X: 10 years',
        icon: PhosphorIconsRegular.sunHorizon,
        accentColor: const Color(0xFF10B981),
      ),
      _VisaItem(
        title: 'LTR (Long-Term Resident)',
        subtitle: '10-year premium • Wealthy citizens, retirees, skilled professionals',
        icon: PhosphorIconsRegular.crown,
        accentColor: const Color(0xFF10B981),
      ),
      _VisaItem(
        title: 'SMART Visa',
        subtitle: 'S-Curve industry experts & entrepreneurs • No Work Permit needed',
        icon: PhosphorIconsRegular.lightning,
        accentColor: const Color(0xFF10B981),
      ),
      _VisaItem(
        title: 'Thailand Privilege (Elite Visa)',
        subtitle: 'Membership-based • 5, 10, or 20 years',
        icon: PhosphorIconsRegular.star,
        accentColor: const Color(0xFF10B981),
      ),
    ],
  ),
  _VisaCategory(
    label: 'Migrant Worker Status',
    emoji: '🪪',
    color: const Color(0xFFEF7C00),
    items: [
      _VisaItem(
        title: 'Non-Thai ID (Pink Card)',
        subtitle: 'Workers from Myanmar, Laos, Cambodia, Vietnam',
        icon: PhosphorIconsRegular.identificationCard,
        accentColor: const Color(0xFFEF7C00),
      ),
      _VisaItem(
        title: 'MOU Worker Visa',
        subtitle: 'Legal entry via government-to-government labor agreements',
        icon: PhosphorIconsRegular.handshake,
        accentColor: const Color(0xFFEF7C00),
      ),
    ],
  ),
];

final List<_ServiceCategory> _serviceCategories = [
  _ServiceCategory(
    label: 'Mandatory Reporting',
    emoji: '📋',
    color: const Color(0xFF3B82F6),
    items: [
      _ServiceItem(
        title: '90-Day Reporting (TM.47)',
        description: 'Report current address every 90 days of continuous stay',
        icon: PhosphorIconsRegular.calendarCheck,
      ),
      _ServiceItem(
        title: 'TM.30 (Residence Notification)',
        description: 'Filed by landlord within 24 hours of tenant moving in',
        icon: PhosphorIconsRegular.house,
      ),
      _ServiceItem(
        title: 'TDAC (Digital Arrival Card)',
        description: 'Mandatory digital card filed 72 hours before arrival',
        icon: PhosphorIconsRegular.deviceMobile,
      ),
    ],
  ),
  _ServiceCategory(
    label: 'Visa Maintenance & Extensions',
    emoji: '🔄',
    color: const Color(0xFF8B5CF6),
    items: [
      _ServiceItem(
        title: 'Extension of Stay (TM.7)',
        description: 'Add 30 days to current visa at Immigration',
        icon: PhosphorIconsRegular.clockCounterClockwise,
      ),
      _ServiceItem(
        title: 'Re-Entry Permit (TM.8)',
        description: 'Leave without canceling visa • Single or Multiple entry',
        icon: PhosphorIconsRegular.arrowUUpLeft,
      ),
      _ServiceItem(
        title: 'Visa Type Change (TM.86/87)',
        description: 'Convert Tourist → Non-B or other types inside Thailand',
        icon: PhosphorIconsRegular.swap,
      ),
      _ServiceItem(
        title: 'Transfer Stamp',
        description: 'Move visa stamps from old passport to new one',
        icon: PhosphorIconsRegular.stamp,
      ),
    ],
  ),
  _ServiceCategory(
    label: 'Work & Legal Documents',
    emoji: '💼',
    color: const Color(0xFF059669),
    items: [
      _ServiceItem(
        title: 'Digital Work Permit (e-WP)',
        description: 'Application and renewal of legal right to work',
        icon: PhosphorIconsRegular.briefcase,
      ),
      _ServiceItem(
        title: 'Certificate of Residence',
        description: 'Official doc for opening bank accounts or buying vehicles',
        icon: PhosphorIconsRegular.certificate,
      ),
      _ServiceItem(
        title: 'Income Certificate',
        description: 'Verification of foreign income via embassy',
        icon: PhosphorIconsRegular.money,
      ),
      _ServiceItem(
        title: 'Permanent Residency (PR)',
        description: 'Stay in Thailand indefinitely without a visa',
        icon: PhosphorIconsRegular.mapPin,
      ),
    ],
  ),
  _ServiceCategory(
    label: 'Health & Identification',
    emoji: '🏥',
    color: const Color(0xFFEC4899),
    items: [
      _ServiceItem(
        title: 'Medical Certificate for Visa',
        description: 'Mandatory health checks: Syphilis, TB, etc. for WP/Visas',
        icon: PhosphorIconsRegular.heartbeat,
      ),
      _ServiceItem(
        title: 'ThaiID App Verification',
        description: 'DOPA app to verify digital identity for government portals',
        icon: PhosphorIconsRegular.fingerprint,
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Main Page
// ---------------------------------------------------------------------------

class VisaPage extends StatefulWidget {
  const VisaPage({super.key});

  @override
  State<VisaPage> createState() => _VisaPageState();
}

class _VisaPageState extends State<VisaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          body: TabBarView(
            controller: _tabController,
            children: [
              _VisaTypesTab(categories: _visaCategories),
              _ServicesTab(categories: _serviceCategories),
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
          decoration: const BoxDecoration(
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
                          color: Colors.white.withOpacity(0.2),
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
                            'Thailand Visa',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Types & Immigration Services 2026',
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
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelStyle:
                GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w400),
            labelColor: _pink,
            unselectedLabelColor: Colors.black54,
            indicatorColor: _pink,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'Visa Types'),
              Tab(text: 'Immigration Services'),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Visa Types
// ---------------------------------------------------------------------------

class _VisaTypesTab extends StatelessWidget {
  final List<_VisaCategory> categories;

  const _VisaTypesTab({required this.categories});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: categories.length,
      itemBuilder: (context, i) => _CategorySection(category: categories[i]),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final _VisaCategory category;

  const _CategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              Text(category.emoji,
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                category.label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        ...category.items.map((item) => _VisaCard(item: item)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _VisaCard extends StatelessWidget {
  final _VisaItem item;

  const _VisaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: item.accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.icon, color: item.accentColor, size: 20),
        ),
        title: Text(
          item.title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            item.subtitle,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: Colors.black45,
              height: 1.4,
            ),
          ),
        ),
        trailing: Icon(
          PhosphorIconsRegular.caretRight,
          size: 14,
          color: Colors.grey.shade400,
        ),
        onTap: () {}, // placeholder for future detail page
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Immigration Services
// ---------------------------------------------------------------------------

class _ServicesTab extends StatelessWidget {
  final List<_ServiceCategory> categories;

  const _ServicesTab({required this.categories});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: categories.length,
      itemBuilder: (context, i) =>
          _ServiceCategorySection(category: categories[i]),
    );
  }
}

class _ServiceCategorySection extends StatelessWidget {
  final _ServiceCategory category;

  const _ServiceCategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                category.label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < category.items.length; i++) ...[
                  _ServiceItemTile(
                    item: category.items[i],
                    accentColor: category.color,
                  ),
                  if (i < category.items.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 68,
                      endIndent: 0,
                      color: Color(0xFFF0F0F0),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ServiceItemTile extends StatelessWidget {
  final _ServiceItem item;
  final Color accentColor;

  const _ServiceItemTile({
    required this.item,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(item.icon, color: accentColor, size: 20),
      ),
      title: Text(
        item.title,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          item.description,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            color: Colors.black45,
            height: 1.4,
          ),
        ),
      ),
      trailing: Icon(
        PhosphorIconsRegular.caretRight,
        size: 14,
        color: Colors.grey.shade400,
      ),
      onTap: () {},
    );
  }
}
