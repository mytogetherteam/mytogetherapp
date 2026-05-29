import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:dio/dio.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/features/auth/data/repositories/auth_repository.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/login_page.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _agreed = false;
  int _step = 1; // 1 = warnings, 2 = confirm password

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthRepository.instance.deleteAccount(
        password: _passwordController.text,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
        _showSuccessSnackbar();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(DioException e) {
    final body = e.response?.data;
    final details = body is Map ? body['details'] as String? : null;
    final message = body is Map ? body['message'] as String? : null;
    return details?.isNotEmpty == true
        ? details!
        : message ?? 'တစ်ခုခု မှားယွင်းနေပါသည်။';
  }

  void _showErrorSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('သင့်အကောင့်ကို ဖျက်သိမ်းလိုက်ပါပြီ။',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _goToStep2() {
    if (!_agreed) {
      _showErrorSnackbar('ကျေးဇူးပြု၍ သဘောတူညီချက်ကို အမှန်ခြစ်ပေးပါ။');
      return;
    }
    setState(() {
      _step = 2;
      _animController.reset();
      _animController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(PhosphorIconsBold.arrowLeft,
              color: Colors.black),
          onPressed: () {
            if (_step == 2) {
              setState(() {
                _step = 1;
                _animController.reset();
                _animController.forward();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          children: [
            Text(
              'အကောင့်ဖျက်ရန်',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            Text(
              'Delete Account',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _step == 1 ? _buildStep1() : _buildStep2(),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Warning icon
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIconsFill.warning,
              size: 52,
              color: Colors.red.shade500,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'သတိပြုရန်',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.red.shade600,
            ),
          ),
          Text(
            'Before you delete',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 28),

          // Warning cards
          _buildWarningCard(
            icon: PhosphorIconsFill.shoppingCart,
            title: 'အော်ဒါများ ပျောက်ကွယ်မည်',
            subtitle: 'Your orders history will be permanently deleted',
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildWarningCard(
            icon: PhosphorIconsFill.wallet,
            title: 'ငွေလက်ကျန် ဆုံးရှုံးမည်',
            subtitle: 'Any remaining balance or credits will be lost',
            color: Colors.purple,
          ),
          const SizedBox(height: 12),
          _buildWarningCard(
            icon: PhosphorIconsFill.userMinus,
            title: 'ပြန်ရယူ၍ မရနိုင်ပါ',
            subtitle: 'This action is permanent and cannot be undone',
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          _buildWarningCard(
            icon: PhosphorIconsFill.lock,
            title: 'ဝင်ရောက်မှု ပိတ်မည်',
            subtitle: 'You will be immediately logged out and access revoked',
            color: Colors.blue,
          ),
          const SizedBox(height: 28),

          // Agreement checkbox
          GestureDetector(
            onTap: () => setState(() => _agreed = !_agreed),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _agreed ? Colors.red.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _agreed ? Colors.red.shade300 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _agreed ? Colors.red.shade500 : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            _agreed ? Colors.red.shade500 : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: _agreed
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'အထက်ပါ သတိပြုချက်များကို နားလည်ပြီး ကျွန်ုပ်၏အကောင့်ကို အပြီးအပိုင် ဖျက်သိမ်းရန် သဘောတူပါသည်။',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'I understand and agree to permanently delete my account.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Continue button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _goToStep2,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'ဆက်လက်လုပ်ဆောင်မည် • Continue',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Text(
                'မဖျက်ပါ • Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Lock icon
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIconsFill.lockKey,
                size: 52,
                color: Colors.red.shade500,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'အတည်ပြုပါ',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            Text(
              'Confirm your identity',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              'အကောင့်ဖျက်ရန် သင့်စကားဝှက်ကို ထည့်သွင်းပါ။\nPlease enter your password to confirm deletion.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),

            // User info chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(PhosphorIconsBold.user,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuthService().currentUser?.fullName ??
                            AuthService().currentUser?.username ??
                            'User',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        AuthService().currentUser?.email ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Password field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              validator: (v) {
                if (v == null || v.isEmpty) return 'စကားဝှက် ထည့်သွင်းပါ';
                if (v.length < 6) return 'စကားဝှက် အနည်းဆုံး ၆ လုံး ရှိရမည်';
                return null;
              },
              style: GoogleFonts.poppins(fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Password • စကားဝှက်',
                labelStyle:
                    GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
                prefixIcon: Icon(PhosphorIcons.lock,
                    color: Colors.grey[500], size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? PhosphorIcons.eye
                        : PhosphorIcons.eyeSlash,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Final delete button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.red.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'အကောင့်ဖျက်မည် • Delete My Account',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Text(
                  'မဖျက်ပါ • Cancel',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color.shade500, size: 22),
          ),
          const SizedBox(width: 14),
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
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[500],
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
