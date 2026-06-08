import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage>
    with TickerProviderStateMixin {
  int? _expandedFaq;

  final List<_FaqItem> _faqs = const [
    _FaqItem(
      questionEn: 'How do I create an account?',
      questionMm: 'အကောင့် ဖွင့်ရန် ဘယ်လိုလုပ်ရမလဲ?',
      questionTh: 'จะสร้างบัญชีได้อย่างไร?',
      answerEn:
          'Open the MyTogether app, tap "Register", then fill in your name, email and password to create your account.',
      answerMm:
          'MyTogether app ကိုဖွင့်ပြီး "Register" ကိုနှိပ်ကာ သင့်နာမည်၊ Email နှင့် Password ဖြင့် အကောင့်ဖွင့်နိုင်ပါသည်။',
      answerTh:
          'เปิดแอป MyTogether แตะ "Register" จากนั้นกรอกชื่อ อีเมล และรหัสผ่านเพื่อสร้างบัญชีของคุณ',
    ),
    _FaqItem(
      questionEn: 'How long does delivery take?',
      questionMm: 'Order လုပ်ပြီးနောက် မည်မျှကြာမည်?',
      questionTh: 'การจัดส่งใช้เวลานานแค่ไหน?',
      answerEn:
          'Delivery typically takes 30–60 minutes, depending on distance and order volume.',
      answerMm:
          'ပုံမှန်အားဖြင့် မိနစ် ၃၀ မှ ၆၀ ကြားတွင် ရောက်ရှိပါမည်။ အကွာအဝေးနှင့် ဝယ်သူအရေအတွက်ပေါ် မူတည်ပြောင်းလဲနိုင်သည်။',
      answerTh:
          'โดยทั่วไปใช้เวลา 30–60 นาที ขึ้นอยู่กับระยะทางและปริมาณคำสั่งซื้อ',
    ),
    _FaqItem(
      questionEn: 'Can I cancel my order?',
      questionMm: 'Order ပယ်ဖျက်နိုင်ပါသလား?',
      questionTh: 'ฉันสามารถยกเลิกคำสั่งซื้อได้ไหม?',
      answerEn:
          'You may cancel within 5 minutes of placing the order. After the seller accepts, please contact support for assistance.',
      answerMm:
          'Order တင်ပြီး မိနစ် ၅ အတွင်း ပယ်ဖျက်နိုင်ပါသည်။ ရောင်းသူ လက်ခံပြီးနောက် ပယ်ဖျက်ရန် Support ကို ဆက်သွယ်ပါ။',
      answerTh:
          'คุณสามารถยกเลิกได้ภายใน 5 นาทีหลังสั่งซื้อ หลังจากร้านรับออร์เดอร์แล้ว กรุณาติดต่อฝ่ายสนับสนุน',
    ),
    _FaqItem(
      questionEn: 'What is your refund policy?',
      questionMm: 'ငွေပြန်အမ်းမည်လား?',
      questionTh: 'นโยบายการคืนเงินเป็นอย่างไร?',
      answerEn:
          'If your order is not fulfilled due to an issue on our end, a full refund will be issued. Please contact our support team.',
      answerMm:
          'Order ကို ပြဿနာတစ်ခုကြောင့် မပြည့်မီဆောင်ရွက်ပေးနိုင်ပါက ငွေပြန်အမ်းပါမည်။ Support team ကို ဆက်သွယ်ပါ။',
      answerTh:
          'หากคำสั่งซื้อไม่สำเร็จเนื่องจากปัญหาจากเรา จะคืนเงินเต็มจำนวน กรุณาติดต่อทีมสนับสนุน',
    ),
    _FaqItem(
      questionEn: 'What if I forget my password?',
      questionMm: 'Password မေ့သွားလျှင် ဘာလုပ်ရမလဲ?',
      questionTh: 'หากลืมรหัสผ่านต้องทำอย่างไร?',
      answerEn:
          'On the login page, tap "Forgot Password" and a reset link will be sent to your email.',
      answerMm:
          'Login page တွင် "Forgot Password" ကိုနှိပ်ပြီး သင့် Email သို့ Reset link ရယူပါ။',
      answerTh:
          'ที่หน้าเข้าสู่ระบบ แตะ "Forgot Password" แล้วลิงก์รีเซ็ตจะถูกส่งไปยังอีเมลของคุณ',
    ),
    _FaqItem(
      questionEn: 'How do I check currency exchange rates?',
      questionMm: 'Currency Exchange rate ကို မည်ကဲ့သို့ ကြည့်ရမလဲ?',
      questionTh: 'จะดูอัตราแลกเปลี่ยนเงินตราได้อย่างไร?',
      answerEn:
          'From the Home screen, tap the "Currency Exchange" section to view live rates.',
      answerMm:
          'Home screen တွင် "Currency Exchange" ကဏ္ဍကို နှိပ်ပါ။ Live rates များကို ကြည့်ရှုနိုင်သည်။',
      answerTh:
          'จากหน้าแรก แตะส่วน "Currency Exchange" เพื่อดูอัตราแบบเรียลไทม์',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeftBold,
              color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('help.title'),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero banner
            _buildHeroBanner(),

            const SizedBox(height: 24),

            // Quick contact actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                context.tr('help.contact_us'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildContactCard(
                      icon: PhosphorIcons.phoneFill,
                      label: context.tr('help.call'),
                      sublabel: context.tr('help.call_us'),
                      color: Colors.green,
                      onTap: () => _launch('tel:+959123456789'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildContactCard(
                      icon: PhosphorIcons.envelopeFill,
                      label: context.tr('help.email'),
                      sublabel: context.tr('help.email_us'),
                      color: AppColors.primary,
                      onTap: () => _launch(
                          'mailto:support@mytogetherapp.com?subject=Support%20Request'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildContactCard(
                      icon: PhosphorIcons.telegramLogoFill,
                      label: context.tr('help.telegram'),
                      sublabel: context.tr('help.chat_now'),
                      color: const Color(0xFF229ED9),
                      onTap: () => _launch('https://t.me/mytogetherapp'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildContactCard(
                      icon: PhosphorIcons.facebookLogoFill,
                      label: context.tr('help.facebook'),
                      sublabel: context.tr('help.message_us'),
                      color: const Color(0xFF1877F2),
                      onTap: () =>
                          _launch('https://facebook.com/mytogetherapp'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Contact info card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildInfoCard(),
            ),

            const SizedBox(height: 28),

            // FAQ Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                context.tr('help.faq'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_faqs.length, (i) => _buildFaqTile(i)),

            const SizedBox(height: 28),

            // Still need help
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildStillNeedHelp(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.headsetFill,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('help.banner_title'),
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('help.subtitle'),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                const SizedBox(width: 8),
                Text(
                  context.tr('help.hours_badge'),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              sublabel,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: PhosphorIcons.envelopeFill,
            label: context.tr('common.email'),
            value: 'support@mytogetherapp.com',
            color: AppColors.primary,
            onCopy: () => _copyToClipboard('support@mytogetherapp.com'),
          ),
          const Divider(height: 24, thickness: 0.5),
          _buildInfoRow(
            icon: PhosphorIcons.phoneFill,
            label: context.tr('help.phone'),
            value: '+95 9 123 456 789',
            color: Colors.green,
            onCopy: () => _copyToClipboard('+959123456789'),
          ),
          const Divider(height: 24, thickness: 0.5),
          _buildInfoRow(
            icon: PhosphorIcons.mapPinFill,
            label: context.tr('help.address'),
            value: context.tr('help.address_value'),
            color: Colors.orange,
          ),
          const Divider(height: 24, thickness: 0.5),
          _buildInfoRow(
            icon: PhosphorIcons.clockFill,
            label: context.tr('help.office_hours'),
            value: context.tr('help.office_hours_value'),
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onCopy,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (onCopy != null)
          GestureDetector(
            onTap: onCopy,
            child: Icon(PhosphorIcons.copy, size: 18, color: Colors.grey[400]),
          ),
      ],
    );
  }

  Widget _buildFaqTile(int index) {
    final faq = _faqs[index];
    final isExpanded = _expandedFaq == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: GestureDetector(
        onTap: () => setState(
            () => _expandedFaq = isExpanded ? null : index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isExpanded
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : Colors.grey.shade100,
            ),
            boxShadow: [
              BoxShadow(
                color: isExpanded
                    ? AppColors.primary.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: isExpanded
                            ? AppColors.primaryGradient
                            : const LinearGradient(
                                colors: [Color(0xFFF1F5F9), Color(0xFFF1F5F9)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Q',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isExpanded ? Colors.white : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.localized(
                          en: faq.questionEn,
                          mm: faq.questionMm,
                          th: faq.questionTh,
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isExpanded ? AppColors.primary : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              if (isExpanded)
                Container(
                  padding: const EdgeInsets.fromLTRB(60, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 1,
                        color: Colors.grey.shade100,
                        margin: const EdgeInsets.only(bottom: 12),
                      ),
                      Text(
                        context.localized(
                          en: faq.answerEn,
                          mm: faq.answerMm,
                          th: faq.answerTh,
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStillNeedHelp() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            PhosphorIcons.chatCircleDotsFill,
            size: 40,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('help.need_more_help'),
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          Text(
            context.tr('help.still_need_help'),
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('help.email_support_desc'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _launch(
                  'mailto:support@mytogetherapp.com?subject=Help%20Request&body=Hello%20MyTogether%20Support%20Team,%0A%0A'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.envelopeFill, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('help.send_email'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.tr('help.could_not_open'), style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.red.shade500,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(context.tr('common.copied'), style: GoogleFonts.poppins(color: Colors.white)),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class _FaqItem {
  final String questionEn;
  final String questionMm;
  final String questionTh;
  final String answerEn;
  final String answerMm;
  final String answerTh;

  const _FaqItem({
    required this.questionEn,
    required this.questionMm,
    required this.questionTh,
    required this.answerEn,
    required this.answerMm,
    required this.answerTh,
  });
}
