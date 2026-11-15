import '../../data/services/thailand_alert_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/presentation/widgets/gradient_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/haptic_splash_factory.dart';

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

Future<void> _open(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

enum Tm47Status { safe, open, grace, overdue }

class Tm47Calculation {
  final DateTime baseDate;
  final DateTime dueDate;
  final DateTime windowStart;
  final DateTime windowEnd;
  final int daysRemaining;
  final Tm47Status status;

  const Tm47Calculation({
    required this.baseDate,
    required this.dueDate,
    required this.windowStart,
    required this.windowEnd,
    required this.daysRemaining,
    required this.status,
  });

  static Tm47Calculation fromDate(DateTime baseDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final base = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final dueDate = base.add(const Duration(days: 90));
    final windowStart = dueDate.subtract(const Duration(days: 15));
    final windowEnd = dueDate.add(const Duration(days: 7));
    final daysRemaining = dueDate.difference(today).inDays;

    Tm47Status status;
    if (daysRemaining > 15) {
      status = Tm47Status.safe;
    } else if (daysRemaining >= 0 && daysRemaining <= 15) {
      status = Tm47Status.open;
    } else if (daysRemaining >= -7) {
      status = Tm47Status.grace;
    } else {
      status = Tm47Status.overdue;
    }

    return Tm47Calculation(
      baseDate: base,
      dueDate: dueDate,
      windowStart: windowStart,
      windowEnd: windowEnd,
      daysRemaining: daysRemaining,
      status: status,
    );
  }
}

class Tm47Service {
  static const String keyDate = 'tm47_saved_date_millis';
  static const String keyType = 'tm47_saved_entry_type';

  static Future<DateTime?> getSavedDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(keyDate);
      if (ms != null) {
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } catch (_) {}
    return null;
  }

  static Future<int> getSavedType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(keyType) ?? 0;
    } catch (_) {}
    return 0;
  }

  static Future<void> save(DateTime date, int type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyDate, date.millisecondsSinceEpoch);
      await prefs.setInt(keyType, type);
      final reminder = await ThailandAlertService.instance.isTm47ReminderEnabled();
      if (reminder) {
        await ThailandAlertService.instance.scheduleTm47Notifications(date);
      }
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyDate);
      await prefs.remove(keyType);
      await ThailandAlertService.instance.cancelTm47Notifications();
    } catch (_) {}
  }
}

/// Interactive 90-Day (TM.47) Report Due Date & Window Checker Sheet
class Tm47CheckerSheet extends StatefulWidget {
  final DateTime? initialDate;
  final int? initialType;
  final VoidCallback? onSaved;

  const Tm47CheckerSheet({
    super.key,
    this.initialDate,
    this.initialType,
    this.onSaved,
  });

