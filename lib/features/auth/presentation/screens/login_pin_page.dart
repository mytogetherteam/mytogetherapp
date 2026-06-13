import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import 'package:flutter/services.dart';
import '../../../cart/data/active_order_state.dart';

class LoginPinPage extends StatefulWidget {
  final String phone;

  const LoginPinPage({super.key, required this.phone});

  @override
  State<LoginPinPage> createState() => _LoginPinPageState();
}

class _LoginPinPageState extends State<LoginPinPage>
    with SingleTickerProviderStateMixin {
  String _pin = '';
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

    // Creates a shaking effect by oscillating between -1 and 1
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
    if (_pin.length < 6 && !_isLoading) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin += digit;
        _hasError = false;
      });

      if (_pin.length == 6) {
        _submitPin();
      }
    }
  }

  void _onDeletePress() {
    if (_pin.isNotEmpty && !_isLoading) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _hasError = false;
      });
    }
  }

  Future<void> _submitPin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthRepository.instance.login(
        phone: widget.phone,
        pin: _pin,
      );
      // Seed any ongoing orders for this account from the backend.
      ActiveOrderState.instance.hydrateActiveOrdersFromApi();
      if (!mounted) return;
      // Login successful, go to home
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
      });
      // Play shake animation
      await _shakeController.forward(from: 0);
      
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _pin = ''; // Clear PIN on error
      });
      AppDialog.showToast(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/images/app_icon_small.png',
            height: 40,
            width: 40,
            fit: BoxFit.cover,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Title
            GradientText(
              context.tr('auth.enter_passcode'),
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.phone,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            
            // Indicator Dots with Shake Animation
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
                  final isFilled = index < _pin.length;
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
              const SizedBox(height: 56), // Placeholder for spinner

            const Spacer(),
            
            // Numpad
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
          color: AppColors.primary.withValues(alpha: 0.08), // Primary color with low opacity
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
