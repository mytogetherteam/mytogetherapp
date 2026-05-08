import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/theme/app_colors.dart';

class OrderConfirmedModal extends StatefulWidget {
  const OrderConfirmedModal({super.key});

  @override
  State<OrderConfirmedModal> createState() => _OrderConfirmedModalState();
}

class _OrderConfirmedModalState extends State<OrderConfirmedModal> {
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isConfirmed = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _isConfirmed ? 'Order Confirmed' : 'Waiting for Order Confirmation',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const SizedBox(height: 24),
        // Loading indicator
        if (!_isConfirmed) ...[
          const CustomLoadingIndicator(size: 24),
          const SizedBox(height: 24),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _isConfirmed
                ? 'Your order is confirmed, and the restaurant\n will prepare your food.'
                : 'Your order is awaiting confirmation from the restaurant. You\'ll be notified once your order is confirmed',
            key: ValueKey<bool>(_isConfirmed),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        // Primary Button
        PrimaryGradientButton(
          onPressed: () {
            if (_isConfirmed) {
              // Action for Chat
            } else {
              Navigator.pop(context);
            }
          },
          child: _isConfirmed
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Chat with Restaurant',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Continue Order',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        // Check Order Status Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[600], // Changes text & ripple overlay color to gray
              side: const BorderSide(color: Colors.black87, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Check Order Status',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        
        // Footer Text
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: _isConfirmed
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: 'You can continue next order ',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                      children: [
                        TextSpan(
                          text: 'here.',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary, // Primary color as requested
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
