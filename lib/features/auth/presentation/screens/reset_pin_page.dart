import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/utils/firebase_error_handler.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import 'package:flutter/services.dart';
import 'login_pin_page.dart';

class ResetPinPage extends StatefulWidget {
  final String phone;
  final String idToken;

  const ResetPinPage({super.key, required this.phone, required this.idToken});

  @override
  State<ResetPinPage> createState() => _ResetPinPageState();
}

class _ResetPinPageState extends State<ResetPinPage>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;
  bool _hasError = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPress(String digit) {
    String currentPin = _isConfirming ? _confirmPin : _pin;
    
    if (currentPin.length < 6 && !_isLoading) {
      HapticFeedback.lightImpact();
      setState(() {
        if (_isConfirming) {
          _confirmPin += digit;
        } else {
          _pin += digit;
        }
        _hasError = false;
      });

      if (_isConfirming && _confirmPin.length == 6) {
        _submitPin();
      } else if (!_isConfirming && _pin.length == 6) {
        // Proceed to confirm step
        setState(() {
          _isConfirming = true;
        });
      }
    }
  }

  void _onDeletePress() {
    if (!_isLoading) {
      HapticFeedback.lightImpact();
      setState(() {
        if (_isConfirming) {
          if (_confirmPin.isNotEmpty) {
            _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          } else {
            // Go back to step 1
            _isConfirming = false;
            _pin = '';
          }
        } else {
          if (_pin.isNotEmpty) {
            _pin = _pin.substring(0, _pin.length - 1);
          }
        }
        _hasError = false;
      });
    }
  }

  Future<void> _submitPin() async {
    if (_pin != _confirmPin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
        _confirmPin = '';
      });
      await _shakeController.forward(from: 0);
      if (mounted) {
        AppDialog.showToast(context, 'Passcodes do not match', isError: true);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthRepository.instance.resetPassword(
        phone: widget.phone,
        idToken: widget.idToken,
        newPin: _pin,
      );
      if (!mounted) return;
      
      AppDialog.showToast(context, 'Passcode successfully reset!');
      
      // Go back to LoginPinPage to login with new pin
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginPinPage(phone: widget.phone),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
        _isLoading = false;
        _confirmPin = ''; // Clear confirm PIN on error
      });
      await _shakeController.forward(from: 0);
      
      if (!mounted) return;
      AppDialog.showToast(context, FirebaseErrorHandler.getMessage(context, e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentPin = _isConfirming ? _confirmPin : _pin;
    String titleText = _isConfirming ? 'Confirm New Passcode' : 'Create New Passcode';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (_isConfirming) {
              setState(() {
                _isConfirming = false;
                _pin = '';
                _confirmPin = '';
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            GradientText(
              titleText,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please enter a 6-digit PIN.',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = index < currentPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: (isFilled && !_hasError)
                          ? AppColors.primaryGradient
                          : null,
                      color: isFilled
                          ? (_hasError ? Colors.red : null)
                          : Colors.transparent,
                      border: Border.all(
                        color: isFilled
                            ? (_hasError ? Colors.red : AppColors.primary)
                            : Colors.grey[400]!,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            const SizedBox(height: 60),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: CustomLoadingIndicator(size: 32),
              )
            else
              const SizedBox(height: 56),

            const Spacer(),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Column(
                children: [
                  _buildNumpadRow(['1', '2', '3']),
                  const SizedBox(height: 24),
                  _buildNumpadRow(['4', '5', '6']),
                  const SizedBox(height: 24),
                  _buildNumpadRow(['7', '8', '9']),
                  const SizedBox(height: 24),
                  _buildNumpadRow(['', '0', 'delete']),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> items) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items.map((item) {
        if (item.isEmpty) {
          return const SizedBox(width: 80, height: 80);
        } else if (item == 'delete') {
          return SizedBox(
            width: 80,
            height: 80,
            child: IconButton(
              onPressed: _onDeletePress,
              icon: Icon(
                Icons.backspace_rounded,
                color: Colors.grey[700],
                size: 28,
              ),
              splashRadius: 40,
            ),
          );
        } else {
          return _buildNumpadButton(item);
        }
      }).toList(),
    );
  }

  Widget _buildNumpadButton(String digit) {
    return GestureDetector(
      onTap: () => _onDigitPress(digit),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.08),
        ),
        child: Center(
          child: GradientText(
            digit,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
