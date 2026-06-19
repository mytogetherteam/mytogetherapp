import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';

/// Bottom panel for map pin screens: required street-address field + confirm.
class MapPickerAddressPanel extends StatelessWidget {
  final TextEditingController addressController;
  final bool isGeocoding;
  final bool isMapMoving;
  final bool isSaving;
  final bool canConfirmBase;
  final String? addressError;
  final VoidCallback onConfirm;
  final VoidCallback onAddressChanged;

  const MapPickerAddressPanel({
    super.key,
    required this.addressController,
    required this.isGeocoding,
    required this.isMapMoving,
    required this.isSaving,
    required this.canConfirmBase,
    this.addressError,
    required this.onConfirm,
    required this.onAddressChanged,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = addressController.text.trim();
    final canConfirm = canConfirmBase &&
        !isMapMoving &&
        !isSaving &&
        trimmed.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('location.map_picker_hint'),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('location.street_address'),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: addressController,
            onChanged: (_) => onAddressChanged(),
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.done,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: context.tr('location.street_address_hint'),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              prefixIcon: isGeocoding && !isMapMoving
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CustomLoadingIndicator(size: 18),
                      ),
                    )
                  : Icon(
                      PhosphorIconsFill.mapPin,
                      color: AppColors.primary,
                      size: 18,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: addressError != null
                      ? Colors.red.shade300
                      : Colors.transparent,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: addressError != null
                      ? Colors.red.shade400
                      : AppColors.primary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
          if (addressError != null) ...[
            const SizedBox(height: 6),
            Text(
              addressError!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryGradientButton(
            onPressed: canConfirm ? onConfirm : null,
            isLoading: isSaving,
            child: Text(
              context.tr('location.confirm_location'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
