import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'visa_detail_page.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _VisaItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String? imageUrl;
  final String? description;
  final String? officialWebsite;
  final bool canTakeAppointmentOnline;

  const _VisaItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.imageUrl,
    this.description,
    this.officialWebsite,
    this.canTakeAppointmentOnline = false,
  });
}

class _ServiceItem {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final String? imageUrl;
  final String? officialWebsite;
  final bool canTakeAppointmentOnline;

  const _ServiceItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    this.imageUrl,
    this.officialWebsite,
    this.canTakeAppointmentOnline = false,
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
        imageUrl: 'https://images.unsplash.com/photo-1563514755193-4e42a8bce736?q=80&w=800&auto=format&fit=crop',
        description: 'Passport holders from 93 countries and territories can enter Thailand without a visa for tourism and short-term business purposes. You will be granted an initial stay of up to 60 days upon arrival, which can be extended for an additional 30 days at the local Immigration Office. Always ensure your passport is valid for at least 6 months.',
        officialWebsite: 'https://www.thaiembassy.com/thailand-visa/thai-visa-exemption-and-bilateral-agreement',
      ),
      _VisaItem(
        title: 'Tourist Visa (TR)',
        subtitle: '60 days • Applied at embassy / online',
        icon: PhosphorIconsRegular.identificationCard,
        accentColor: const Color(0xFF6C63FF),
        imageUrl: 'https://images.unsplash.com/photo-1552465011-b4e21bf6e79a?q=80&w=800&auto=format&fit=crop',
        description: 'The Tourist Visa (TR) allows visitors to stay in Thailand for up to 60 days for tourism purposes. You must apply for this visa from a Thai embassy or consulate outside of Thailand before you travel. In many countries, this can now be done via the official e-Visa portal.',
        officialWebsite: 'https://thaievisa.go.th/',
        canTakeAppointmentOnline: true,
      ),
      _VisaItem(
        title: 'Multiple Entry Tourist Visa (METV)',
        subtitle: '6 months • Unlimited 60-day entries',
        icon: PhosphorIconsRegular.arrowsClockwise,
        accentColor: const Color(0xFF6C63FF),
        imageUrl: 'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?q=80&w=800&auto=format&fit=crop',
        description: 'The Multiple Entry Tourist Visa (METV) is valid for 6 months and allows unlimited border runs. Each entry grants a 60-day stay in Thailand. This visa must be applied for in your home country or country of permanent residence before traveling. It requires proof of funds (usually 200,000 THB equivalent) and employment verification.',
        officialWebsite: 'https://thaievisa.go.th/',
      ),
      _VisaItem(
        title: 'Visa on Arrival (VoA)',
        subtitle: '15 days • Select nationalities at airport',
        icon: PhosphorIconsRegular.airplaneLanding,
        accentColor: const Color(0xFF6C63FF),
        imageUrl: 'https://images.unsplash.com/photo-1530521954074-e64f6810b32d?q=80&w=800&auto=format&fit=crop',
        description: 'Passports holders from eligible countries (who do not qualify for the 60-day exemption) can apply for a Visa on Arrival at major international airports in Thailand. This visa costs 2,000 THB and grants a 15-day stay. You must provide a confirmed return ticket within 15 days and proof of accommodation.',
        officialWebsite: 'https://www.thaiembassy.com/thailand-visa/visa-on-arrival',
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
        imageUrl: 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?q=80&w=800&auto=format&fit=crop',
        description: 'The Destination Thailand Visa (DTV) is designed for digital nomads, freelancers, remote workers, and people attending cultural activities or medical treatment. It is valid for 5 years and allows you to stay up to 180 days per entry (extendable for another 180 days). Applicants must submit proof of funds of at least 500,000 THB.',
        officialWebsite: 'https://thaievisa.go.th/',
        canTakeAppointmentOnline: true,
      ),
      _VisaItem(
        title: 'Non-Immigrant B (Business)',
        subtitle: 'Legal employment / business • Requires Work Permit',
        icon: PhosphorIconsRegular.briefcase,
        accentColor: const Color(0xFF10B981),
        imageUrl: 'https://images.unsplash.com/photo-1521791136064-7986c2920216?q=80&w=800&auto=format&fit=crop',
        description: 'The Non-Immigrant B Visa is required for foreigners wishing to legally work or conduct business in Thailand. A Thai company or organization must provide sponsoring documents for the application. Once the visa is approved and you enter Thailand, you must apply for a Work Permit to legally begin your duties.',
        officialWebsite: 'https://thaievisa.go.th/',
      ),
      _VisaItem(
        title: 'Non-Immigrant ED (Education)',
        subtitle: 'Students at schools, universities, language centers',
        icon: PhosphorIconsRegular.graduationCap,
        accentColor: const Color(0xFF10B981),
        imageUrl: 'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?q=80&w=800&auto=format&fit=crop',
        description: 'The Non-Immigrant ED Visa is for foreigners studying full-time in Thailand, attending seminars, training sessions, or internships. You must have an acceptance letter from an accredited educational institution. The visa is initially valid for 90 days and extended periodically based on your curriculum.',
        officialWebsite: 'https://thaievisa.go.th/',
      ),
      _VisaItem(
        title: 'Non-Immigrant O (Family/Marriage)',
        subtitle: 'Thai spouses, children, or dependents',
        icon: PhosphorIconsRegular.heart,
        accentColor: const Color(0xFF10B981),
        imageUrl: 'https://images.unsplash.com/photo-1511895426328-dc8714191300?q=80&w=800&auto=format&fit=crop',
        description: 'The Non-Immigrant O Visa is granted to foreign dependents, spouses, and children of Thai citizens or foreign residents holding valid long-term visas. For a marriage visa, you will be required to show proof of a legitimate relationship and strict financial requirements (such as 400,000 THB in a Thai bank account or a 40,000 THB monthly income).',
      ),
      _VisaItem(
        title: 'Non-Immigrant O-A / O-X (Retirement)',
        subtitle: '50+ years old • O-A: 1 year • O-X: 10 years',
        icon: PhosphorIconsRegular.sunHorizon,
        accentColor: const Color(0xFF10B981),
        imageUrl: 'https://images.unsplash.com/photo-1473186578172-c141e6798fec?q=80&w=800&auto=format&fit=crop',
        description: 'Designed for retirees aged 50 and above. The O-A visa allows a 1-year stay, while the O-X permits up to 10 years (restricted to specific nationalities). Applicants must meet significant financial requirements (e.g., 800,000 THB for O-A or 3,000,000 THB for O-X) and carry mandatory Thai health insurance. Employment is strictly prohibited.',
      ),
      _VisaItem(
        title: 'LTR (Long-Term Resident)',
        subtitle: '10-year premium • Wealthy citizens, retirees, skilled professionals',
        icon: PhosphorIconsRegular.crown,
        accentColor: const Color(0xFF10B981),
        imageUrl: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?q=80&w=800&auto=format&fit=crop',
        description: 'The Long-Term Resident (LTR) Visa offers 10-year validity, tax exemptions, and fast-track services for high-potential foreigners. Eligible groups include wealthy global citizens, wealthy pensioners, highly-skilled professionals, and remote workers working for well-established global companies. Managed by the BOI.',
        officialWebsite: 'https://ltr.boi.go.th/',
      ),
      _VisaItem(
        title: 'SMART Visa',
        subtitle: 'S-Curve industry experts & entrepreneurs',
        icon: PhosphorIconsRegular.lightning,
        accentColor: const Color(0xFF10B981),
        imageUrl: 'https://images.unsplash.com/photo-1531297180771-8ea30b127bc9?q=80&w=800&auto=format&fit=crop',
        description: 'The SMART Visa is issued to highly-skilled expat professionals, investors, executives, and startup entrepreneurs working in targeted "S-Curve" industries like robotics, aviation, and medical hubs. It provides built-in work authorization, eliminating the need for a separate Work Permit, and allows 1-year reporting instead of 90 days.',
        officialWebsite: 'https://smart-visa.boi.go.th/',
      ),
      _VisaItem(
        title: 'Thailand Privilege (Elite Visa)',
        subtitle: 'Membership-based • 5, 10, or 20 years',
        icon: PhosphorIconsRegular.star,
        accentColor: const Color(0xFF10B981),
        imageUrl: 'https://images.unsplash.com/photo-1562967914-01efa7e87832?q=80&w=800&auto=format&fit=crop',
        description: 'The Thailand Privilege Visa (formerly Thai Elite Visa) is a specialized prolonged tourist visa tied to a premium membership package. It costs between 900,000 THB and 5,000,000 THB depending on the chosen tier. Members enjoy VIP airport fast-track, limousine transfers, exclusive lounge access, and dedicated concierge services.',
        officialWebsite: 'https://www.thailandprivilege.co.th/',
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
        imageUrl: 'https://images.unsplash.com/photo-1573164713988-8665fc963095?q=80&w=800&auto=format&fit=crop',
        description: 'The Pink Card (Non-Thai Identification Card) is primarily issued to migrant workers from neighboring countries (Myanmar, Laos, Cambodia, Vietnam) after registering with the Ministry of Interior. It acts as an official ID within Thailand, substituting the passport for many domestic transactions like banking and healthcare.',
      ),
      _VisaItem(
        title: 'MOU Worker Visa',
        subtitle: 'Legal entry via government-to-government labor agreements',
        icon: PhosphorIconsRegular.handshake,
        accentColor: const Color(0xFFEF7C00),
        imageUrl: 'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?q=80&w=800&auto=format&fit=crop',
        description: 'The MOU (Memorandum of Understanding) Worker Visa is an official employment arrangement negotiated directly between the Thai government and the governments of Myanmar, Laos, and Cambodia. It ensures the legal hiring, fair taxation, and labor protection of migrant workers coming to fill shortages in manufacturing, construction, and agriculture.',
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
        subtitle: 'Address reporting every 90 days',
        description: 'Long-term visa holders must report their residential address to the Immigration Bureau every 90 days of continuous stay in Thailand. Getting this done late incurs a 2,000 THB fine. You can complete this report in person, by mail, or through the official Thai Immigration e-Service portal online.',
        icon: PhosphorIconsRegular.calendarCheck,
        imageUrl: 'https://images.unsplash.com/photo-1543269865-cbf427effbad?q=80&w=800&auto=format&fit=crop',
        officialWebsite: 'https://tm47.immigration.go.th/tm47/#/login',
        canTakeAppointmentOnline: true,
      ),
      _ServiceItem(
        title: 'TM.30 (Residence Notification)',
        subtitle: 'Filed by landlord within 24 hours',
        description: 'Under the Immigration Act, the property owner or landlord must report the presence of any foreigner staying at their residence within 24 hours of arrival. While the landlord usually files the TM.30 online, the foreigner must keep the TM.30 receipt in their passport for subsequent visa extensions and 90-day reporting.',
        icon: PhosphorIconsRegular.house,
        imageUrl: 'https://images.unsplash.com/photo-1558036117-15d82a90b9b1?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'TDAC (Digital Arrival Card)',
        subtitle: 'Digital alternative to TM.6 card',
        description: 'The traditional TM.6 Arrival Card is being replaced by the Thailand Digital Arrival Card (TDAC) and ETA system. While currently suspended for air arrivals from most countries to ease airport congestion, the digital integration allows immigration pre-screening. Ensure you check current requirements before traveling if entering by land.',
        icon: PhosphorIconsRegular.deviceMobile,
        imageUrl: 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?q=80&w=800&auto=format&fit=crop',
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
        subtitle: 'Extend your visa at Immigration',
        description: 'An extension of stay (using form TM.7) is applied for at a Thai Immigration Office. A 60-day tourist visa or visa exemption can typically be extended for an additional 30 days for a fee of 1,900 THB. Long-term visas (business, education, retirement) require extensive annual renewal paperwork submitted via TM.7.',
        icon: PhosphorIconsRegular.clockCounterClockwise,
        imageUrl: 'https://images.unsplash.com/photo-1544256718-3bcf237f3974?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'Re-Entry Permit (TM.8)',
        subtitle: 'Required before leaving Thailand',
        description: 'If you leave Thailand, your current visa is automatically canceled unless you have a Re-Entry Permit. Form TM.8 allows you to obtain a Single-Entry (1,000 THB) or Multiple-Entry (3,800 THB) permit. This keeps your current visa valid while you travel abroad. Apply at Immigration or at major airports before departure.',
        icon: PhosphorIconsRegular.arrowUUpLeft,
        imageUrl: 'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'Visa Type Change (TM.86/87)',
        subtitle: 'Change visa type without leaving',
        description: 'Forms TM.86 and TM.87 allow foreigners to change their visa status (e.g., from a Tourist Visa or Exemption to a Non-Immigrant Visa) without leaving Thailand. This requires at least 15 days remaining on the current stamp, and significant supporting documentation from a sponsor, employer, or family member.',
        icon: PhosphorIconsRegular.swap,
        imageUrl: 'https://images.unsplash.com/photo-1450101499163-c8848c66cb85?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'Transfer Stamp',
        subtitle: 'Move visas to a new passport',
        description: 'When you receive a new passport from your embassy while staying in Thailand, your existing Thai visa and entry stamps must be transferred from the old passport to the new one. This free service is done at the Immigration Office that issued your most recent visa extension or at the airport.',
        icon: PhosphorIconsRegular.stamp,
        imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=800&auto=format&fit=crop',
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
        subtitle: 'Legal authorization to work',
        description: 'Foreigners legally employed in Thailand must hold a Work Permit. The physical blue books have been heavily replaced by the Digital Work Permit (e-WP) application on smartphones. The employer must coordinate with the Ministry of Labour to secure the Work Permit before you can legally begin working.',
        icon: PhosphorIconsRegular.briefcase,
        imageUrl: 'https://images.unsplash.com/photo-1507679799987-c73779587ccf?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'Certificate of Residence',
        subtitle: 'Official proof of Thai address',
        description: 'A Certificate of Residence is an official document from Immigration or your Embassy confirming your Thai address. It is frequently required for buying a vehicle, applying for a Thai driver\'s license, opening a bank account, or acquiring utilities. You must show proof of address like a lease contract and a TM.30 receipt.',
        icon: PhosphorIconsRegular.certificate,
        imageUrl: 'https://images.unsplash.com/photo-1603796846054-e2ef6cc2878d?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'Income Certificate',
        subtitle: 'Embassy letter verifying income',
        description: 'An Income Certificate is an official letter from a foreign embassy verifying a foreigner\'s pension or steady monthly income from abroad. This is commonly required for Retirement Visa applications (e.g., proving monthly income of at least 65,000 THB) or Marriage Visas (40,000 THB).',
        icon: PhosphorIconsRegular.money,
        imageUrl: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'Permanent Residency (PR)',
        subtitle: 'Indefinite stay for qualified residents',
        description: 'Permanent Residency allows you to stay in Thailand indefinitely without applying for annual extensions. Criteria are highly strict: you must hold a Non-Immigrant visa for at least 3 consecutive years, speak conversational Thai, and show significant tax payments. An annual quota of 100 people per nationality is enforced.',
        icon: PhosphorIconsRegular.mapPin,
        imageUrl: 'https://images.unsplash.com/photo-1473186578172-c141e6798fec?q=80&w=800&auto=format&fit=crop',
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
        subtitle: 'Health check for Work Permits',
        description: 'A standardized medical certificate is required for Work Permits and certain long-term visas. A doctor at a certified Thai clinic or hospital must examine you (including a blood test) and verify that you do not suffer from prohibitive diseases like late-stage syphilis, tuberculosis, drug addiction, alcoholism, or elephantiasis.',
        icon: PhosphorIconsRegular.heartbeat,
        imageUrl: 'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?q=80&w=800&auto=format&fit=crop',
      ),
      _ServiceItem(
        title: 'ThaiID App Verification',
        subtitle: 'Digital identity application',
        description: 'ThaID is a digital identity application developed by the Department of Provincial Administration (DOPA). While primarily for Thai citizens, expats with specific residency status and pink cards can use it to securely verify their identity when accessing government e-services, filing taxes remotely, and verifying banking transactions.',
        icon: PhosphorIconsRegular.fingerprint,
        imageUrl: 'https://images.unsplash.com/photo-1585076641399-5c06d15a43ce?q=80&w=800&auto=format&fit=crop',
      ),
    ],
  )
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
            color: Colors.black.withValues(alpha: 0.04),
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
            color: item.accentColor.withValues(alpha: 0.1),
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VisaDetailPage(
                args: VisaDetailArgs(
                  title: item.title,
                  description: item.description ?? item.subtitle,
                  imageUrl: item.imageUrl,
                  officialWebsite: item.officialWebsite,
                  canTakeAppointmentOnline: item.canTakeAppointmentOnline,
                ),
              ),
            ),
          );
        },
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
                  color: Colors.black.withValues(alpha: 0.04),
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
          color: accentColor.withValues(alpha: 0.1),
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VisaDetailPage(
              args: VisaDetailArgs(
                title: item.title,
                description: item.description,
                imageUrl: item.imageUrl,
                officialWebsite: item.officialWebsite,
                canTakeAppointmentOnline: item.canTakeAppointmentOnline,
              ),
            ),
          ),
        );
      },
    );
  }
}