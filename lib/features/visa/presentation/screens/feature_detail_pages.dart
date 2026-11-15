import '../../data/services/thailand_alert_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/presentation/widgets/gradient_icon.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/haptic_splash_factory.dart';
import '../../data/models/visa_dto.dart';
import '../widgets/tm47_checker_sheet.dart';
import 'visa_detail_page.dart';

class _Tx {
  final String en;
  final String mm;
  final String th;
  const _Tx({required this.en, required this.mm, required this.th});

  String get s => LocaleController.instance.localized(en: en, mm: mm, th: th);
}

const _kSlate900 = Color(0xFF1E293B);
const _kSlate600 = Color(0xFF475569);
const _kSlate500 = Color(0xFF64748B);
const _kBorder = Color(0xFFEDF2F7);

String _money(double v) => NumberFormat('#,##0.00').format(v);

Widget _sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          width: 3.5,
          height: 16,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradientVertical,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        GradientText(
          title,
          style: AppFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Future<void> _openExternal(String url) async {
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

Future<void> _callPhone(String number) async {
  AppHaptics.buttonTap();
  final uri = Uri.parse('tel:$number');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Shared Base Scaffold for Feature Detail Pages
class _FeatureDetailScaffold extends StatelessWidget {
  final String title;
  final String? badgeText;
  final Widget body;

  const _FeatureDetailScaffold({
    required this.title,
    this.badgeText,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: Column(
          children: [
            // Professional Clean Top App Bar (Single Row: Back Button + Title)
            Container(
              padding: EdgeInsets.fromLTRB(14, top + 6, 16, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
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
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        PhosphorIconsRegular.arrowLeft,
                        color: Color(0xFF0F172A),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.poppins(
                        color: const Color(0xFF0F172A),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 1. 90-Day (TM.47) Detail & Checker Page
// ============================================================================

class Tm47DetailPage extends StatefulWidget {
  final VoidCallback? onUpdated;

  const Tm47DetailPage({super.key, this.onUpdated});

  @override
  State<Tm47DetailPage> createState() => _Tm47DetailPageState();
}

class _Tm47DetailPageState extends State<Tm47DetailPage> {
  DateTime? _selectedDate;
  int _entryType = 0;
  bool _reminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
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

  Future<void> _toggleReminder(bool val) async {
    AppHaptics.buttonTap();
    setState(() => _reminderEnabled = val);
    await ThailandAlertService.instance.setTm47ReminderEnabled(val, baseDate: _selectedDate);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            val
                ? const _Tx(
                    en: '90-Day auto-reminders activated (15d, 7d, Due, Grace)!',
                    mm: '90-Day အလိုအလျောက် သတိပေးချက်များ စတင်ဖွင့်လှစ်ပြီးပါပြီ (၁၅ ရက်၊ ၇ ရက်၊ နောက်ဆုံးရက်၊ သက်ညှာခွင့်)။',
                    th: 'เปิดระบบแจ้งเตือน 90 วันอัตโนมัติแล้ว!',
                  ).s
                : const _Tx(
                    en: '90-Day reminders turned off.',
                    mm: '90-Day သတိပေးချက်များ ပိတ်ပြီးပါပြီ။',
                    th: 'ปิดการแจ้งเตือนแล้ว',
                  ).s,
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
      body: 'သင်၏ ဖုန်းတွင် 90-Day သတိပေးချက်များ အောင်မြင်စွာ အလုပ်လုပ်နေပါပြီ။ သတ်မှတ်ရက်မတိုင်မီ တိကျစွာ သတိပေးသွားမည် ဖြစ်ပါသည်။',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            const _Tx(
              en: 'Test notification sent! Check notification bar.',
              mm: 'စမ်းသပ်သတိပေးချက် ပို့ပြီးပါပြီ။ ဖုန်း၏ Notification bar တွင် ကြည့်ရှုပါ။',
              th: 'ส่งการแจ้งเตือนทดสอบแล้ว!',
            ).s,
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_selectedDate != null) {
      await Tm47Service.save(_selectedDate!, _entryType);
      widget.onUpdated?.call();
    }
  }

  Future<void> _clear() async {
    AppHaptics.buttonTap();
    await Tm47Service.clear();
    if (mounted) {
      setState(() => _selectedDate = null);
      widget.onUpdated?.call();
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
              onSurface: _kSlate900,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      _save();
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
          statusTitle = const _Tx(
            en: 'Safe & Valid',
            mm: 'အချိန်မီပါသေးသည်',
            th: 'ยังอยู่ในกำหนดปกติ',
          ).s;
          statusSubtitle = '${const _Tx(
            en: 'Days remaining: ',
            mm: 'ကျန်ရှိသောရက်: ',
            th: 'จำนวนวันที่เหลือ: ',
          ).s}${calc.daysRemaining} ${const _Tx(en: 'days', mm: 'ရက်', th: 'วัน').s}';
          break;
        case Tm47Status.open:
          statusColor = const Color(0xFFF59E0B);
          statusIcon = PhosphorIconsFill.bellRinging;
          statusTitle = const _Tx(
            en: 'Window Open - Report Now',
            mm: 'ယခု တင်သွင်းနိုင်ပါပြီ',
            th: 'เปิดให้รายงานตัวแล้ว',
          ).s;
          statusSubtitle = calc.daysRemaining == 0
              ? const _Tx(
                  en: 'Today is your deadline day!',
                  mm: 'ယနေ့သည် သတ်မှတ်ရက် နောက်ဆုံးနေ့ ဖြစ်ပါသည်!',
                  th: 'วันนี้คือวันครบกำหนด!',
                ).s
              : '${const _Tx(
                  en: 'Days until due date: ',
                  mm: 'သတ်မှတ်ရက်ပြည့်ရန်: ',
                  th: 'เหลือก่อนครบกำหนด: ',
                ).s}${calc.daysRemaining} ${const _Tx(en: 'days', mm: 'ရက်', th: 'วัน').s}';
          break;
        case Tm47Status.grace:
          statusColor = const Color(0xFFEA580C);
          statusIcon = PhosphorIconsFill.warning;
          statusTitle = const _Tx(
            en: 'Grace Period (7 Days)',
            mm: '၇ ရက် သက်ညှာခွင့်ကာလအတွင်း',
            th: 'อยู่ในช่วงผ่อนผัน 7 วัน',
          ).s;
          statusSubtitle = '${const _Tx(
            en: 'Due date passed ',
            mm: 'သတ်မှတ်ရက်ကျော်လွန်သည်မှာ ',
            th: 'เกินกำหนดมาแล้ว ',
          ).s}${-calc.daysRemaining} ${const _Tx(en: 'days ago (Report immediately)', mm: 'ရက် ရှိပါပြီ (ချက်ချင်းတင်ပါ)', th: 'วัน (รีบรายงานตัวด่วน)').s}';
          break;
        case Tm47Status.overdue:
          statusColor = const Color(0xFFEF4444);
          statusIcon = PhosphorIconsFill.xCircle;
          statusTitle = const _Tx(
            en: 'Overdue - 2,000 THB Fine',
            mm: 'ရက်လွန်ဒဏ်ကြေး ကျသင့်ပါပြီ',
            th: 'เกินกำหนด - มีค่าปรับ 2,000 บาท',
          ).s;
          statusSubtitle = '${const _Tx(
            en: 'Overdue by ',
            mm: 'ရက်လွန်သွားသည်မှာ ',
            th: 'เกินกำหนดมาแล้ว ',
          ).s}${-calc.daysRemaining} ${const _Tx(en: 'days. Overstay fine applies.', mm: 'ရက် ဖြစ်ပါသည် (ဒဏ်ကြေး ပေးဆောင်ရမည်)။', th: 'วัน ต้องชำระค่าปรับ').s}';
          break;
      }
    }

    return _FeatureDetailScaffold(
      title: const _Tx(
        en: '90-Day Report (TM.47) Checker',
        mm: 'ရက် ၉၀ (TM.47) စစ်ဆေးတွက်ချက်စက်',
        th: 'ตรวจกำหนดรายงานตัว 90 วัน (ตม.47)',
      ).s,
      badgeText: 'Immigration Bureau 2026',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode Switcher
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _tabButton(
                    0,
                    const _Tx(
                      en: 'Last Report Date',
                      mm: 'နောက်ဆုံး တိုင်ကြားသည့်ရက်',
                      th: 'วันรายงานตัวล่าสุด',
                    ).s,
                  ),
                ),
                Expanded(
                  child: _tabButton(
                    1,
                    const _Tx(
                      en: 'Arrival Date',
                      mm: 'ထိုင်းသို့ ဝင်ရောက်သည့်ရက်',
                      th: 'วันเดินทางเข้าไทย',
                    ).s,
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
                  color: hasDate
                      ? _kBorder
                      : AppColors.primary.withValues(alpha: 0.35),
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
                              ? const _Tx(
                                  en: 'Previous TM.47 Receipt Date',
                                  mm: 'ယခင် တိုင်ကြားခဲ့သော ပြေစာရက်စွဲ',
                                  th: 'วันที่ตามใบรับ ตม.47 ล่าสุด',
                                ).s
                              : const _Tx(
                                  en: 'Passport Entry Stamp Date',
                                  mm: 'ပတ်စပို့ ဝင်ရောက်တံဆိပ်တုံး ရက်စွဲ',
                                  th: 'วันที่ประทับตราเข้าเมืองล่าสุด',
                                ).s,
                          style: AppFonts.poppins(
                            fontSize: 11.5,
                            color: _kSlate500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasDate
                              ? dateFormat.format(_selectedDate!)
                              : const _Tx(
                                  en: 'Select date to calculate',
                                  mm: 'ရက်စွဲ မသတ်မှတ်ရသေးပါ (ရွေးပါ)',
                                  th: 'ยังไม่ได้ระบุ (แตะเพื่อเลือก)',
                                ).s,
                          style: AppFonts.poppins(
                            fontSize: 14.5,
                            fontWeight:
                                hasDate ? FontWeight.w700 : FontWeight.w600,
                            color: hasDate ? _kSlate900 : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7.5,
                      ),
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
                            ? const _Tx(
                                en: 'Change',
                                mm: 'ရက်ပြောင်း',
                                th: 'เปลี่ยนวัน',
                              ).s
                            : const _Tx(
                                en: 'Pick Date',
                                mm: 'ရက်ရွေးမည်',
                                th: 'เลือกวันที่',
                              ).s,
                        style: AppFonts.poppins(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // If date is selected, show full results
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
                            color: _kSlate600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _clear,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        const _Tx(en: 'Reset', mm: 'ရှင်းမည်', th: 'รีเซ็ต').s,
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

            // Date breakdown table
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                children: [
                  _dateRow(
                    title: const _Tx(
                      en: 'Exact Due Date (Day 90)',
                      mm: 'သတ်မှတ်ရက်ပြည့်မြောက်မည့်နေ့ (ရက် ၉၀)',
                      th: 'วันครบกำหนดตรง (วันที่ 90)',
                    ).s,
                    dateStr: dateFormat.format(calc.dueDate),
                    isHighlight: true,
                  ),
                  const Divider(height: 20, thickness: 0.6, color: Color(0xFFF1F5F9)),
                  _dateRow(
                    title: const _Tx(
                      en: 'Earliest Submission (15 Days Before)',
                      mm: 'စတင်တင်သွင်းနိုင်သည့်ရက် (၁၅ ရက် ကြိုတင်)',
                      th: 'เริ่มยื่นล่วงหน้าได้ (15 วันก่อนกำหนด)',
                    ).s,
                    dateStr: dateFormat.format(calc.windowStart),
                  ),
                  const Divider(height: 20, thickness: 0.6, color: Color(0xFFF1F5F9)),
                  _dateRow(
                    title: const _Tx(
                      en: 'Latest Allowed Date (7 Days Grace)',
                      mm: 'နောက်ဆုံးခွင့်ပြုသည့်ရက် (၇ ရက် သက်ညှာခွင့်)',
                      th: 'วันสุดท้ายที่ผ่อนผัน (7 วันหลังกำหนด)',
                    ).s,
                    dateStr: dateFormat.format(calc.windowEnd),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 90-Day Auto Reminders Card
          _buildReminderCard(calc),
          const SizedBox(height: 16),

          // Rules Guide
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(PhosphorIconsFill.info, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      const _Tx(
                        en: 'Official 90-Day Regulations',
                        mm: 'တရားဝင် ရက် ၉၀ စည်းမျဉ်းများ',
                        th: 'ระเบียบการรายงานตัว 90 วัน',
                      ).s,
                      style: AppFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _kSlate900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _bullet(
                  const _Tx(
                    en: 'Foreigners staying over 90 days on non-immigrant visas must notify immigration of their residence every 90 days.',
                    mm: 'ထိုင်းနိုင်ငံတွင် ယာယီဗီဇာ (Non-B, Non-O, Non-ED, LTR စသည်) ဖြင့် ရက် ၉၀ ကျော် နေထိုင်သူတိုင်း ရက် ၉၀ လျှင် တစ်ကြိမ် နေရပ်လိပ်စာ တိုင်ကြားရမည်။',
                    th: 'ชาวต่างชาติที่พำนักเกิน 90 วันด้วยวีซ่าชั่วคราว ต้องรายงานที่พักทุก 90 วัน',
                  ).s,
                ),
                _bullet(
                  const _Tx(
                    en: 'Online reporting can be filed 15 days up to 7 days before the due date at tm47.immigration.go.th.',
                    mm: 'အွန်လိုင်းမှ တင်ပါက သတ်မှတ်ရက် မတိုင်မီ ၁၅ ရက်မှ ၇ ရက် ကြိုတင်၍ tm47.immigration.go.th တွင် တင်သွင်းနိုင်သည်။',
                    th: 'รายงานตัวออนไลน์ได้ล่วงหน้า 15 ถึง 7 วันก่อนครบกำหนดที่ tm47.immigration.go.th',
                  ).s,
                ),
                _bullet(
                  const _Tx(
                    en: 'Leaving Thailand on a valid re-entry permit resets your 90-day count to 1 on the day you re-enter Thailand.',
                    mm: 'Re-entry permit ဖြင့် ထိုင်းနိုင်ငံပြင်ပသို့ ထွက်ခွာပါက ထိုင်းနိုင်ငံသို့ ပြန်လည်ဝင်ရောက်သည့်ရက်မှစ၍ ရက် ၉၀ ရေတွက်မှု ပြန်လည်စတင်ပါသည်။',
                    th: 'หากเดินทางออกนอกประเทศด้วย Re-entry permit ให้นับ 90 วันใหม่ตั้งแต่วันที่กลับเข้าไทย',
                  ).s,
                ),
                _bullet(
                  const _Tx(
                    en: 'Late report penalty is 2,000 THB; if arrested without filing, penalty is up to 5,000 THB + 200 THB per day.',
                    mm: 'ရက်လွန်ဒဏ်ကြေးမှာ ၂,၀၀၀ ဘတ် ဖြစ်ပြီး ဖမ်းဆီးခံရပါက ၅,၀၀၀ ဘတ်အထိနှင့် တစ်ရက်လျှင် ၂၀၀ ဘတ် ထပ်ဆောင်း ဒဏ်တပ်ခံရနိုင်သည်။',
                    th: 'ค่าปรับรายงานตัวช้า 2,000 บาท หากถูกจับกุมปรับสูงสุด 5,000 บาท + วันละ 200 บาท',
                  ).s,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action button
          PrimaryGradientButton(
            onPressed: () => _openExternal('https://tm47.immigration.go.th/'),
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsBold.globe, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  const _Tx(
                    en: 'Open TM.47 Online System',
                    mm: 'တရားဝင် TM.47 Online စနစ် ဖွင့်မည်',
                    th: 'เปิดระบบรายงานตัว 90 วันออนไลน์',
                  ).s,
                  style: AppFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Tm47Calculation? calc) {
    return Container(
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
                      const _Tx(
                        en: '90-Day Auto Reminders',
                        mm: '90-Day အလိုအလျောက် သတိပေးချက်များ',
                        th: 'ระบบแจ้งเตือน 90 วันอัตโนมัติ',
                      ).s,
                      style: AppFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _kSlate900,
                      ),
                    ),
                    Text(
                      const _Tx(
                        en: 'Never miss deadline (15d, 7d, Due, Grace)',
                        mm: 'ရက် ၁၅၊ ၇၊ နောက်ဆုံးရက်နှင့် သက်ညှာခွင့်များတွင် သတိပေးမည်',
                        th: 'แจ้งเตือน 15 วัน 7 วัน ครบกำหนด และผ่อนผัน',
                      ).s,
                      style: AppFonts.poppins(
                        fontSize: 11,
                        color: _kSlate500,
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
                  _milestoneRow('15d Before', const _Tx(en: 'Window opens for filing', mm: 'စတင်တင်သွင်းခွင့်ရသည့်ရက်', th: 'เปิดยื่นรายงานตัว').s, const Color(0xFF10B981)),
                  const SizedBox(height: 8),
                  _milestoneRow('7d Warning', const _Tx(en: 'Urgent reminder before due', mm: 'ဒဏ်ကြေးမကျစေရန် အရေးကြီးသတိပေးချက်', th: 'เตือนด่วนก่อนครบกำหนด').s, const Color(0xFFF59E0B)),
                  const SizedBox(height: 8),
                  _milestoneRow('Due Date', const _Tx(en: 'Day 90 final deadline', mm: 'ရက် ၉၀ နောက်ဆုံးထားတင်ရမည့်ရက်', th: 'วันครบกำหนด 90 วัน').s, const Color(0xFFEA580C)),
                  const SizedBox(height: 8),
                  _milestoneRow('Grace Period', const _Tx(en: 'Final 7-day in-person window', mm: 'လ.ဝ.က လူကိုယ်တိုင်သွားရန် ၇ ရက် သက်ညှာခွင့်', th: 'ผ่อนผัน 7 วัน ยื่นด้วยตนเอง').s, const Color(0xFFEF4444)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _sendTestNotification,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      PhosphorIconsBold.bellRinging,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      const _Tx(
                        en: 'Send Test Notification Now',
                        mm: 'စမ်းသပ်သတိပေးချက် ယခုပို့ကြည့်မည်',
                        th: 'ส่งการแจ้งเตือนทดสอบตอนนี้',
                      ).s,
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
    );
  }

  Widget _milestoneRow(String tag, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            tag,
            style: AppFonts.poppins(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _kSlate600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabButton(int index, String label) {
    final isSelected = _entryType == index;
    return GestureDetector(
      onTap: () {
        AppHaptics.buttonTap();
        setState(() => _entryType = index);
        _save();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? GradientText(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
      ),
    );
  }

  Widget _dateRow({required String title, required String dateStr, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppFonts.poppins(
              fontSize: 12.5,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
              color: isHighlight ? _kSlate900 : _kSlate600,
            ),
          ),
        ),
        if (isHighlight)
          GradientText(
            dateStr,
            style: AppFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          )
        else
          Text(
            dateStr,
            style: AppFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kSlate900,
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
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF334155),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. OT Calculator Detail Page
// ============================================================================

class OtCalculatorDetailPage extends StatefulWidget {
  const OtCalculatorDetailPage({super.key});

  @override
  State<OtCalculatorDetailPage> createState() => _OtCalculatorDetailPageState();
}

class _OtCalculatorDetailPageState extends State<OtCalculatorDetailPage> {
  int _payType = 0; // 0 monthly, 1 daily
  int _dayType = 0; // 0 normal, 1 holiday
  final _wage = TextEditingController(text: '15000');
  final _normalHours = TextEditingController(text: '8');
  final _shiftHours = TextEditingController(text: '8');
  final _otHours = TextEditingController(text: '2');

  @override
  void dispose() {
    _wage.dispose();
    _normalHours.dispose();
    _shiftHours.dispose();
    _otHours.dispose();
    super.dispose();
  }

  double _v(TextEditingController c) => double.tryParse(c.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final monthly = _payType == 0;
    final holiday = _dayType == 1;
    final wage = _v(_wage);
    final perDay = _v(_normalHours);
    final ot = _v(_otHours);
    final shift = _v(_shiftHours);

    final dailyWage = monthly ? wage / 30 : wage;
    final hourly = perDay > 0 ? dailyWage / perDay : 0.0;
    final holidayPay = holiday ? shift * hourly * (monthly ? 1 : 2) : 0.0;
    final otPay = ot * hourly * (holiday ? 3 : 1.5);
    final total = holidayPay + otPay;

    return _FeatureDetailScaffold(
      title: const _Tx(
        en: 'Overtime (OT) Pay Calculator',
        mm: 'အချိန်ပိုလုပ်ခ (OT) တွက်စက်',
        th: 'เครื่องคำนวณค่าล่วงเวลา (โอที)',
      ).s,
      badgeText: 'Labour Protection Act',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(const _Tx(en: 'Pay Frequency', mm: 'လစာ အမျိုးအစား', th: 'ประเภทค่าจ้าง').s),
                _segmented(
                  labels: [
                    const _Tx(en: 'Monthly Salary', mm: 'လစဉ်လစာ', th: 'เงินเดือน').s,
                    const _Tx(en: 'Daily Wage', mm: 'နေ့စားလုပ်ခ', th: 'ค่าจ้างรายวัน').s,
                  ],
                  selected: _payType,
                  onChanged: (i) => setState(() => _payType = i),
                ),
                _label(const _Tx(en: 'Wage Amount', mm: 'လုပ်ခ ပမာဏ', th: 'จำนวนค่าจ้าง').s),
                _inputField(_wage, suffix: '฿'),
                _label(const _Tx(en: 'Normal Work Hours/Day', mm: 'တစ်ရက် ပုံမှန်အလုပ်ချိန် (နာရီ)', th: 'ชม.ทำงานปกติต่อวัน').s),
                _inputField(_normalHours),
                _label(const _Tx(en: 'Day Type', mm: 'ရက် အမျိုးအစား', th: 'ประเภทวัน').s),
                _segmented(
                  labels: [
                    const _Tx(en: 'Normal Work Day', mm: 'ပုံမှန်အလုပ်ရက်', th: 'วันทำงานปกติ').s,
                    const _Tx(en: 'Holiday / Rest Day', mm: 'အားလပ်ရက် / နားရက်', th: 'วันหยุด').s,
                  ],
                  selected: _dayType,
                  onChanged: (i) => setState(() => _dayType = i),
                ),
                if (holiday) ...[
                  _label(const _Tx(en: 'Hours worked in normal shift', mm: 'ပုံမှန်အလုပ်ချိန်အတွင်း လုပ်သော နာရီ', th: 'ชม.กะปกติวันหยุด').s),
                  _inputField(_shiftHours),
                ],
                _label(const _Tx(en: 'Overtime Hours (OT)', mm: 'OT နာရီ', th: 'จำนวนชั่วโมงโอที').s),
                _inputField(_otHours),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Executive Result Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFF1F5F9),
                width: 1,
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
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: const GradientIcon(
                        icon: PhosphorIconsFill.calculator,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GradientText(
                      'တွက်ချက်မှု အသေးစိတ်',
                      style: AppFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _resRow('တစ်နာရီ ပုံမှန်လုပ်ခ', '฿ ${_money(hourly)}'),
                if (holiday)
                  _resRow(
                    'အားလပ်ရက် ပုံမှန်အလုပ်ဆင်းခ (${monthly ? "၁ ဆ" : "၂ ဆ"})',
                    '฿ ${_money(holidayPay)}',
                  ),
                _resRow(
                  'အချိန်ပို OT လုပ်ခ (${holiday ? "၃ ဆ" : "၁.၅ ဆ"})',
                  '฿ ${_money(otPay)}',
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ရသင့်သော စုစုပေါင်းထပ်ဆောင်းငွေ',
                        style: AppFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      GradientText(
                        '฿ ${_money(total)}',
                        style: AppFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legal reference note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'ထိုင်းအလုပ်သမားကာကွယ်ရေးဥပဒေအရ ပုံမှန်ရက် OT ကို အနည်းဆုံး ၁.၅ ဆ၊ အားလပ်ရက်အတွင်း ပုံမှန်အလုပ်ချိန်ကို ၁-၂ ဆ၊ အားလပ်ရက် OT ကို ၃ ဆ ပေးဆောင်ရမည်။ လစဉ်လစာကို ရက် ၃၀ ဖြင့် စား၍ တစ်ရက်လုပ်ခကို တွက်ချက်ပါသည်။',
              style: AppFonts.poppins(fontSize: 11.5, color: _kSlate600, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: AppFonts.poppins(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController c, {String? suffix}) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) => setState(() {}),
      style: AppFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: _kSlate900),
      decoration: InputDecoration(
        isDense: true,
        suffixText: suffix,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _segmented({required List<String> labels, required int selected, required ValueChanged<int> onChanged}) {
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: i == selected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: i == selected
                      ? GradientText(
                          labels[i],
                          style: AppFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Text(
                          labels[i],
                          style: AppFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resRow(String key, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: AppFonts.poppins(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
          Text(val, style: AppFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. Severance Pay Detail Page (Section 118)
// ============================================================================

class SeveranceDetailPage extends StatefulWidget {
  const SeveranceDetailPage({super.key});

  @override
  State<SeveranceDetailPage> createState() => _SeveranceDetailPageState();
}

class _SeveranceDetailPageState extends State<SeveranceDetailPage> {
  int _payType = 0;
  final _wage = TextEditingController(text: '15000');
  final _years = TextEditingController(text: '2');
  final _months = TextEditingController(text: '0');

  @override
  void dispose() {
    _wage.dispose();
    _years.dispose();
    _months.dispose();
    super.dispose();
  }

  double _v(TextEditingController c) => double.tryParse(c.text) ?? 0;

  int _entitlementDays(double serviceDays) {
    if (serviceDays < 120) return 0;
    if (serviceDays < 365) return 30;
    if (serviceDays < 365 * 3) return 90;
    if (serviceDays < 365 * 6) return 180;
    if (serviceDays < 365 * 10) return 240;
    if (serviceDays < 365 * 20) return 300;
    return 400;
  }

  @override
  Widget build(BuildContext context) {
    final monthly = _payType == 0;
    final wage = _v(_wage);
    final serviceDays = _v(_years).floor() * 365.0 + _v(_months).floor() * 30.0;
    final days = _entitlementDays(serviceDays);
    final dailyWage = monthly ? wage / 30 : wage;
    final amount = days * dailyWage;

    return _FeatureDetailScaffold(
      title: const _Tx(
        en: 'Severance Pay (Section 118)',
        mm: 'အလုပ်ထုတ်နစ်နာကြေး (ပုဒ်မ ၁၁၈)',
        th: 'ค่าชดเชยการเลิกจ้าง (มาตรา 118)',
      ).s,
      badgeText: 'Section 118 Legal Chart',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('လစာ အမျိုးအစား'),
                _segmented(
                  labels: ['လစဉ်လစာ', 'နေ့စားလုပ်ခ'],
                  selected: _payType,
                  onChanged: (i) => setState(() => _payType = i),
                ),
                _label('နောက်ဆုံးရရှိသော လုပ်ခ (Wage)'),
                _inputField(_wage, suffix: '฿'),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('လုပ်သက် (နှစ်)'),
                          _inputField(_years),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('လ'),
                          _inputField(_months),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Executive Result Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFF1F5F9),
                width: 1,
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
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: const GradientIcon(
                        icon: PhosphorIconsFill.money,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GradientText(
                      'တွက်ချက်မှု အကျဉ်းချုပ်',
                      style: AppFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _resRow('ဥပဒေအရ ရပိုင်ခွင့်', '$days ရက်စာ လုပ်ခ'),
                _resRow('တစ်ရက် ပျမ်းမျှလုပ်ခ', '฿ ${_money(dailyWage)}'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ရရှိမည့် ခန့်မှန်းနစ်နာကြေး',
                        style: AppFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      GradientText(
                        '฿ ${_money(amount)}',
                        style: AppFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Statutory Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ဥပဒေအရ သတ်မှတ်ထားသော နစ်နာကြေး ဇယား',
                  style: AppFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: _kSlate900),
                ),
                const SizedBox(height: 10),
                _tableRow('၁၂၀ ရက် မှ ၁ နှစ်အောက်', 'ရက် ၃၀ စာ လုပ်ခ'),
                _tableRow('၁ နှစ် မှ ၃ နှစ်အောက်', 'ရက် ၉၀ စာ လုပ်ခ'),
                _tableRow('၃ နှစ် မှ ၆ နှစ်အောက်', '၁၈၀ ရက်စာ လုပ်ခ'),
                _tableRow('၆ နှစ် မှ ၁၀ နှစ်အောက်', '၂၄၀ ရက်စာ လုပ်ခ'),
                _tableRow('၁၀ နှစ် မှ ၂၀ နှစ်အောက်', '၃၀၀ ရက်စာ လုပ်ခ'),
                _tableRow('၂၀ နှစ်နှင့် အထက်', '၄၀၀ ရက်စာ လုပ်ခ'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: AppFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
      ),
    );
  }

  Widget _inputField(TextEditingController c, {String? suffix}) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) => setState(() {}),
      style: AppFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: _kSlate900),
      decoration: InputDecoration(
        isDense: true,
        suffixText: suffix,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _segmented({required List<String> labels, required int selected, required ValueChanged<int> onChanged}) {
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: i == selected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: i == selected
                      ? GradientText(
                          labels[i],
                          style: AppFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Text(
                          labels[i],
                          style: AppFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resRow(String key, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: AppFonts.poppins(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
          Text(val, style: AppFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _tableRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: AppFonts.poppins(fontSize: 12, color: const Color(0xFF475569))),
          GradientText(v, style: AppFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. Labor Rights Detail Page
// ============================================================================

class LaborRightsDetailPage extends StatelessWidget {
  const LaborRightsDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _FeatureDetailScaffold(
      title: 'အလုပ်သမား အခွင့်အရေးနှင့် ခွင့်ရက်များ',
      badgeText: 'Labour Protection Rights',
      body: Column(
        children: [
          _card(
            icon: PhosphorIconsFill.clock,
            title: 'အလုပ်ချိန်နှင့် နားရက် စည်းကမ်း',
            desc: '• ပုံမှန်အလုပ်ချိန်သည် တစ်ရက် ၈ နာရီ၊ တစ်ပတ်လျှင် ၄၈ နာရီထက် မပိုရပါ။\n• တစ်ပတ်လျှင် အနည်းဆုံး ၁ ရက် မဖြစ်မနေ အနားပေးရမည်။\n• အလုပ်ချိန်အတွင်း ၅ နာရီဆက်တိုက် လုပ်ကိုင်ပြီးပါက အနည်းဆုံး ၁ နာရီ နားချိန် ပေးရမည်။',
          ),
          _card(
            icon: PhosphorIconsFill.coin,
            title: 'အနိမ့်ဆုံးလုပ်ခ (Minimum Wage)',
            desc: '• ထိုင်းနိုင်ငံ ပြည်နယ်အလိုက် တစ်ရက် အနိမ့်ဆုံးလုပ်ခသည် ၃၃၇ ဘတ် မှ ၄၀၀ ဘတ် ဝန်းကျင် ဖြစ်ပါသည်။\n• အလုပ်ရှင်သည် သတ်မှတ်နှုန်းထားထက် လျှော့ချပေးခွင့် မရှိပါ။',
          ),
          _card(
            icon: PhosphorIconsFill.firstAid,
            title: 'ခွင့်ရက်ဆိုင်ရာ အခွင့်အရေးများ',
            desc: '• ဆေးခွင့် (Sick Leave) - တစ်နှစ်လျှင် ရက် ၃၀ အထိ လစာအပြည့် ရရှိခွင့်ရှိသည်။ (၃ ရက်နှင့်အထက် ခွင့်ယူပါက ဆရာဝန်ထောက်ခံစာ လိုအပ်နိုင်သည်)\n• နှစ်ပတ်လည်ခွင့် (Annual Leave) - လုပ်သက် ၁ နှစ်ပြည့်ပါက အနည်းဆုံး ၆ ရက် ရရှိရမည်။\n• သားဖွားခွင့် (Maternity Leave) - ရက်ပေါင်း ၉၈ ရက်အထိ ခွင့်ယူနိုင်ပြီး ၄၅ ရက်အတွက် လစာ အပြည့်ရရှိမည်။',
          ),
          _card(
            icon: PhosphorIconsFill.shieldWarning,
            title: 'ပတ်စပို့နှင့် အလုပ်ပါမစ် သိမ်းဆည်းမှု ကာကွယ်ရေး',
            desc: '• အလုပ်ရှင်သည် အလုပ်သမား၏ ပတ်စပို့နှင့် အလုပ်ပါမစ် မူရင်းများကို မတရားသိမ်းဆည်းထားခွင့် ဥပဒေအရ လုံးဝမရှိပါ။\n• ချိုးဖောက်ခံရပါက အလုပ်သမားဝန်ကြီးဌာန ဖုန်း ၁၅၀၆ သို့ အခမဲ့ တိုင်ကြားနိုင်ပါသည်။',
          ),
        ],
      ),
    );
  }

  Widget _card({required IconData icon, required String title, required String desc}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: GradientIcon(icon: icon, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GradientText(
                  title,
                  style: AppFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            style: AppFonts.poppins(fontSize: 12, color: const Color(0xFF475569), height: 1.55),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. Social Security (SSO) Detail Page
// ============================================================================

class SsoDetailPage extends StatelessWidget {
  const SsoDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _FeatureDetailScaffold(
      title: 'လူမှုဖူလုံရေး မတ်တြာ ၃၃ (SSO)',
      badgeText: 'Social Security Office',
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const GradientIcon(
                    icon: PhosphorIconsFill.hospital,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GradientText(
                        'မတ်တြာ ၃၃ အလုပ်သမား အကျိုးခံစားခွင့်',
                        style: AppFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'လစဉ် လစာ၏ ၅% ထည့်ဝင်ပြီး အလုပ်ရှင်ကလည်း ၅% ထည့်ဝင်ပေးပါသည်။',
                        style: AppFonts.poppins(
                          color: const Color(0xFF64748B),
                          fontSize: 11.5,
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
          _item('အခမဲ့ ဆေးကုသခွင့်', 'ရွေးချယ်ထားသော ဆေးရုံတွင် ပြင်ပလူနာ၊ အတွင်းလူနာ ဆေးကုသမှု ကုန်ကျစရိတ်အားလုံး အခမဲ့ ခံစားခွင့်ရှိသည်။'),
          _item('သားဖွားစရိတ် ထောက်ပံ့ငွေ', 'သားဖွားစရိတ် အထောက်အပံ့ ၁၅,၀၀၀ ဘတ် နှင့်အတူ လစာ၏ ၅၀% ကို ၉၀ ရက်စာ ခံစားခွင့် ရရှိသည်။'),
          _item('ကလေးထောက်ပံ့စရိတ်', 'အသက် ၆ နှစ်အထိ ကလေးတစ်ဦးလျှင် တစ်လ ၈၀၀ ဘတ်စီ လစဉ် ထောက်ပံ့ငွေ ရရှိသည်။'),
          _item('အလုပ်လက်မဲ့ ထောက်ပံ့ကြေး', 'အလုပ်ထုတ်ခံရပါက လစာ၏ ၅၀% ကို ရက်ပေါင်း ၁၈၀ အထိ၊ မိမိသဘောဖြင့် နုတ်ထွက်ပါက ၃၀% ကို ရက်ပေါင်း ၉၀ အထိ ရရှိသည်။'),
          _item('သေဆုံးမှုနှင့် နာရေးစရိတ်', 'နာရေးစရိတ် ၅၀,၀၀၀ ဘတ် နှင့်အတူ ကျန်ရစ်သူ ထောက်ပံ့ကြေးများ ရရှိသည်။'),
          const SizedBox(height: 16),
          PrimaryGradientButton(
            onPressed: () => _openExternal('https://www.sso.go.th'),
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsBold.globe, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text('တရားဝင် SSO ဝက်ဘ်ဆိုက်သို့ သွားရန်', style: AppFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _kSlate900)),
          const SizedBox(height: 4),
          Text(desc, style: AppFonts.poppins(fontSize: 11.5, color: const Color(0xFF475569), height: 1.45)),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. Thai Fines & Penalties Detail Page
// ============================================================================

class ThaiFinesDetailPage extends StatelessWidget {
  const ThaiFinesDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _FeatureDetailScaffold(
      title: 'သိထားသင့်သော ထိုင်းဒဏ်ကြေးနှင့် ဥပဒေများ',
      badgeText: 'Fines & Regulations',
      body: Column(
        children: [
          _fineCard(
            title: 'ဗီဇာရက်ကျော်ခြင်း (Overstay)',
            fine: '၅၀၀ ဘတ် / ရက် (အများဆုံး ၂၀,၀၀၀ ဘတ်)',
            details: '• ရက် ၉၀ ကျော်လျှင် ၁ နှစ် ထိုင်းနိုင်ငံတွင်း ပြန်ဝင်ခွင့် ပိတ်ပင်ခြင်း (Blacklist)\n• ၁ နှစ်ကျော်လျှင် ၃ နှစ် ပိတ်ပင်ခြင်း\n• ၃ နှစ်ကျော်လျှင် ၅ နှစ် ပိတ်ပင်ခြင်း\n• ၅ နှစ်ကျော်လျှင် ၁၀ နှစ် ပြန်ဝင်ခွင့် ပိတ်ပင်ခြင်း ခံရမည်။',
            color: const Color(0xFFEF4444),
          ),
          _fineCard(
            title: 'အီးစီးကရက် (Vape / E-Cigarette) ပိတ်ပင်မှု',
            fine: 'ဒဏ်ငွေ ဘတ် ၅ သိန်းအထိ နှင့် ထောင်ဒဏ် ၅ နှစ်အထိ',
            details: '• ထိုင်းနိုင်ငံတွင် Vape / E-Cigarette တင်သွင်းခြင်း၊ ရောင်းချခြင်း၊ လမ်းပေါ်တွင် သောက်သုံး ကိုင်ဆောင်ခြင်းသည် လုံးဝတရားမဝင်ပါ။\n• လမ်းပေါ်တွင် ဖမ်းဆီးခံရပါက ကြီးလေးသော ပြစ်ဒဏ် ချမှတ်ခံရနိုင်သဖြင့် လုံးဝ မကိုင်ဆောင်သင့်ပါ။',
            color: const Color(0xFFEA580C),
          ),
          _fineCard(
            title: 'အလုပ်ပါမစ် စည်းကမ်းချက်နှင့် ပြည်နှင်ဒဏ်',
            fine: 'ဒဏ်ငွေ ၅,၀၀၀ မှ ၅၀,၀၀၀ ဘတ် နှင့် ပြည်နှင်ဒဏ်',
            details: '• အလုပ်ပါမစ်မရှိဘဲ အလုပ်လုပ်ကိုင်ခြင်း၊ နိုင်ငံခြားသား လုပ်ကိုင်ခွင့်မရှိသော အလုပ်များ (ဥပမာ- ဧည့်လမ်းညွှန်၊ ဈေးရောင်း၊ ဆံသ) လုပ်ကိုင်ပါက ဒဏ်ငွေနှင့် နိုင်ငံတော်မှ နှင်ထုတ်ခံရမည်။\n• အလုပ်ရှင် ပြောင်းလဲပါက ရက်ပေါင်း ၃၀ မှ ၆၀ အတွင်း အလုပ်ရှင်သစ် ထံ တရားဝင် ပြောင်းရွှေ့စာရင်းသွင်းရမည်။',
            color: const Color(0xFFF59E0B),
          ),
          _fineCard(
            title: 'နေရပ်လိပ်စာ အကြောင်းကြားခြင်း (TM.30)',
            fine: 'ဒဏ်ငွေ ၁,၆၀၀ မှ ၂,၀၀၀ ဘတ်',
            details: '• နိုင်ငံခြားသားတစ်ဦး နေထိုင်ရာ အိမ်၊ ဟိုတယ်၊ တိုက်ခန်းသို့ ရောက်ရှိပြီး ၂၄ နာရီအတွင်း အိမ်ရှင် သို့မဟုတ် တာဝန်ရှိသူက လူဝင်မှုကြီးကြပ်ရေးသို့ TM.30 တိုင်ကြားရမည်။',
            color: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }

  Widget _fineCard({
    required String title,
    required String fine,
    required String details,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(PhosphorIconsFill.warningOctagon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GradientText(
                  title,
                  style: AppFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'ပြစ်ဒဏ်/ဒဏ်ငွေ: $fine',
              style: AppFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            details,
            style: AppFonts.poppins(fontSize: 11.5, color: const Color(0xFF475569), height: 1.55),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 7. Hotlines Detail Page
// ============================================================================

class HotlinesDetailPage extends StatelessWidget {
  const HotlinesDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hotlines = [
      (
        '1506',
        'အလုပ်သမားဝန်ကြီးဌာန / လူမှုဖူလုံရေး',
        'အလုပ်သမားအခွင့်အရေး ချိုးဖောက်ခံရမှု၊ လစာမရမှု၊ အလုပ်ပါမစ်နှင့် လူမှုဖူလုံရေး။ (အသံမီနူးတွင် မြန်မာဘာသာ ရွေးချယ်နိုင်သည်)',
        'Ministry of Labour',
      ),
      (
        '1155',
        'ခရီးသွားရဲတပ်ဖွဲ့ (Tourist Police)',
        'နိုင်ငံခြားသားများအတွက် ၂၄ နာရီ ဘာသာပြန်နှင့် အရေးပေါ် အကူအညီပေးရေး စင်တာ။',
        'Tourist Police 24h',
      ),
      (
        '191',
        'ရဲ အရေးပေါ် ခေါ်ဆိုမှု',
        'မတော်တဆမှုများ၊ မှုခင်းများ၊ အရေးပေါ် လုံခြုံရေး အကူအညီ လိုအပ်သောအခါ။',
        'Police Emergency',
      ),
      (
        '1669',
        'ဆေးဘက်ဆိုင်ရာ အရေးပေါ် လူနာတင်ယာဉ်',
        'အရေးပေါ် ဆေးရုံ လူနာတင်ယာဉ် ခေါ်ဆိုရန်။',
        'Ambulance 24h',
      ),
      (
        '1300',
        'လူမှုကူညီရေးစင်တာ (MSDHS)',
        'လူကုန်ကူးမှု၊ အကြမ်းဖက်ခံရမှုနှင့် လူမှုရေး ကူညီထောက်ပံ့မှု လိုအပ်သူများအတွက်။',
        'Social Assistance',
      ),
    ];

    return _FeatureDetailScaffold(
      title: 'တိုက်ရိုက်ခေါ်ဆိုနိုင်သော အရေးပေါ်ဖုန်းများ',
      badgeText: 'Emergency Directory',
      body: Column(
        children: [
          for (final h in hotlines)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const GradientIcon(icon: PhosphorIconsFill.phoneCall, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GradientText(
                              h.$1,
                              style: AppFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                h.$4,
                                style: AppFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: _kSlate600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          h.$2,
                          style: AppFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kSlate900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          h.$3,
                          style: AppFonts.poppins(fontSize: 11, color: _kSlate500, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _callPhone(h.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIconsFill.phone, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'ခေါ်မည်',
                            style: AppFonts.poppins(
                              fontSize: 11.5,
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
        ],
      ),
    );
  }
}

// ============================================================================
// 8. Visa Types Hub Page (Shows Visas in 2-Column Grid)
// ============================================================================

class VisaTypesHubPage extends StatelessWidget {
  final List<VisaDto> visas;
  final List<VisaCategoryDto> categories;

  const VisaTypesHubPage({
    super.key,
    required this.visas,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return _FeatureDetailScaffold(
      title: 'ထိုင်းဗီဇာ အမျိုးအစားများ',
      badgeText: '${visas.length} Types Available',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ထိုင်းနိုင်ငံသို့ လာရောက် အလုပ်လုပ်ကိုင်ခြင်း၊ ခရီးသွားခြင်းနှင့် ရေရှည်နေထိုင်ခြင်းအတွက် တရားဝင်ဗီဇာများ',
            style: AppFonts.poppins(fontSize: 12, color: _kSlate600, height: 1.45),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visas.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.76,
            ),
            itemBuilder: (context, i) {
              final v = visas[i];
              return _VisaGridCard(
                visa: v,
                onTap: () {
                  AppHaptics.buttonTap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisaDetailPage(
                        args: VisaDetailArgs(
                          visaId: v.id,
                          title: v.displayTitle,
                          subtitle: v.displaySubtitle,
                          description: v.displayDescription,
                          categoryTitle: v.visaCategory?.title,
                          imageUrl: v.resolvedImageUrl,
                          officialWebsite: v.linkUrl,
                          canTakeAppointmentOnline: v.linkUrl != null &&
                              v.linkUrl!.toLowerCase().contains('evisa'),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 9. Immigration Services Hub Page (Shows TM Services in 2-Column Grid)
// ============================================================================

class ImmigrationServicesHubPage extends StatelessWidget {
  final List<VisaDto> services;

  const ImmigrationServicesHubPage({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return _FeatureDetailScaffold(
      title: 'လူဝင်မှုကြီးကြပ်ရေး ဝန်ဆောင်မှုများ (တမလိပ်)',
      badgeText: 'Immigration TM Forms',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ထိုင်းလူဝင်မှုကြီးကြပ်ရေးဗျူရို၏ တရားဝင်လုပ်ထုံးလုပ်နည်းများနှင့် ဖောင်ပုံစံများ',
            style: AppFonts.poppins(fontSize: 12, color: _kSlate600, height: 1.45),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: services.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.76,
            ),
            itemBuilder: (context, i) {
              final s = services[i];
              return _VisaGridCard(
                visa: s,
                onTap: () {
                  AppHaptics.buttonTap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisaDetailPage(
                        args: VisaDetailArgs(
                          visaId: s.id,
                          title: s.displayTitle,
                          subtitle: s.displaySubtitle,
                          description: s.displayDescription,
                          categoryTitle: s.visaCategory?.title,
                          imageUrl: s.resolvedImageUrl,
                          officialWebsite: s.linkUrl,
                          canTakeAppointmentOnline: s.linkUrl != null &&
                              s.linkUrl!.toLowerCase().contains('evisa'),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared Visa Grid Card Component (Used in 2-Column Grids)
// ============================================================================

class _VisaGridCard extends StatelessWidget {
  final VisaDto visa;
  final VoidCallback onTap;

  const _VisaGridCard({required this.visa, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOnline =
        visa.linkUrl != null && visa.linkUrl!.toLowerCase().contains('evisa');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDF2F7), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: const GradientIcon(
                        icon: PhosphorIconsFill.identificationCard,
                        size: 20,
                      ),
                    ),
                    if (isOnline)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'E-Visa',
                          style: AppFonts.poppins(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  visa.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                    height: 1.25,
                  ),
                ),
                if (visa.displaySubtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    visa.displaySubtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.poppins(
                      fontSize: 10.5,
                      color: const Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'အသေးစိတ်',
                      style: AppFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      PhosphorIconsBold.arrowUpRight,
                      size: 10.5,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

