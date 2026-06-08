import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
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
          _isConfirmed
              ? context.tr('order_confirm.title_confirmed')
              : context.tr('order_confirm.title_waiting'),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const SizedBox(height: 24),
        if (!_isConfirmed) ...[
          const CustomLoadingIndicator(size: 24),
          const SizedBox(height: 24),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _isConfirmed
                ? context.tr('order_confirm.body_confirmed')
                : context.tr('order_confirm.body_waiting'),
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
                    const Icon(Icons.chat_bubble_outline,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('order_confirm.chat'),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Text(
                  context.tr('order_confirm.continue'),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[600],
              side: const BorderSide(color: Colors.black87, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.tr('order_confirm.check_status'),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: _isConfirmed
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: context.tr('order_confirm.footer_prefix'),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                      children: [
                        TextSpan(
                          text: context.tr('order_confirm.footer_link'),
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
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
