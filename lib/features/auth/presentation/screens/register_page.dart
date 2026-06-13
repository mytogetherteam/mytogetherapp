import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/theme/app_colors.dart';
import 'setup_pin_page.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/utils/firebase_error_handler.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  bool _showOtpView = false;
  String? _verificationId;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phoneStr = '+66${_phoneController.text.trim().replaceAll(' ', '')}';
      
      // Check if phone number already exists
      final bool exists = await AuthRepository.instance.checkPhoneExists(phoneStr);
      if (exists) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This phone number is already registered. Please login instead.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneStr,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (rarely triggers correctly across all devices)
          _verifyWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          final msg = FirebaseErrorHandler.getMessage(context, e);
          AppDialog.showToast(context, msg, isError: true);
          setState(() {
            _errorMessage = msg;
            _isLoading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _showOtpView = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      final msg = FirebaseErrorHandler.getMessage(context, e);
      AppDialog.showToast(context, msg, isError: true);
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_verificationId == null || _otpController.text.isEmpty) {
      setState(() => _errorMessage = context.tr('auth.enter_otp'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await _verifyWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      final msg = FirebaseErrorHandler.getMessage(context, e);
      AppDialog.showToast(context, msg, isError: true);
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    } catch (e) {
      final msg = FirebaseErrorHandler.getMessage(context, e);
      AppDialog.showToast(context, msg, isError: true);
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();

      if (idToken == null) throw Exception("Failed to get Firebase ID token");

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SetupPinPage(
            idToken: idToken,
            name: _fullNameController.text.trim(),
            email: _emailController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (_showOtpView) {
              setState(() => _showOtpView = false);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/logo_3d.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    const SizedBox(height: 8),
                    Text(
                      context.tr('auth.create_account'),
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _showOtpView
                          ? context.tr('auth.otp_subtitle')
                          : context.tr('auth.join_subtitle'),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_errorMessage != null) ...[
                      _buildErrorBanner(_errorMessage!),
                      const SizedBox(height: 20),
                    ],

                    if (!_showOtpView) _buildRegistrationForm(),
                    if (_showOtpView) _buildOtpForm(),

                    const SizedBox(height: 32),

                    PrimaryGradientButton(
                      onPressed: _isLoading ? null : (_showOtpView ? _handleVerifyOtp : _handleSendOtp),
                      isLoading: _isLoading,
                      child: Text(
                        _showOtpView
                            ? context.tr('auth.verify_otp_register')
                            : context.tr('auth.send_otp'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),


                          const SizedBox(height: 40),
                        ],
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

  Widget _buildRegistrationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context.tr('auth.register_phone')),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _phoneController,
          hint: context.tr('auth.phone_hint'),
          prefixWidget: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_outlined, color: Colors.grey[500], size: 20),
                const SizedBox(width: 8),
                Text(
                  '+66',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 20, color: Colors.grey[300]),
                const SizedBox(width: 8),
              ],
            ),
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return context.tr('auth.enter_phone');
            final cleanPhone = v.replaceAll(' ', '');
            if (!RegExp(r'^\d{8,9}$').hasMatch(cleanPhone)) {
              return context.tr('auth.invalid_thai_phone');
            }
            return null;
          },
        ),
        const SizedBox(height: 18),

        _buildLabel(context.tr('auth.full_name')),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _fullNameController,
          hint: context.tr('auth.name_hint'),
          icon: Icons.badge_outlined,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return context.tr('auth.name_required');
            return null;
          },
        ),
        const SizedBox(height: 18),

        _buildLabel(
            '${context.tr('auth.email')} ${context.tr('auth.optional')}'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _emailController,
          hint: context.tr('auth.email_hint'),
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _buildOtpForm() {
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 56,
      textStyle: GoogleFonts.poppins(
        fontSize: 22,
        color: Colors.black,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(14),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 1.5),
      borderRadius: BorderRadius.circular(14),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.red, width: 1.5),
      borderRadius: BorderRadius.circular(14),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context.tr('auth.otp_code')),
        const SizedBox(height: 16),
        Center(
          child: Pinput(
            length: 6,
            controller: _otpController,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            errorPinTheme: errorPinTheme,
            keyboardType: TextInputType.number,
            showCursor: true,
            onCompleted: (pin) {
              if (!_isLoading) {
                _handleVerifyOtp();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
  );

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade400,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.red.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    Widget? prefixWidget,
    bool obscure = false,
    Widget? suffixWidget,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: GoogleFonts.poppins(fontSize: 15, color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
        prefixIcon: prefixWidget ?? (icon != null ? Icon(icon, color: Colors.grey[500], size: 20) : null),
        suffixIcon: suffixWidget,
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}
