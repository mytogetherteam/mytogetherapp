import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/utils/firebase_error_handler.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'reset_pin_page.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String phone;

  const ForgotPasswordPage({super.key, required this.phone});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _verificationId;
  
  Timer? _resendTimer;
  int _resendSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    // Start OTP flow immediately for the passed phone number
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendOtp();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendSecondsRemaining = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendSecondsRemaining > 0) {
          setState(() => _resendSecondsRemaining--);
        } else {
          _resendTimer?.cancel();
        }
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _verifyWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          final msg = FirebaseErrorHandler.getMessage(context, e);
          AppDialog.showToast(context, msg, isError: true);
          setState(() => _isLoading = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
          });
          _startResendTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;
      AppDialog.showToast(context, e.toString(), isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_verificationId == null || _otpController.text.isEmpty) {
      AppDialog.showToast(context, context.tr('auth.enter_otp'), isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await _verifyWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = FirebaseErrorHandler.getMessage(context, e);
      AppDialog.showToast(context, msg, isError: true);
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      AppDialog.showToast(context, e.toString(), isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();

      if (idToken == null) throw Exception("Failed to get Firebase ID token");

      if (!mounted) return;
      setState(() => _isLoading = false);
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResetPinPage(
            phone: widget.phone,
            idToken: idToken,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = FirebaseErrorHandler.getMessage(context, e);
      AppDialog.showToast(context, msg, isError: true);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              GradientText(
                context.tr('auth.forgot_passcode') != 'auth.forgot_passcode' 
                    ? context.tr('auth.forgot_passcode') 
                    : 'Forgot Passcode',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We have sent a verification code to ${widget.phone}.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
              
              Center(
                child: Pinput(
                  length: 6,
                  controller: _otpController,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  keyboardType: TextInputType.number,
                  showCursor: true,
                  onCompleted: (pin) {
                    if (!_isLoading) _handleVerifyOtp();
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _resendSecondsRemaining > 0
                      ? Text(
                          context.trArgs('auth.resend_in', {'seconds': '$_resendSecondsRemaining'}),
                          key: const ValueKey('countdown'),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : TextButton(
                          key: const ValueKey('resend_btn'),
                          onPressed: _isLoading ? null : _sendOtp,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                          child: Text(
                            context.tr('auth.resend_code'),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                ),
              ),
              
              const Spacer(),
              PrimaryGradientButton(
                onPressed: _isLoading ? null : _handleVerifyOtp,
                isLoading: _isLoading,
                child: Text(
                  'Verify & Continue',
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
    );
  }
}