  static void show(
    BuildContext context, {
    DateTime? initialDate,
    int? initialType,
    VoidCallback? onSaved,
  }) {
    AppHaptics.buttonTap();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Tm47CheckerSheet(
        initialDate: initialDate,
        initialType: initialType,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<Tm47CheckerSheet> createState() => _Tm47CheckerSheetState();
}

class _Tm47CheckerSheetState extends State<Tm47CheckerSheet> {
  DateTime? _selectedDate;
  int _entryType = 0; // 0 = Last TM.47 Report Date, 1 = Thailand Arrival Date

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _entryType = widget.initialType ?? 0;
    _initSaved();
  }

  Future<void> _initSaved() async {
    if (widget.initialDate == null) {
      final saved = await Tm47Service.getSavedDate();
      final savedType = await Tm47Service.getSavedType();
      if (mounted) {
        setState(() {
          _selectedDate = saved;
          _entryType = savedType;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_selectedDate != null) {
      await Tm47Service.save(_selectedDate!, _entryType);
      widget.onSaved?.call();
    }
  }

  Future<void> _clearDate() async {
    AppHaptics.buttonTap();
    await Tm47Service.clear();
    if (mounted) {
      setState(() {
        _selectedDate = null;
      });
      widget.onSaved?.call();
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
      setState(() {
        _selectedDate = picked;
      });
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
          statusColor = const Color(0xFF10B981); // Green
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
          statusColor = const Color(0xFFF59E0B); // Amber
          statusIcon = PhosphorIconsFill.bellRinging;
          statusTitle = const _Tx(
            en: 'Window Open - Report Now',
            mm: 'ယခု တိုင်ကြားနိုင်ပါပြီ',
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
          statusColor = const Color(0xFFEA580C); // Deep Orange
          statusIcon = PhosphorIconsFill.warning;
          statusTitle = const _Tx(
            en: 'Grace Period (7 Days)',
            mm: '၇ ရက် သက်ညှာခွင့်ကာလအတွင်း',
            th: 'อยู่ในช่วงผ่อนผန် 7 วัน',
          ).s;
          final daysLate = -calc.daysRemaining;
          statusSubtitle = '${const _Tx(
            en: 'Due date passed ',
            mm: 'သတ်မှတ်ရက်ကျော်လွန်သည်မှာ ',
            th: 'เกินกำหนดมาแล้ว ',
          ).s}$daysLate ${const _Tx(en: 'days ago (Report immediately)', mm: 'ရက် ရှိပါပြီ (ချက်ချင်းတင်ပါ)', th: 'วัน (รีบรายงานตัวด่วน)').s}';
          break;
        case Tm47Status.overdue:
          statusColor = const Color(0xFFEF4444); // Red
          statusIcon = PhosphorIconsFill.xCircle;
          statusTitle = const _Tx(
            en: 'Overdue - 2,000 THB Fine',
            mm: 'ရက်လွန်ဒဏ်ကြေး ကျသင့်ပါပြီ',
            th: 'เกินกำหนด - มีค่าปรับ 2,000 บาท',
          ).s;
          final daysLate = -calc.daysRemaining;
          statusSubtitle = '${const _Tx(
            en: 'Overdue by ',
            mm: 'ရက်လွန်သွားသည်မှာ ',
            th: 'เกินกำหนดมาแล้ว ',
          ).s}$daysLate ${const _Tx(en: 'days. Overstaying fine applies.', mm: 'ရက် ဖြစ်ပါသည် (ဒဏ်ကြေး ပေးဆောင်ရမည်)။', th: 'วัน ต้องชำระค่าปรับ').s}';
          break;
      }
    }

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const GradientIcon(
                        icon: PhosphorIconsFill.calendarCheck,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            const _Tx(
                              en: '90-Day Report (TM.47) Checker',
                              mm: 'ရက် ၉၀ (TM.47) စစ်ဆေးတွက်ချက်စက်',
                              th: 'ตรวจกำหนดรายงานตัว 90 วัน (ตม.47)',
                            ).s,
                            style: AppFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _kSlate900,
                            ),
                          ),
                          Text(
                            const _Tx(
                              en: 'Thai Immigration Bureau Regulation',
                              mm: 'ထိုင်းလူဝင်မှုကြီးကြပ်ရေး တရားဝင်စည်းမျဉ်း',
                              th: 'ระเบียบสำนักงานตรวจคนเข้าเมือง',
                            ).s,
                            style: AppFonts.poppins(
                              fontSize: 11.5,
                              color: _kSlate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasDate)
                      GestureDetector(
                        onTap: _clearDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            const _Tx(
                              en: 'Reset',
                              mm: 'ရှင်းမည်',
                              th: 'รีเซ็ต',
                            ).s,
                            style: AppFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Calculation Type Switcher
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEEF2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _typeTab(
                          0,
                          const _Tx(
                            en: 'Last Report Date',
                            mm: 'နောက်ဆုံး တိုင်ကြားသည့်ရက်',
                            th: 'วันรายงานตัวล่าสุด',
                          ).s,
                        ),
                      ),
                      Expanded(
                        child: _typeTab(
                          1,
                          const _Tx(
                            en: 'Thailand Arrival Date',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
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
                          size: 20,
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
                                  fontWeight: hasDate ? FontWeight.w700 : FontWeight.w600,
                                  color: hasDate ? _kSlate900 : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hasDate
                                ? const _Tx(
                                    en: 'Change',
                                    mm: 'ရက်ပြောင်းရန်',
                                    th: 'เปลี่ยนวัน',
                                  ).s
                                : const _Tx(
                                    en: 'Pick Date',
                                    mm: 'ရက်ရွေးမည်',
                                    th: 'เลือกวันที่',
                                  ).s,
                            style: AppFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // If date is set, show full live calculated results
                if (hasDate && calc != null) ...[
                  // Status Banner
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 24),
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
                              const SizedBox(height: 3),
                              Text(
                                statusSubtitle,
                                style: AppFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: _kSlate600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Detailed Dates Result Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
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
                        const Divider(
                          height: 20,
                          thickness: 0.6,
                          color: Color(0xFFF1F5F9),
                        ),
                        _dateRow(
                          title: const _Tx(
                            en: 'Earliest Submission (15 Days Before)',
                            mm: 'စတင်တင်သွင်းနိုင်သည့်ရက် (၁၅ ရက် ကြိုတင်)',
                            th: 'เริ่มยื่นล่วงหน้าได้ (15 วันก่อนกำหนด)',
                          ).s,
                          dateStr: dateFormat.format(calc.windowStart),
                        ),
                        const Divider(
                          height: 20,
                          thickness: 0.6,
                          color: Color(0xFFF1F5F9),
                        ),
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
                ] else ...[
                  // Not set hint card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          PhosphorIconsFill.info,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            const _Tx(
                              en: 'Pick your last report or arrival date above to see your exact 90-day deadline.',
                              mm: 'နောက်တစ်ကြိမ် ရက် ၉၀ ပြည့်မည့်ရက်နှင့် အချိန်မီတင်သွင်းရန် ကြိုတင်ကာလများကို ကြည့်ရှုရန် အထက်တွင် ရက်စွဲ ရွေးချယ်ပါခင်ဗျာ။',
                              th: 'เลือกวันรายงานตัวล่าสุดหรือวันเข้าไทยด้านบน เพื่อดูวันครบกำหนด 90 วันที่แน่นอน',
                            ).s,
                            style: AppFonts.poppins(
                              fontSize: 12,
                              color: _kSlate600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Legal Rules Accordion/Note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            PhosphorIconsFill.info,
                            size: 16,
                            color: _kSlate500,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            const _Tx(
                              en: 'Important 90-Day Rules',
                              mm: 'အရေးကြီးသော ရက် ၉၀ စည်းကမ်းများ',
                              th: 'กฎสำคัญการรายงานตัว 90 วัน',
                            ).s,
                            style: AppFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _kSlate900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _ruleBullet(
                        const _Tx(
                          en: 'Online report (tm47.immigration.go.th) can be filed 15 to 7 days before due date.',
                          mm: 'အွန်လိုင်းမှ တင်ပါက သတ်မှတ်ရက် မတိုင်မီ ၁၅ ရက်မှ ၇ ရက် ကြိုတင်တင်ရပါမည်။',
                          th: 'ยื่นออนไลน์ต้องยื่นล่วงหน้า 15 ถึง 7 วันก่อนครบกำหนด',
                        ).s,
                      ),
                      _ruleBullet(
                        const _Tx(
                          en: 'Leaving Thailand resets the 90-day count to 1 on your re-entry date.',
                          mm: 'ထိုင်းနိုင်ငံမှ ပြန်ထွက်ပါက ထိုင်းသို့ ပြန်ဝင်သည့်ရက်မှ ရက် ၉၀ ပြန်စပါမည်။',
                          th: 'หากเดินทางออกนอกประเทศ นับ 90 วันใหม่ตั้งแต่วันที่กลับเข้าไทย',
                        ).s,
                      ),
                      _ruleBullet(
                        const _Tx(
                          en: 'Late report fine is 2,000 THB; if arrested without report, fine is up to 5,000 THB + 200 THB/day.',
                          mm: 'ရက်လွန်ဒဏ်ကြေးမှာ ၂,၀၀၀ ဘတ် ဖြစ်ပြီး ဖမ်းဆီးခံရပါက ၅,၀၀၀ ဘတ်အထိ ကျသင့်နိုင်သည်။',
                          th: 'ค่าปรับรายงานตัวช้า 2,000 บาท หากถูกจับกุมปรับสูงสุด 5,000 บาท + วันละ 200 บาท',
                        ).s,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Button to Official TM.47 Online Portal
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () =>
                        _open(Uri.parse('https://tm47.immigration.go.th/')),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Ink(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              PhosphorIconsBold.globe,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              const _Tx(
                                en: 'Go to Official TM.47 Online System',
                                mm: 'တရားဝင် TM.47 Online စနစ်သို့ သွားရန်',
                                th: 'ไปยังระบบรายงานตัว 90 วันออนไลน์',
                              ).s,
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeTab(int index, String label) {
    final isSelected = _entryType == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppHaptics.buttonTap();
        setState(() => _entryType = index);
        _save();
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
            color: isSelected ? Colors.white : _kSlate500,
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
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
              color: isHighlight ? _kSlate900 : _kSlate600,
            ),
          ),
        ),
        Text(
          dateStr,
          style: AppFonts.poppins(
            fontSize: isHighlight ? 14 : 12.5,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight ? AppColors.primary : _kSlate900,
          ),
        ),
      ],
    );
  }

  Widget _ruleBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: _kSlate500,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppFonts.poppins(
                fontSize: 11.5,
                color: _kSlate600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
