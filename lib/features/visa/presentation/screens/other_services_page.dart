import '../../data/services/thailand_alert_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';
import 'package:mytogetherapp/core/presentation/widgets/empty_state_view.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_icon.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'package:mytogetherapp/core/utils/haptic_splash_factory.dart';
import '../widgets/tm47_checker_sheet.dart';
import 'feature_detail_pages.dart';

class OtherServicesPage extends StatefulWidget {
  const OtherServicesPage({super.key});

  @override
  State<OtherServicesPage> createState() => _OtherServicesPageState();
}

class _OtherServicesPageState extends State<OtherServicesPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  bool _isScrolled = false;

  DateTime? _tm47Date;
  ThailandVisaCategory _selectedCategory = ThailandVisaCategory.mouWork;
  DateTime? _visaExpiryDate;
  bool _visaReminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSavedTm47();
    _loadVisaCategoryState();
  }

  void _onScroll() {
    final scrolled = _scrollController.hasClients && _scrollController.offset > 70;
    if (scrolled != _isScrolled && mounted) {
      setState(() => _isScrolled = scrolled);
    }
  }

  Future<void> _loadVisaCategoryState() async {
    final cat = await ThailandAlertService.instance.getSelectedCategory();
    final date = await ThailandAlertService.instance.getVisaExpiryDate();
    final reminder = await ThailandAlertService.instance.isVisaReminderEnabled();
    if (mounted) {
      setState(() {
        _selectedCategory = cat;
        _visaExpiryDate = date;
        _visaReminderEnabled = reminder;
      });
    }
  }

  Future<void> _selectCategory(ThailandVisaCategory cat) async {
    AppHaptics.buttonTap();
    setState(() => _selectedCategory = cat);
    await ThailandAlertService.instance.setSelectedCategory(cat);
  }

  Future<void> _pickVisaExpiryDate() async {
    AppHaptics.buttonTap();
    final now = DateTime.now();
    final initial = _visaExpiryDate ?? now.add(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      await ThailandAlertService.instance.setVisaExpiryDate(picked);
      setState(() => _visaExpiryDate = picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _l(
                'Visa expiry date saved & 30d, 14d, 3d reminders scheduled!',
                'ဗီဇာသက်တမ်းရက် သိမ်းဆည်းပြီး ၃၀ ရက်၊ ၁၄ ရက်၊ ၃ ရက် သတိပေးချက်များ ပြင်ဆင်ပြီးပါပြီ။',
                'บันทึกวันหมดอายุและตั้งเตือนแล้ว!',
              ),
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleVisaReminder(bool val) async {
    AppHaptics.buttonTap();
    setState(() => _visaReminderEnabled = val);
    await ThailandAlertService.instance.setVisaReminderEnabled(val);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            val
                ? _l(
                    'Visa expiry reminders active (30d, 14d, 3d)!',
                    'ဗီဇာသက်တမ်းကုန် သတိပေးချက်များ စတင်ဖွင့်လှစ်ပြီးပါပြီ (၃၀ ရက်၊ ၁၄ ရက်၊ ၃ ရက်)။',
                    'เปิดระบบแจ้งเตือนวันหมดอายุวีซ่าแล้ว!',
                  )
                : _l(
                    'Visa expiry reminders turned off.',
                    'ဗီဇာသက်တမ်းကုန် သတိပေးချက်များ ပိတ်ပြီးပါပြီ။',
                    'ปิดการแจ้งเตือนแล้ว',
                  ),
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testVisaNotification() async {
    AppHaptics.buttonTap();
    await ThailandAlertService.instance.sendTestNotification(
      title: '🚨 ဗီဇာ/Work Permit စမ်းသပ်သတိပေးချက်',
      body: 'သင်၏ ဖုန်းတွင် ထိုင်းဗီဇာ သက်တမ်းကုန်ဆုံးမှု သတိပေးချက်များ အောင်မြင်စွာ ချိတ်ဆက်ပြီးပါပြီ။',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _l(
              'Test notification sent! Check your notification bar.',
              'စမ်းသပ်သတိပေးချက် ပို့ပြီးပါပြီ။ ဖုန်း၏ Notification bar တွင် ကြည့်ပါ။',
              'ส่งการแจ้งเตือนทดสอบแล้ว!',
            ),
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String _l(String en, String mm, String th) =>
      LocaleController.instance.localized(en: en, mm: mm, th: th);

  Future<void> _loadSavedTm47() async {
    final date = await Tm47Service.getSavedDate();
    if (mounted) {
      setState(() {
        _tm47Date = date;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    AppHaptics.buttonTap();
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  void _nav(Widget page) {
    AppHaptics.buttonTap();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  List<(IconData, String, String, String, String, VoidCallback, String)>
      get _features => [
            (
              PhosphorIconsFill.clockCountdown,
              _l('OT Calculator', 'OT အချိန်ပိုတွက်စက်', 'คำนวณโอที'),
              _l(
                '1.5x, 2x, 3x overtime pay',
                '၁.၅ ဆ၊ ၂ ဆ၊ ၃ ဆ လုပ်ခတွက်ရန်',
                'โอที 1.5, 2, 3 เท่า',
              ),
              _l('Labour Law', 'အလုပ်သမားဥပဒေ', 'กฎหมายแรงงาน'),
              'calc',
              () => _nav(const OtCalculatorDetailPage()),
              'ot overtime salary အချိန်ပို လုပ်ခ',
            ),
            (
              PhosphorIconsFill.money,
              _l('Severance Pay', 'အလုပ်ထုတ်နစ်နာကြေး', 'ค่าชดเชยเลิกจ้าง'),
              _l(
                'Section 118: 30-400 days',
                'ပုဒ်မ ၁၁၈ ရက် ၃၀-၄၀၀ လျော်ကြေး',
                'มาตรา 118: 30-400 วัน',
              ),
              _l('Section 118', 'ပုဒ်မ ၁၁၈', 'มาตรา 118'),
              'calc',
              () => _nav(const SeveranceDetailPage()),
              'severance compensation 118 နစ်နာကြေး လျော်ကြေး',
            ),
            (
              PhosphorIconsFill.scales,
              _l('Labor Rights', 'အလုပ်သမားအခွင့်အရေး', 'สิทธิแรงงาน'),
              _l(
                'Hours, leaves & protection',
                'အလုပ်ချိန်၊ ဆေးခွင့်နှင့် နားရက်',
                'เวลาทำงาน วันลา และการคุ้มครอง',
              ),
              _l('Rights', 'အခွင့်အရေး', 'สิทธิ'),
              'law',
              () => _nav(const LaborRightsDetailPage()),
              'labor rights leave minimum wage အလုပ်သမား အခွင့်အရေး ဆေးခွင့်',
            ),
            (
              PhosphorIconsFill.firstAidKit,
              _l('Social Security', 'လူမှုဖူလုံရေး SSO', 'ประกันสังคม'),
              _l(
                'Section 33 healthcare & fund',
                'မတ်တြာ ၃၃ ဆေးရုံနှင့် အကျိုးခံစားခွင့်',
                'มาตรา 33 รักษาฟรีและสิทธิประโยชน์',
              ),
              _l('SSO 33', 'မတ်တြာ ၃၃', 'ม.33'),
              'law',
              () => _nav(const SsoDetailPage()),
              'sso social security 33 လူမှုဖူလုံရေး ဆေးရုံ ပကန်ဆန်ခွန်',
            ),
            (
              PhosphorIconsFill.warningOctagon,
              _l('Fines & Rules', 'ဒဏ်ကြေးနှင့်ဥပဒေများ', 'ค่าปรับและกฎหมาย'),
              _l(
                'Overstay & Vape ban rules',
                'Overstay နှင့် Vape ဥပဒေပြစ်ဒဏ်',
                'อยู่เกินกำหนดและบุหรี่ไฟฟ้า',
              ),
              _l('Important', 'သတိပြုရန်', 'สำคัญ'),
              'law',
              () => _nav(const ThaiFinesDetailPage()),
              'fine overstay vape blacklist ဒဏ်ကြေး ဥပဒေ',
            ),
            (
              PhosphorIconsFill.phoneCall,
              _l('Hotlines Directory', 'အရေးပေါ်ဖုန်းများ', 'สายด่วนฉุกเฉิน'),
              _l(
                '1506, 1155, 191, 1669 direct',
                '၁၅၀၆၊ ၁၁၅၅၊ ၁၉၁၊ ၁၆၆၉ ခေါ်ရန်',
                'โทรด่วน 1506, 1155, 191, 1669',
              ),
              _l('Direct Call', 'တိုက်ရိုက်ခေါ်', 'โทรด่วน'),
              'support',
              () => _nav(const HotlinesDetailPage()),
              'hotline emergency phone 1506 1155 191 1669 အရေးပေါ် ဖုန်း',
            ),
            (
              PhosphorIconsFill.globe,
              _l('Official Portals', 'တရားဝင် Portals', 'พอร์ทัลทางการ'),
              _l(
                'E-Visa, TM.47 & SSO links',
                'E-Visa၊ TM.47၊ SSO ဝက်ဘ်ဆိုက်များ',
                'ลิงก์ E-Visa, ตม.47, ประกันสังคม',
              ),
              _l('Websites', 'ဝက်ဘ်ဆိုက်', 'เว็บไซต์'),
              'support',
              () => _openUrl('https://www.immigration.go.th'),
              'portal website immigration mol sso ဝက်ဘ်ဆိုက်',
            ),
          ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (_isScrolled
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light)
          .copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _isScrolled ? Brightness.dark : Brightness.light,
        statusBarBrightness:
            _isScrolled ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: Stack(
        children: [
          ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(overscroll: false),
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: _buildBody(),
                  ),
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
                    'Thai Law & Services',
                    'ထိုင်းဥပဒေနှင့် ဝန်ဆောင်မှုများ',
                    'กฎหมายไทยและบริการสำคัญ',
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

        ],
      ),
    );
  }

  Widget _buildHeader() {
    final top = MediaQuery.of(context).padding.top;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final headerHeight = (isIOS ? 255.0 : 240.0) + top;

    return SizedBox(
      width: double.infinity,
      height: headerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          // Extended Sky Overscroll Filler: eliminates white gap when pulled down
          Positioned(
            top: -400,
            left: 0,
            right: 0,
            height: 400,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFA7D7FF),
                    Color(0xFFD7BAAF),
                  ],
                ),
              ),
            ),
          ),
          // Background Illustration Image (1024x576)
          Image.asset(
            'assets/images/thai_law_header_bg.webp',
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
          // Smooth bottom fade-to-white gradient style (Visa Page Style)
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
          // Header Foreground Content (Visa Page Style)
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 56, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  _l(
                    'Thai Law & Essential Services',
                    'ထိုင်းဥပဒေနှင့် ဝန်ဆောင်မှုများ',
                    'กฎหมายและบริการสำคัญในไทย',
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
                    'Labour laws, rights, fines & stay rules',
                    'အလုပ်သမားဥပဒေ၊ အခွင့်အရေး၊ ဒဏ်ကြေးနှင့် စည်းမျဉ်းများ',
                    'กฎหมายแรงงาน สิทธิแรงงาน ค่าปรับ และการพำนัก',
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
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim()),
              cursorColor: AppColors.primary,
              style: AppFonts.poppins(
                color: const Color(0xFF1E293B),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: _l(
                  'Search 90-day, OT, SSO, fines & hotlines...',
                  'ရက် ၉၀၊ OT၊ လူမှုဖူလုံရေးနှင့် ဖုန်းများ ရှာရန်...',
                  'ค้นหา 90 วัน โอที ประกันสังคม และสายด่วน...',
                ),
                hintStyle: AppFonts.poppins(
                  color: const Color(0xFF94A3B8),
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
                FocusScope.of(context).unfocus();
              },
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildBody() {
    final q = _query.toLowerCase();
    final is90Match = q.isNotEmpty &&
        ('90-day tm47 report ရက် ၉၀ တာဝန်ခံ တွက်စက်'.contains(q) ||
            '90'.contains(q) ||
            'tm47'.contains(q));
    final isVisaMatch = q.isNotEmpty &&
        ('visa alert expiry category mou dtv tourist ed non-b non-o ltr ဗီဇာ စည်းမျဉ်း သက်တမ်း'.contains(q));
    final filtered = _features.where((f) {
      return q.isEmpty ||
          f.$2.toLowerCase().contains(q) ||
          f.$3.toLowerCase().contains(q) ||
          f.$4.toLowerCase().contains(q) ||
          f.$7.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (q.isEmpty || is90Match || isVisaMatch) ...[
          _buildSectionHeader(
            title: _l(
              'Compliance & Expiry Alerts',
              'သတိပေးချက်နှင့် စောင့်ကြည့်စနစ်များ',
              'การแจ้งเตือนและการปฏิบัติตามกฎ',
            ),
          ),
          const SizedBox(height: 12),
          _buildNotificationCardsRow(),
          const SizedBox(height: 18),
        ],
        _buildSectionHeader(
          title: _l(
            'Essential Law & Services',
            'အဓိက ဥပဒေနှင့် ဝန်ဆောင်မှုများ',
            'บริการและกฎหมายสำคัญ',
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: EmptyStateView(
              icon: PhosphorIconsRegular.scales,
              subtitle: _l(
                'No matching services found',
                'ရှာဖွေသော ဝန်ဆောင်မှု မတွေ့ရှိပါ',
                'ไม่พบบริการที่ค้นหา',
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final f = filtered[i];
              return _buildServiceTile(
                icon: f.$1,
                title: f.$2,
                subtitle: f.$3,
                onTap: f.$6,
              );
            },
          ),
        const SizedBox(height: 20),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildNotificationCardsRow() {
    final hasDate = _tm47Date != null;
    final calc = hasDate ? Tm47Calculation.fromDate(_tm47Date!) : null;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTm47Card(calc, dateFormat),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildVisaAlertCard(dateFormat),
        ),
      ],
    );
  }

  Widget _buildTm47Card(Tm47Calculation? calc, DateFormat dateFormat) {
    Color statusDotColor = const Color(0xFF10B981);
    String statusTitle = _l('Safe', 'ပုံမှန်', 'ปกติ');
    String daysText = '';

    if (calc != null) {
      switch (calc.status) {
        case Tm47Status.safe:
          statusDotColor = const Color(0xFF10B981);
          statusTitle = _l('Safe', 'ပုံမှန်', 'ปกติ');
          daysText = _l('${calc.daysRemaining}d left', '${calc.daysRemaining} ရက်လို', 'เหลือ ${calc.daysRemaining} วัน');
          break;
        case Tm47Status.open:
          statusDotColor = const Color(0xFFF59E0B);
          statusTitle = _l('Open', 'ယခုတင်ပါ', 'ยื่นได้');
          daysText = _l('${calc.daysRemaining}d left', '${calc.daysRemaining} ရက်လို', 'เหลือ ${calc.daysRemaining} วัน');
          break;
        case Tm47Status.grace:
          statusDotColor = const Color(0xFFEA580C);
          statusTitle = _l('Grace', 'သက်ညှာခွင့်', 'ผ่อนผัน');
          daysText = _l('${calc.daysRemaining.abs()}d in grace', 'သက်ညှာ ${calc.daysRemaining.abs()} ရက်', 'ผ่อนผัน ${calc.daysRemaining.abs()} วัน');
          break;
        case Tm47Status.overdue:
          statusDotColor = const Color(0xFFEF4444);
          statusTitle = _l('Overdue', 'ရက်လွန်', 'เกินกำหนด');
          daysText = _l('Fine 2,000฿', 'ဒဏ်ကြေးကျပြီ', 'ปรับ 2,000฿');
          break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _showTm47DetailModal(context),
          borderRadius: BorderRadius.circular(18),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Icon Squircle + Reminder Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.12),
                            AppColors.secondary.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          width: 0.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const GradientIcon(
                        icon: PhosphorIconsFill.clockCountdown,
                        size: 20,
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: _tm47Date != null
                            ? statusDotColor.withValues(alpha: 0.12)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _tm47Date != null
                                ? PhosphorIconsFill.checkCircle
                                : PhosphorIconsFill.bellRinging,
                            size: 11,
                            color: _tm47Date != null
                                ? statusDotColor
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 3.5),
                          Text(
                            _tm47Date != null ? statusTitle : _l('Reminder', 'သတိပေးစနစ်', 'เตือน'),
                            style: AppFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: _tm47Date != null
                                  ? statusDotColor
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Title
                Text(
                  _l('90-Day (TM.47)', 'ရက် ၉၀ (TM.47)', 'รายงานตัว 90 วัน'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                // Single clean status line
                if (calc != null)
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: statusDotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${dateFormat.format(calc.dueDate)} · $daysText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusDotColor,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _l('Not configured yet', 'ရက်စွဲ မသတ်မှတ်ရသေးပါ', 'ยังไม่ได้ระบุวัน'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                const SizedBox(height: 12),
                // Sleek Rounded Bottom Action Pill
                Container(
                  width: double.infinity,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        calc != null
                            ? _l('Check Details', 'စစ်ဆေးမည်', 'ตรวจดู')
                            : _l('Set Date', 'ရက်ရွေးမည်', 'ตั้งวัน'),
                        style: AppFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        PhosphorIconsBold.caretRight,
                        size: 10,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisaAlertCard(DateFormat dateFormat) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int? daysLeft;
    ComplianceUrgency urgency = ComplianceUrgency.safe;

    if (_visaExpiryDate != null) {
      final exp = DateTime(_visaExpiryDate!.year, _visaExpiryDate!.month, _visaExpiryDate!.day);
      daysLeft = exp.difference(today).inDays;
      if (daysLeft < 0) {
        urgency = ComplianceUrgency.overdue;
      } else if (daysLeft <= 14) {
        urgency = ComplianceUrgency.urgent;
      } else if (daysLeft <= 30) {
        urgency = ComplianceUrgency.warning;
      } else {
        urgency = ComplianceUrgency.safe;
      }
    }

    Color urgencyColor;
    String urgencyLabel;
    switch (urgency) {
      case ComplianceUrgency.safe:
        urgencyColor = const Color(0xFF10B981);
        urgencyLabel = daysLeft != null
            ? _l('$daysLeft days left', '$daysLeft ရက်လို', 'เหลือ $daysLeft วัน')
            : '';
        break;
      case ComplianceUrgency.warning:
        urgencyColor = const Color(0xFFF59E0B);
        urgencyLabel = _l('$daysLeft days left', '$daysLeft ရက်လို', 'เหลือ $daysLeft วัน');
        break;
      case ComplianceUrgency.urgent:
        urgencyColor = const Color(0xFFEA580C);
        urgencyLabel = _l('URGENT: $daysLeft d', 'အရေးကြီး: $daysLeft ရက်', 'ด่วน: $daysLeft วัน');
        break;
      case ComplianceUrgency.overdue:
        urgencyColor = const Color(0xFFEF4444);
        urgencyLabel = _l('Expired', 'ရက်လွန်ပြီ', 'หมดอายุแล้ว');
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _showVisaAlertDetailModal(context),
          borderRadius: BorderRadius.circular(18),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Category Icon Squircle + Category Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.12),
                            AppColors.secondary.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          width: 0.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: GradientIcon(
                        icon: PhosphorIconsFill.identificationCard,
                        size: 20,
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getCategoryShortLabel(_selectedCategory),
                        style: AppFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Title
                Text(
                  _l('Visa Alerts', 'ဗီဇာသတိပေးချက်', 'แจ้งเตือนวีซ่า'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                // Single clean status line
                if (_visaExpiryDate != null)
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: urgencyColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${dateFormat.format(_visaExpiryDate!)} · $urgencyLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: urgencyColor,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _l('No expiry date set', 'ရက်စွဲ မသတ်မှတ်ရသေးပါ', 'ยังไม่ได้ระบุวัน'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                const SizedBox(height: 12),
                // Sleek Rounded Bottom Action Pill
                Container(
                  width: double.infinity,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _visaExpiryDate != null
                            ? _l('View Rules', 'စည်းမျဉ်းကြည့်', 'ดูกฎเกณฑ์')
                            : _l('Set Expiry', 'ရက်ရွေးမည်', 'ตั้งวัน'),
                        style: AppFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        PhosphorIconsBold.caretRight,
                        size: 10,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            AppHaptics.buttonTap();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFF0F172A).withValues(alpha: 0.05),
          highlightColor: const Color(0xFF0F172A).withValues(alpha: 0.02),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                // Icon Squircle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      width: 0.8,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: GradientIcon(
                    icon: icon,
                    size: 22,
                    gradient: AppColors.primaryGradient,
                  ),
                ),
                const SizedBox(width: 13),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.poppins(
                          fontSize: 13.8,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Trailing clean caret
                const Icon(
                  PhosphorIconsBold.caretRight,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTm47DetailModal(BuildContext context) {
    AppHaptics.buttonTap();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _Tm47DetailModalSheet(
        onUpdated: () {
          _loadSavedTm47();
        },
      ),
    );
  }

  void _showVisaAlertDetailModal(BuildContext context) {
    AppHaptics.buttonTap();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _VisaAlertDetailModalSheet(
        onUpdated: () {
          _loadVisaCategoryState();
        },
      ),
    );
  }

  Widget _buildSectionHeader({required String title}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
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
          Text(
            title,
            style: AppFonts.poppins(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryShortLabel(ThailandVisaCategory cat) {
    switch (cat) {
      case ThailandVisaCategory.mouWork:
        return 'MOU/Work';
      case ThailandVisaCategory.dtv:
        return 'DTV Nomad';
      case ThailandVisaCategory.education:
        return 'Non-ED';
      case ThailandVisaCategory.tourist:
        return 'Tourist';
      case ThailandVisaCategory.nonO:
        return 'Non-O';
      case ThailandVisaCategory.ltr:
        return 'LTR VIP';
    }
  }

  IconData _getCategoryIcon(ThailandVisaCategory cat) {
    switch (cat) {
      case ThailandVisaCategory.mouWork:
        return PhosphorIconsFill.briefcase;
      case ThailandVisaCategory.dtv:
        return PhosphorIconsFill.laptop;
      case ThailandVisaCategory.education:
        return PhosphorIconsFill.graduationCap;
      case ThailandVisaCategory.tourist:
        return PhosphorIconsFill.compass;
      case ThailandVisaCategory.nonO:
        return PhosphorIconsFill.usersThree;
      case ThailandVisaCategory.ltr:
        return PhosphorIconsFill.crown;
    }
  }

  String _getCategoryBadge(ThailandVisaCategory cat) {
    switch (cat) {
      case ThailandVisaCategory.mouWork:
        return 'LABOUR & DEPT OF EMPLOYMENT';
      case ThailandVisaCategory.dtv:
        return 'NEW DTV SCHEME 2024-2026';
      case ThailandVisaCategory.education:
        return 'MINISTRY OF EDUCATION & IMMIGRATION';
      case ThailandVisaCategory.tourist:
        return 'TOURIST COMPLIANCE';
      case ThailandVisaCategory.nonO:
        return 'SECTION 35 FAMILY / RETIREMENT';
      case ThailandVisaCategory.ltr:
        return 'BOARD OF INVESTMENT (BOI)';
    }
  }

  String _getCategoryTitle(ThailandVisaCategory cat) {
    switch (cat) {
      case ThailandVisaCategory.mouWork:
        return _l('MOU & Non-B (Work Permit)', 'MOU နှင့် အလုပ်သမားဗီဇာ (Non-B)', 'วีซ่าทำงาน MOU และ Non-B');
      case ThailandVisaCategory.dtv:
        return _l('Destination Thailand Visa (DTV)', 'DTV (Digital Nomad ဗီဇာ)', 'วีซ่าพำนักระยะยาว DTV');
      case ThailandVisaCategory.education:
        return _l('Non-ED (Education Visa)', 'Non-ED (ပညာသင်ဗီဇာ)', 'วีซ่านักเรียน Non-ED');
      case ThailandVisaCategory.tourist:
        return _l('Tourist & Visa Exemption', 'ကမ္ဘာလှည့်ခရီးသွား (ရက် ၆၀)', 'วีซ่าท่องเที่ยวและยกเว้นวีซ่า');
      case ThailandVisaCategory.nonO:
        return _l('Non-O (Family / Retirement)', 'Non-O (မှီခို / အငြိမ်းစား)', 'วีซ่าครอบครัวและบำนาญ Non-O');
      case ThailandVisaCategory.ltr:
        return _l('Long-Term Resident (LTR)', 'LTR (ရေရှည်နေထိုင်ခွင့်)', 'วีซ่าพำนักระยะยาวพิเศษ LTR');
    }
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
                  'Official Legal Disclaimer',
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
              'This page provides general guidance based on official regulations of the Thai Immigration Bureau and Ministry of Labour. For complex cases, call 1506 or consult licensed legal counsel.',
              'ဤအချက်အလက်များသည် ထိုင်းလူဝင်မှုကြီးကြပ်ရေးနှင့် အလုပ်သမားဝန်ကြီးဌာန၏ တရားဝင် ထုတ်ပြန်ချက်များအပေါ် အခြေခံထားသော လမ်းညွှန်ချက်သာ ဖြစ်သည်။ အရေးပေါ် အငြင်းပွားမှုများအတွက် ၁၅၀၆ သို့ တိုက်ရိုက်ဆက်သွယ်ပါ။',
              'ข้อมูลนี้เป็นคำแนะนำทั่วไปตามระเบียบของสตม.และกระทรวงแรงงาน หากมีข้อพิพาทโทร 1506 หรือปรึกษาผู้เชี่ยวชาญ',
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
              _linkChip('immigration.go.th', 'https://www.immigration.go.th'),
              _linkChip('mol.go.th', 'https://www.mol.go.th'),
              _linkChip('sso.go.th', 'https://www.sso.go.th'),
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
}



/// Detailed Interactive Modal Sheet for 90-Day (TM.47) Report
class _Tm47DetailModalSheet extends StatefulWidget {
  final VoidCallback onUpdated;

  const _Tm47DetailModalSheet({required this.onUpdated});

  @override
  State<_Tm47DetailModalSheet> createState() => _Tm47DetailModalSheetState();
}

class _Tm47DetailModalSheetState extends State<_Tm47DetailModalSheet> {
  DateTime? _selectedDate;
  int _entryType = 0; // 0 = Last report date, 1 = Arrival date
  bool _reminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  String _l(String en, String mm, String th) =>
      LocaleController.instance.localized(en: en, mm: mm, th: th);

  Future<void> _loadState() async {
    final date = await Tm47Service.getSavedDate();
    final type = await Tm47Service.getSavedType();
    final reminder = await ThailandAlertService.instance.isTm47ReminderEnabled();
    if (mounted) {
      setState(() {
        _selectedDate = date;
        _entryType = type;
        _reminderEnabled = reminder;
      });
    }
  }

  Future<void> _pickDate() async {
    AppHaptics.buttonTap();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(now.year - 5, 1, 1);
    final lastDate = DateTime(now.year + 1, 12, 31);
    final initial = _selectedDate ?? today;
    final safeInitial = initial.isBefore(firstDate)
        ? firstDate
        : (initial.isAfter(lastDate) ? today : initial);

    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      await Tm47Service.save(picked, _entryType);
      widget.onUpdated();
    }
  }

  Future<void> _clearDate() async {
    AppHaptics.buttonTap();
    await Tm47Service.clear();
    setState(() => _selectedDate = null);
    widget.onUpdated();
  }

  Future<void> _toggleReminder(bool val) async {
    AppHaptics.buttonTap();
    setState(() => _reminderEnabled = val);
    await ThailandAlertService.instance.setTm47ReminderEnabled(val, baseDate: _selectedDate);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            val
                ? _l(
                    '90-Day auto-reminders active (15d, 7d, Due, Grace)!',
                    '90-Day အလိုအလျောက် သတိပေးချက်များ စတင်ဖွင့်လှစ်ပြီးပါပြီ (၁၅ ရက်၊ ၇ ရက်၊ နောက်ဆုံးရက်၊ သက်ညှာခွင့်)။',
                    'เปิดระบบแจ้งเตือน 90 วันอัตโนมัติแล้ว!',
                  )
                : _l(
                    '90-Day reminders turned off.',
                    '90-Day သတိပေးချက်များ ပိတ်ပြီးပါပြီ။',
                    'ปิดการแจ้งเตือนแล้ว',
                  ),
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    AppHaptics.buttonTap();
    await ThailandAlertService.instance.sendTestNotification(
      title: '🔔 90-Day (TM.47) စမ်းသပ်သတိပေးချက်',
      body: 'သင်၏ ဖုန်းတွင် 90-Day သတိပေးချက်များ အောင်မြင်စွာ ချိတ်ဆက်ပြီးပါပြီ။ သတ်မှတ်ရက်မတိုင်မီ အချိန်မီ သတိပေးသွားမည် ဖြစ်ပါသည်။',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _l(
              'Test notification sent! Check notification bar.',
              'စမ်းသပ်သတိပေးချက် ပို့ပြီးပါပြီ။ ဖုန်း၏ Notification bar တွင် ကြည့်ရှုပါ။',
              'ส่งการแจ้งเตือนทดสอบแล้ว!',
            ),
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openExternal(String url) async {
    AppHaptics.buttonTap();
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final hasDate = _selectedDate != null;
    final calc = hasDate ? Tm47Calculation.fromDate(_selectedDate!) : null;

    Color statusColor = AppColors.primary;
    String statusTitle = '';
    String statusSubtitle = '';
    IconData statusIcon = PhosphorIconsFill.calendarBlank;

    if (calc != null) {
      switch (calc.status) {
        case Tm47Status.safe:
          statusColor = const Color(0xFF10B981);
          statusIcon = PhosphorIconsFill.checkCircle;
          statusTitle = _l('Safe & Valid', 'အချိန်မီပါသေးသည်', 'ยังอยู่ในกำหนดปกติ');
          statusSubtitle = '${_l('Days remaining: ', 'ကျန်ရှိသောရက်: ', 'จำนวนวันที่เหลือ: ')}${calc.daysRemaining} ${_l('days', 'ရက်', 'วัน')}';
          break;
        case Tm47Status.open:
          statusColor = const Color(0xFFF59E0B);
          statusIcon = PhosphorIconsFill.bellRinging;
          statusTitle = _l('Window Open - Report Now', 'ယခု တင်သွင်းနိုင်ပါပြီ', 'เปิดให้รายงานตัวแล้ว');
          statusSubtitle = calc.daysRemaining == 0
              ? _l('Today is your deadline day!', 'ယနေ့သည် သတ်မှတ်ရက် နောက်ဆုံးနေ့ ဖြစ်ပါသည်!', 'วันนี้คือวันครบกำหนด!')
              : '${_l('Days until due date: ', 'သတ်မှတ်ရက်ပြည့်ရန်: ', 'เหลือก่อนครบกำหนด: ')}${calc.daysRemaining} ${_l('days', 'ရက်', 'วัน')}';
          break;
        case Tm47Status.grace:
          statusColor = const Color(0xFFEA580C);
          statusIcon = PhosphorIconsFill.warning;
          statusTitle = _l('Grace Period (7 Days)', '၇ ရက် သက်ညှာခွင့်ကာလအတွင်း', 'อยู่ในช่วงผ่อนผัน 7 วัน');
          statusSubtitle = '${_l('Due date passed ', 'သတ်မှတ်ရက်ကျော်လွန်သည်မှာ ', 'เกินกำหนดมาแล้ว ')}${-calc.daysRemaining} ${_l('days ago (Report immediately)', 'ရက် ရှိပါပြီ (ချက်ချင်းတင်ပါ)', 'วัน (รีบรายงานตัวด่วน)')}';
          break;
        case Tm47Status.overdue:
          statusColor = const Color(0xFFEF4444);
          statusIcon = PhosphorIconsFill.xCircle;
          statusTitle = _l('Overdue - 2,000 THB Fine', 'ရက်လွန်ဒဏ်ကြေး ကျသင့်ပါပြီ', 'เกินกำหนด - มีค่าปรับ 2,000 บาท');
          statusSubtitle = '${_l('Overdue by ', 'ရက်လွန်သွားသည်မှာ ', 'เกินกำหนดมาแล้ว ')}${-calc.daysRemaining} ${_l('days. Overstay fine applies.', 'ရက် ဖြစ်ပါသည် (ဒဏ်ကြေး ပေးဆောင်ရမည်)။', 'วัน ต้องชำระค่าปรับ')}';
          break;
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle Bar
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            // Header Row: Title & Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      PhosphorIconsFill.clockCountdown,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _l('90-Day (TM.47) Report', 'ရက် ၉၀ (TM.47) စစ်ဆေးတွက်ချက်မှု', 'ตรวจรายงานตัว 90 วัน (ตม.47)'),
                          style: AppFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _l('Immigration Bureau 2026 Regulation', 'ထိုင်းလူဝင်မှုကြီးကြပ်ရေး တရားဝင်စနစ်', 'ระเบียบสำนักงานตรวจคนเข้าเมือง'),
                          style: AppFonts.poppins(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEDF2F7)),
            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode Switcher Tab
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEEF2),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _modeTab(
                              0,
                              _l('Last Report Date', 'နောက်ဆုံး တိုင်ကြားသည့်ရက်', 'วันรายงานตัวล่าสุด'),
                            ),
                          ),
                          Expanded(
                            child: _modeTab(
                              1,
                              _l('Arrival Date', 'ထိုင်းသို့ ဝင်ရောက်သည့်ရက်', 'วันเดินทางเข้าไทย'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date Picker Card
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasDate ? const Color(0xFFEDF2F7) : AppColors.primary.withValues(alpha: 0.35),
                            width: hasDate ? 1 : 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIconsFill.calendarBlank,
                              color: hasDate ? AppColors.primary : const Color(0xFF64748B),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _entryType == 0
                                        ? _l('Previous TM.47 Receipt Date', 'ယခင် တိုင်ကြားခဲ့သော ပြေစာရက်စွဲ', 'วันที่ตามใบรับ ตม.47 ล่าสุด')
                                        : _l('Passport Entry Stamp Date', 'ပတ်စပို့ ဝင်ရောက်တံဆိပ်တုံး ရက်စွဲ', 'วันที่ประทับตราเข้าเมืองล่าสุด'),
                                    style: AppFonts.poppins(
                                      fontSize: 11.5,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasDate
                                        ? dateFormat.format(_selectedDate!)
                                        : _l('Select date to calculate', 'ရက်စွဲ မသတ်မှတ်ရသေးပါ (ရွေးပါ)', 'ยังไม่ได้ระบุ (แตะเพื่อเลือก)'),
                                    style: AppFonts.poppins(
                                      fontSize: 14.5,
                                      fontWeight: hasDate ? FontWeight.w700 : FontWeight.w600,
                                      color: hasDate ? const Color(0xFF0F172A) : AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.28),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                hasDate
                                    ? _l('Change', 'ရက်ပြောင်း', 'เปลี่ยนวัน')
                                    : _l('Pick Date', 'ရက်ရွေးမည်', 'เลือกวันที่'),
                                style: AppFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Results if date is selected
                    if (hasDate && calc != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(statusIcon, color: statusColor, size: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    statusTitle,
                                    style: AppFonts.poppins(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: statusColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    statusSubtitle,
                                    style: AppFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _clearDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _l('Reset', 'ရှင်းမည်', 'รีเซ็ต'),
                                  style: AppFonts.poppins(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Breakdown table
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEDF2F7)),
                        ),
                        child: Column(
                          children: [
                            _dateRow(
                              title: _l('Exact Due Date (Day 90)', 'သတ်မှတ်ရက်ပြည့်မြောက်မည့်နေ့ (ရက် ၉၀)', 'วันครบกำหนดตรง (วันที่ 90)'),
                              dateStr: dateFormat.format(calc.dueDate),
                              isHighlight: true,
                            ),
                            const Divider(height: 20, thickness: 0.6, color: Color(0xFFF1F5F9)),
                            _dateRow(
                              title: _l('Earliest Submission (15 Days Before)', 'စတင်တင်သွင်းနိုင်သည့်ရက် (၁၅ ရက် ကြိုတင်)', 'เริ่มยื่นล่วงหน้าได้ (15 วันก่อนกำหนด)'),
                              dateStr: dateFormat.format(calc.windowStart),
                            ),
                            const Divider(height: 20, thickness: 0.6, color: Color(0xFFF1F5F9)),
                            _dateRow(
                              title: _l('Latest Allowed Date (7 Days Grace)', 'နောက်ဆုံးခွင့်ပြုသည့်ရက် (၇ ရက် သက်ညှာခွင့်)', 'วันสุดท้ายที่ผ่อนผัน (7 วันหลังกำหนด)'),
                              dateStr: dateFormat.format(calc.windowEnd),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Auto Reminders Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF1F5F9),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(11),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  PhosphorIconsFill.bellRinging,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _l('90-Day Auto Reminders', '90-Day အလိုအလျောက် သတိပေးချက်များ', 'ระบบแจ้งเตือน 90 วันอัตโนมัติ'),
                                      style: AppFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      _l('Never miss deadline (15d, 7d, Due, Grace)', 'ရက် ၁၅၊ ၇၊ နောက်ဆုံးရက်နှင့် သက်ညှာခွင့်များတွင် သတိပေးမည်', 'แจ้งเตือน 15 วัน 7 วัน ครบกำหนด และผ่อนผัน'),
                                      style: AppFonts.poppins(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _reminderEnabled,
                                onChanged: _toggleReminder,
                                activeColor: AppColors.primary,
                              ),
                            ],
                          ),
                          if (_reminderEnabled) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFF1F5F9),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  _milestoneRow('15d Before', _l('Window opens for filing', 'စတင်တင်သွင်းခွင့်ရသည့်ရက်', 'เปิดยื่นรายงานตัว'), const Color(0xFF10B981)),
                                  const SizedBox(height: 8),
                                  _milestoneRow('7d Warning', _l('Urgent reminder before due', 'ဒဏ်ကြေးမကျစေရန် အရေးကြီးသတိပေးချက်', 'เตือนด่วนก่อนครบกำหนด'), const Color(0xFFF59E0B)),
                                  const SizedBox(height: 8),
                                  _milestoneRow('Due Date', _l('Day 90 final deadline', 'ရက် ၉၀ နောက်ဆုံးထားတင်ရမည့်ရက်', 'วันครบกำหนด 90 วัน'), const Color(0xFFEA580C)),
                                  const SizedBox(height: 8),
                                  _milestoneRow('Grace Period', _l('Final 7-day in-person window', 'လ.ဝ.က လူကိုယ်တိုင်သွားရန် ၇ ရက် သက်ညှာခွင့်', 'ผ่อนผัน 7 วัน ยื่นด้วยตนเอง'), const Color(0xFFEF4444)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _sendTestNotification,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(PhosphorIconsBold.bellRinging, size: 15, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      _l('Send Test Notification to Phone', 'ဖုန်းသို့ စမ်းသပ်သတိပေးချက် ပို့မည်', 'ส่งการแจ้งเตือนทดสอบไปยังมือถือ'),
                                      style: AppFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rules Guide
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEDF2F7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(PhosphorIconsFill.info, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                _l('Official 90-Day Regulations', 'တရားဝင် ရက် ၉၀ စည်းမျဉ်းများ', 'ระเบียบการรายงานตัว 90 วัน'),
                                style: AppFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _bullet(_l(
                            'Foreigners staying over 90 days on non-immigrant visas must notify immigration of their residence every 90 days.',
                            'ထိုင်းနိုင်ငံတွင် ယာယီဗီဇာ (Non-B, Non-O, Non-ED, LTR စသည်) ဖြင့် ရက် ၉၀ ကျော် နေထိုင်သူတိုင်း ရက် ၉၀ လျှင် တစ်ကြိမ် နေရပ်လိပ်စာ တိုင်ကြားရမည်။',
                            'ชาวต่างชาติที่พำนักเกิน 90 วันด้วยวีซ่าชั่วคราว ต้องรายงานที่พักทุก 90 วัน',
                          )),
                          _bullet(_l(
                            'Online reporting can be filed 15 days up to 7 days before the due date at tm47.immigration.go.th.',
                            'အွန်လိုင်းမှ တင်ပါက သတ်မှတ်ရက် မတိုင်မီ ၁၅ ရက်မှ ၇ ရက် ကြိုတင်၍ tm47.immigration.go.th တွင် တင်သွင်းနိုင်သည်။',
                            'รายงานตัวออนไลน์ได้ล่วงหน้า 15 ถึง 7 วันก่อนครบกำหนดที่ tm47.immigration.go.th',
                          )),
                          _bullet(_l(
                            'Leaving Thailand on a valid re-entry permit resets your 90-day count to 1 on the day you re-enter Thailand.',
                            'Re-entry permit ဖြင့် ထိုင်းနိုင်ငံပြင်ပသို့ ထွက်ခွာပါက ထိုင်းနိုင်ငံသို့ ပြန်လည်ဝင်ရောက်သည့်ရက်မှစ၍ ရက် ၉၀ ရေတွက်မှု ပြန်လည်စတင်ပါသည်။',
                            'หากเดินทางออกนอกประเทศด้วย Re-entry permit ให้นับ 90 วันใหม่ตั้งแต่วันที่กลับเข้าไทย',
                          )),
                          _bullet(_l(
                            'Late report penalty is 2,000 THB; if arrested without filing, penalty is up to 5,000 THB + 200 THB per day.',
                            'ရက်လွန်ဒဏ်ကြေးမှာ ၂,၀၀၀ ဘတ် ဖြစ်ပြီး ဖမ်းဆီးခံရပါက ၅,၀၀၀ ဘတ်အထိနှင့် တစ်ရက်လျှင် ၂၀၀ ဘတ် ထပ်ဆောင်း ဒဏ်တပ်ခံရနိုင်သည်။',
                            'ค่าปรับรายงานตัวช้า 2,000 บาท หากถูกจับกุมปรับสูงสุด 5,000 บาท + วันละ 200 บาท',
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Action Button
                    GestureDetector(
                      onTap: () => _openExternal('https://tm47.immigration.go.th/'),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(PhosphorIconsBold.globe, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              _l('Open TM.47 Online System', 'တရားဝင် TM.47 Online စနစ် ဖွင့်မည်', 'เปิดระบบรายงานตัว 90 วันออนไลน์'),
                              style: AppFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeTab(int index, String label) {
    final isSelected = _entryType == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppHaptics.buttonTap();
        setState(() => _entryType = index);
        if (_selectedDate != null) {
          Tm47Service.save(_selectedDate!, index);
          widget.onUpdated();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.poppins(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _dateRow({
    required String title,
    required String dateStr,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppFonts.poppins(
              fontSize: 12.5,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
              color: isHighlight ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          dateStr,
          style: AppFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isHighlight ? AppColors.primary : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _milestoneRow(String tag, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            tag,
            style: AppFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppFonts.poppins(
              fontSize: 11.5,
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 8),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppFonts.poppins(
                fontSize: 11.5,
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Detailed Interactive Modal Sheet for Visa Category Compliance Alerts & Rules
class _VisaAlertDetailModalSheet extends StatefulWidget {
  final VoidCallback onUpdated;

  const _VisaAlertDetailModalSheet({required this.onUpdated});

  @override
  State<_VisaAlertDetailModalSheet> createState() => _VisaAlertDetailModalSheetState();
}

class _VisaAlertDetailModalSheetState extends State<_VisaAlertDetailModalSheet> {
  ThailandVisaCategory _selectedCategory = ThailandVisaCategory.mouWork;
  DateTime? _visaExpiryDate;
  bool _visaReminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  String _l(String en, String mm, String th) =>
      LocaleController.instance.localized(en: en, mm: mm, th: th);

  Future<void> _loadState() async {
    final cat = await ThailandAlertService.instance.getSelectedCategory();
    final date = await ThailandAlertService.instance.getVisaExpiryDate();
    final reminder = await ThailandAlertService.instance.isVisaReminderEnabled();
    if (mounted) {
      setState(() {
        _selectedCategory = cat;
        _visaExpiryDate = date;
        _visaReminderEnabled = reminder;
      });
    }
  }

  Future<void> _selectCategory(ThailandVisaCategory cat) async {
    AppHaptics.buttonTap();
    setState(() => _selectedCategory = cat);
    await ThailandAlertService.instance.setSelectedCategory(cat);
    widget.onUpdated();
  }

  Future<void> _pickVisaExpiryDate() async {
    AppHaptics.buttonTap();
    final now = DateTime.now();
    final initial = _visaExpiryDate ?? now.add(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      await ThailandAlertService.instance.setVisaExpiryDate(picked);
      setState(() => _visaExpiryDate = picked);
      widget.onUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _l(
                'Visa expiry date saved & 30d, 14d, 3d reminders scheduled!',
                'ဗီဇာသက်တမ်းရက် သိမ်းဆည်းပြီး ၃၀ ရက်၊ ၁၄ ရက်၊ ၃ ရက် သတိပေးချက်များ ပြင်ဆင်ပြီးပါပြီ။',
                'บันทึกวันหมดอายุและตั้งเตือนแล้ว!',
              ),
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleVisaReminder(bool val) async {
    AppHaptics.buttonTap();
    setState(() => _visaReminderEnabled = val);
    await ThailandAlertService.instance.setVisaReminderEnabled(val);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            val
                ? _l(
                    'Visa expiry reminders active (30d, 14d, 3d)!',
                    'ဗီဇာသက်တမ်းကုန် သတိပေးချက်များ စတင်ဖွင့်လှစ်ပြီးပါပြီ (၃၀ ရက်၊ ၁၄ ရက်၊ ၃ ရက်)။',
                    'เปิดระบบแจ้งเตือนวันหมดอายุวีซ่าแล้ว!',
                  )
                : _l(
                    'Visa expiry reminders turned off.',
                    'ဗီဇာသက်တမ်းကုန် သတိပေးချက်များ ပိတ်ပြီးပါပြီ။',
                    'ปิดการแจ้งเตือนแล้ว',
                  ),
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    AppHaptics.buttonTap();
    await ThailandAlertService.instance.sendTestNotification(
      title: '🚨 ဗီဇာ/Work Permit စမ်းသပ်သတိပေးချက်',
      body: 'သင်၏ ဖုန်းတွင် ထိုင်းဗီဇာ သက်တမ်းကုန်ဆုံးမှု သတိပေးချက်များ အောင်မြင်စွာ ချိတ်ဆက်ပြီးပါပြီ။',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _l(
              'Test notification sent! Check your notification bar.',
              'စမ်းသပ်သတိပေးချက် ပို့ပြီးပါပြီ။ ဖုန်း၏ Notification bar တွင် ကြည့်ပါ။',
              'ส่งการแจ้งเตือนทดสอบแล้ว!',
            ),
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  IconData _getCategoryIcon(ThailandVisaCategory cat) {
    switch (cat) {
      case ThailandVisaCategory.mouWork:
        return PhosphorIconsFill.briefcase;
      case ThailandVisaCategory.dtv:
        return PhosphorIconsFill.laptop;
      case ThailandVisaCategory.education:
        return PhosphorIconsFill.graduationCap;
      case ThailandVisaCategory.tourist:
        return PhosphorIconsFill.compass;
      case ThailandVisaCategory.nonO:
        return PhosphorIconsFill.usersThree;
      case ThailandVisaCategory.ltr:
        return PhosphorIconsFill.crown;
    }
  }

  String _getCategoryBadge(ThailandVisaCategory cat) {
    switch (cat) {
      case ThailandVisaCategory.mouWork:
        return 'LABOUR & DEPT OF EMPLOYMENT';
      case ThailandVisaCategory.dtv:
        return 'NEW DTV SCHEME 2024-2026';
      case ThailandVisaCategory.education:
        return 'MINISTRY OF EDUCATION & IMMIGRATION';
      case ThailandVisaCategory.tourist:
        return 'TOURIST COMPLIANCE';
      case ThailandVisaCategory.nonO:
        return 'SECTION 35 FAMILY / RETIREMENT';
      case ThailandVisaCategory.ltr:
        return 'BOARD OF INVESTMENT (BOI)';
    }
  }

  String _getCategoryTitle(ThailandVisaCategory cat) {
    switch (cat) {
      case ThailandVisaCategory.mouWork:
        return _l('MOU & Non-B (Work Permit)', 'MOU နှင့် အလုပ်သမားဗီဇာ (Non-B)', 'วีซ่าทำงาน MOU และ Non-B');
      case ThailandVisaCategory.dtv:
        return _l('Destination Thailand Visa (DTV)', 'DTV (Digital Nomad ဗီဇာ)', 'วีซ่าพำนักระยะยาว DTV');
      case ThailandVisaCategory.education:
        return _l('Non-ED (Education Visa)', 'Non-ED (ပညာသင်ဗီဇာ)', 'วีซ่านักเรียน Non-ED');
      case ThailandVisaCategory.tourist:
        return _l('Tourist & Visa Exemption', 'ကမ္ဘာလှည့်ခရီးသွား (ရက် ၆၀)', 'วีซ่าท่องเที่ยวและยกเว้นวีซ่า');
      case ThailandVisaCategory.nonO:
        return _l('Non-O (Family / Retirement)', 'Non-O (မှီခို / အငြိမ်းစား)', 'วีซ่าครอบครัวและบำนาญ Non-O');
      case ThailandVisaCategory.ltr:
        return _l('Long-Term Resident (LTR)', 'LTR (ရေရှည်နေထိုင်ခွင့်)', 'วีซ่าพำนักระยะยาวพิเศษ LTR');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int? daysLeft;
    ComplianceUrgency urgency = ComplianceUrgency.safe;
    if (_visaExpiryDate != null) {
      final exp = DateTime(_visaExpiryDate!.year, _visaExpiryDate!.month, _visaExpiryDate!.day);
      daysLeft = exp.difference(today).inDays;
      if (daysLeft < 0) {
        urgency = ComplianceUrgency.overdue;
      } else if (daysLeft <= 14) {
        urgency = ComplianceUrgency.urgent;
      } else if (daysLeft <= 30) {
        urgency = ComplianceUrgency.warning;
      } else {
        urgency = ComplianceUrgency.safe;
      }
    }

    Color urgencyColor;
    String urgencyLabel;
    switch (urgency) {
      case ComplianceUrgency.safe:
        urgencyColor = const Color(0xFF10B981);
        urgencyLabel = daysLeft != null
            ? _l('$daysLeft days left', '$daysLeft ရက် လိုသေးသည်', 'เหลืออีก $daysLeft วัน')
            : '';
        break;
      case ComplianceUrgency.warning:
        urgencyColor = const Color(0xFFF59E0B);
        urgencyLabel = _l('$daysLeft days - Renew Soon', '$daysLeft ရက်အလို သက်တမ်းတိုးပါ', 'เหลือ $daysLeft วัน รีบต่อ');
        break;
      case ComplianceUrgency.urgent:
        urgencyColor = const Color(0xFFEA580C);
        urgencyLabel = _l('URGENT: $daysLeft days left', 'အရေးကြီး: $daysLeft ရက်အတွင်း တိုးပါ', 'ด่วนมาก: เหลือ $daysLeft วัน');
        break;
      case ComplianceUrgency.overdue:
        urgencyColor = const Color(0xFFEF4444);
        urgencyLabel = _l('EXPIRED (${daysLeft?.abs()}d ago)', 'ရက်လွန်နေပြီ (${daysLeft?.abs()} ရက်)', 'หมดอายุแล้ว');
        break;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle Bar
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            // Header Row: Title & Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _getCategoryIcon(_selectedCategory),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _l('Visa Alerts & Rules', 'ဗီဇာအမျိုးအစား စည်းမျဉ်းသတိပေးချက်', 'แจ้งเตือนและระเบียบวีซ่า'),
                          style: AppFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _l('Compliance tracking & official laws', 'ဥပဒေလိုက်နာမှုနှင့် စည်းမျဉ်းများ', 'การปฏิบัติตามกฎหมายและเตือน'),
                          style: AppFonts.poppins(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEDF2F7)),
            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Horizontal Category Selector Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _visaChip(ThailandVisaCategory.mouWork, '🏢 MOU / Non-B', 'အလုပ်သမား'),
                          const SizedBox(width: 8),
                          _visaChip(ThailandVisaCategory.dtv, '🌴 DTV', 'Digital Nomad'),
                          const SizedBox(width: 8),
                          _visaChip(ThailandVisaCategory.education, '🎓 Non-ED', 'ပညာသင်'),
                          const SizedBox(width: 8),
                          _visaChip(ThailandVisaCategory.tourist, '🏖️ Tourist', 'ရက် ၆၀'),
                          const SizedBox(width: 8),
                          _visaChip(ThailandVisaCategory.nonO, '👨‍👩‍👧 Non-O', 'မှီခို/အငြိမ်းစား'),
                          const SizedBox(width: 8),
                          _visaChip(ThailandVisaCategory.ltr, '💎 LTR', 'ရေရှည်နေထိုင်'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Banner & Header
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  _getCategoryBadge(_selectedCategory),
                                  style: AppFonts.poppins(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getCategoryTitle(_selectedCategory),
                            style: AppFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Live Expiry Date & Countdown Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  PhosphorIconsFill.calendarCheck,
                                  size: 20,
                                  color: _visaExpiryDate != null ? urgencyColor : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _visaExpiryDate != null
                                            ? '${_l('Visa Due: ', 'ဗီဇာသက်တမ်း: ', 'หมดอายุ: ')}${dateFormat.format(_visaExpiryDate!)}'
                                            : _l('No Expiry Date Set', 'ဗီဇာသက်တမ်းရက် မသတ်မှတ်ရသေးပါ', 'ยังไม่ได้ระบุวันหมดอายุ'),
                                        style: AppFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (_visaExpiryDate != null && urgencyLabel.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: BoxDecoration(
                                                color: urgencyColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              urgencyLabel,
                                              style: AppFonts.poppins(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: urgencyColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else ...[
                                        Text(
                                          _l('Tap to track & set reminders', 'ရက်စွဲရွေးပြီး သတိပေးချက်ရယူပါ', 'แตะเพื่อตั้งวันและแจ้งเตือน'),
                                          style: AppFonts.poppins(
                                            fontSize: 11,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _pickVisaExpiryDate,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text(
                                      _visaExpiryDate != null
                                          ? _l('Change', 'ရက်ပြောင်း', 'เปลี่ยน')
                                          : _l('Set Date', 'ရက်ရွေး', 'ตั้งวัน'),
                                      style: AppFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Reminders & Test Notification Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(PhosphorIconsRegular.bellRinging, size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _l(
                                    'Expiry Reminders (30d, 14d, 3d)',
                                    'သက်တမ်းကုန် အလိုအလျောက် သတိပေးမည်',
                                    'แจ้งเตือนก่อนหมดอายุ (30, 14, 3 วัน)',
                                  ),
                                  style: AppFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                value: _visaReminderEnabled,
                                onChanged: _toggleVisaReminder,
                                activeColor: AppColors.primary,
                              ),
                            ],
                          ),
                          if (_visaReminderEnabled) ...[
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: _sendTestNotification,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(PhosphorIconsBold.bellRinging, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      _l('Send Test Notification to Phone', 'ဖုန်းသို့ စမ်းသပ်သတိပေးချက် ပို့မည်', 'ส่งการแจ้งเตือนทดสอบ'),
                                      style: AppFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category-Specific Crucial Legal Alerts
                    _buildCategoryRuleAlerts(_selectedCategory),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visaChip(ThailandVisaCategory cat, String label, String sub) {
    final isSelected = _selectedCategory == cat;
    return GestureDetector(
      onTap: () => _selectCategory(cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              sub,
              style: AppFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRuleAlerts(ThailandVisaCategory cat) {
    switch (cat) {
      case ThailandVisaCategory.mouWork:
        return Column(
          children: [
            _alertBox(
              icon: PhosphorIconsFill.warningCircle,
              color: const Color(0xFFDC2626),
              title: _l('Critical Re-Entry Permit Rule', 'Re-Entry Permit မမေ့ရန် အထူးသတိပြုပါ', 'คำเตือนสำคัญ: Re-Entry Permit'),
              desc: _l(
                'Leaving Thailand without a Re-Entry permit automatically cancels your Non-B/MOU visa and Work Permit immediately.',
                'ကြိုတင် Re-entry permit မပါဘဲ ထိုင်းနိုင်ငံပြင်ပသို့ ထွက်ခွာမိပါက သင်၏ Non-B/MOU ဗီဇာသည် အလိုအလျောက် ချက်ချင်းပျက်ပြယ်ပါမည်။',
                'หากออกนอกไทยโดยไม่มี Re-Entry วีซ่าจะถูกยกเลิกทันที',
              ),
            ),
            const SizedBox(height: 8),
            _alertBox(
              icon: PhosphorIconsFill.buildings,
              color: const Color(0xFF2563EB),
              title: _l('30-Day Employer Transfer Window', 'အလုပ်ရှင်ပြောင်းရွှေ့ခြင်း ဥပဒေ', 'แจ้งเปลี่ยนนายจ้างภายใน 30 วัน'),
              desc: _l(
                'If changing jobs, you must register your new employer at the Department of Employment within 30 days.',
                'အလုပ်ပြောင်းပါက ရက်ပေါင်း ၃၀ အတွင်း အလုပ်သစ်ထံ အလုပ်သမားဦးစီးဌာနတွင် တရားဝင်ပြောင်းရွှေ့ မှတ်ပုံတင်ရပါမည်။',
                'ต้องแจ้งนายจ้างใหม่ภายใน 30 วัน',
              ),
            ),
          ],
        );
      case ThailandVisaCategory.dtv:
        return Column(
          children: [
            _alertBox(
              icon: PhosphorIconsFill.airplaneTakeoff,
              color: const Color(0xFF059669),
              title: _l('180-Day Max Stay Per Entry', 'ရက် ၁၈၀ နေထိုင်ခွင့် ကန့်သတ်ချက်', 'พำนักได้สูงสุด 180 วัน/ครั้ง'),
              desc: _l(
                'Max 180 days per entry. You can extend once for +180 days (10,000 THB) at Immigration or exit & re-enter.',
                'တစ်ကြိမ်လျှင် ရက် ၁၈၀ သာ နေခွင့်ရှိပြီး ရက် ၁၈၀ ပြည့်ပါက နောက်ထပ် ၁၈၀ ရက် (ဘတ် ၁ သောင်းဖြင့်) ထပ်တိုးနိုင် သို့မဟုတ် နယ်စပ်ထွက်ရပါမည်။',
                'ขยายเวลาได้อีก 180 วัน (10,000 บาท) หรือเดินทางออกนอกประเทศ',
              ),
            ),
            const SizedBox(height: 8),
            _alertBox(
              icon: PhosphorIconsFill.clockCountdown,
              color: const Color(0xFFD97706),
              title: _l('90-Day Report Still Required', 'ရက် ၉၀ သတင်းပို့ရန် လိုအပ်သည်', 'รายงานตัว 90 วันยังจำเป็น'),
              desc: _l(
                'If staying continuously over 90 days on DTV without leaving Thailand, TM.47 90-day report is mandatory.',
                'DTV ဖြင့် နိုင်ငံတွင်း ရက်ပေါင်း ၉၀ ကျော် ဆက်တိုက်နေထိုင်ပါက 90-Day Report (TM.47) တင်သွင်းရန် လိုအပ်ပါသည်။',
                'หากอยู่เกิน 90 วันติดต่อกัน ต้องยื่นรายงานตัว 90 วัน',
              ),
            ),
          ],
        );
      case ThailandVisaCategory.education:
        return Column(
          children: [
            _alertBox(
              icon: PhosphorIconsFill.graduationCap,
              color: const Color(0xFF2563EB),
              title: _l('School Papers Needed 21 Days Before', 'ကျောင်းစာရွက်စာတမ်း ၂၁ ရက် ကြိုယူပါ', 'ขอเอกสารจากสถาบันก่อน 21 วัน'),
              desc: _l(
                'Obtain official attendance and school letter 21 days before your 90-day extension at Immigration.',
                'သက်တမ်းမကုန်မီ ၂၁ ရက်အလိုတွင် ကျောင်းထံမှ တရားဝင်ထောက်ခံစာရယူ၍ လ.ဝ.က တွင် သက်တမ်းတိုးပါ။',
                'ต้องยื่นหนังสือรับรองจากโรงเรียนทุก 90 วัน',
              ),
            ),
            const SizedBox(height: 8),
            _alertBox(
              icon: PhosphorIconsFill.prohibit,
              color: const Color(0xFFDC2626),
              title: _l('No Work Permitted on ED Visa', 'အလုပ်လုပ်ကိုင်ခွင့် လုံးဝမရှိပါ', 'ห้ามทำงานโดยเด็ดขาด'),
              desc: _l(
                'Working on an ED visa is strictly illegal in Thailand and punishable by immediate deportation.',
                'ပညာသင်ဗီဇာဖြင့် အလုပ်လုပ်ကိုင်ခွင့် လုံးဝမရှိပါ။ တွေ့ရှိပါက ဖမ်းဆီးပြည်နှင်ဒဏ်ပေးခံရနိုင်သည်။',
                'วีซ่านักเรียนห้ามทำงานในประเทศไทย',
              ),
            ),
          ],
        );
      case ThailandVisaCategory.tourist:
        return Column(
          children: [
            _alertBox(
              icon: PhosphorIconsFill.compass,
              color: const Color(0xFF0284C7),
              title: _l('60-Day Stay + 30-Day Extension', 'ရက် ၆၀ နေထိုင်ခွင့် + ရက် ၃၀ တိုးခွင့်', 'พำนัก 60 วัน + ขยายได้ 30 วัน'),
              desc: _l(
                'Can extend only ONCE for +30 days (1,900 THB) at any Thai Immigration office.',
                'လ.ဝ.က ရုံးတွင် ၁ ကြိမ်သာ ရက် ၃၀ (၁,၉၀၀ ဘတ်) ထပ်မံတိုးနိုင်ပါသည်။',
                'ขยายได้ 1 ครั้ง 30 วัน (1,900 บาท)',
              ),
            ),
            const SizedBox(height: 8),
            _alertBox(
              icon: PhosphorIconsFill.warning,
              color: const Color(0xFFDC2626),
              title: _l('Overstay Fine 500 THB/Day', 'Overstay ဒဏ်ကြေး တစ်ရက် ၅၀၀ ဘတ်', 'ค่าปรับอยู่เกินวันละ 500 บาท'),
              desc: _l(
                'Overstay fine is 500 THB/day (up to 20,000 THB). Overstaying > 90 days leads to 1 to 5 years entry ban.',
                'Overstay တစ်ရက်လျှင် ၅၀၀ ဘတ် (အများဆုံး ၂၀,၀၀၀ ဘတ်) ကျသင့်ပြီး ရက် ၉၀ ကျော်လွန်ပါက ၁ နှစ်မှ ၅ နှစ်အထိ နိုင်ငံတွင်း ဝင်ရောက်ခွင့် ပိတ်ပင်ခံရမည်။',
                'อยู่เกิน 90 วันถูกแบนห้ามเข้าประเทศ 1-5 ปี',
              ),
            ),
          ],
        );
      case ThailandVisaCategory.nonO:
        return Column(
          children: [
            _alertBox(
              icon: PhosphorIconsFill.bank,
              color: const Color(0xFF7C3AED),
              title: _l('Bank Seasoning (2-3 Months Prior)', 'ဘဏ်ငွေ ၂-၃ လ ကြိုတင်ထည့်ထားပါ', 'เงินฝากในบัญชีล่วงหน้า 2-3 เดือน'),
              desc: _l(
                'Deposit 400,000 THB (Spouse) or 800,000 THB (Retirement) into Thai bank account 2-3 months before renewal.',
                'သက်တမ်းမတိုးမီ ၂-၃ လ ကြိုတင်၍ ထိုင်းဘဏ်စာရင်းတွင် ဘတ် ၄ သိန်း (အိမ်ထောင်ဖက်) သို့မဟုတ် ဘတ် ၈ သိန်း (အငြိမ်းစား) ထည့်သွင်းထားရပါမည်။',
                'ต้องมีเงินฝาก 400,000 หรือ 800,000 บาท ตามเกณฑ์',
              ),
            ),
          ],
        );
      case ThailandVisaCategory.ltr:
        return Column(
          children: [
            _alertBox(
              icon: PhosphorIconsFill.shieldCheck,
              color: const Color(0xFF059669),
              title: _l('1-Year Reporting Privilege', '၁ နှစ်လျှင် ၁ ကြိမ်သာ သတင်းပို့ရန်လို', 'รายงานตัวปีละ 1 ครั้ง'),
              desc: _l(
                'LTR visa holders report once a year instead of every 90 days, with fast-track immigration at international airports.',
                'LTR ကိုင်ဆောင်သူများသည် ရက် ၉၀ တိုင်း သတင်းပို့စရာမလိုဘဲ ၁ နှစ်ပြည့်မှသာ သတင်းပို့ရပြီး လေဆိပ်တွင် Fast-Track အခွင့်အရေး ရရှိသည်။',
                'สิทธิพิเศษรายงานตัว 1 ปีต่อครั้ง พร้อม Fast-track สนามบิน',
              ),
            ),
          ],
        );
    }
  }

  Widget _alertBox({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: AppFonts.poppins(
                    fontSize: 11,
                    height: 1.35,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
