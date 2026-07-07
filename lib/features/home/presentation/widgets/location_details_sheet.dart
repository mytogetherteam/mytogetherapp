import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../auth/data/models/user_location_model.dart';

class LocationDetailsSheet extends StatefulWidget {
  final UserLocationModel location;
  final Function(UserLocationModel) onSave;
  final bool isEdit;
  final bool allowDismiss;

  const LocationDetailsSheet({
    super.key,
    required this.location,
    required this.onSave,
    this.isEdit = false,
    this.allowDismiss = true,
  });

  @override
  State<LocationDetailsSheet> createState() => _LocationDetailsSheetState();
}

class _LocationDetailsSheetState extends State<LocationDetailsSheet> {
  late TextEditingController _buildingController;
  late TextEditingController _floorController;
  late TextEditingController _noteController;
  late TextEditingController _postalController;
  late String _selectedType;

  final List<String> _types = ['HOME', 'WORK', 'OTHER'];

  @override
  void initState() {
    super.initState();
    _buildingController = TextEditingController(text: widget.location.buildingName);
    _floorController = TextEditingController(text: widget.location.floor);
    _noteController = TextEditingController(text: widget.location.note);
    _postalController = TextEditingController(text: widget.location.postalCode);
    _selectedType = _types.contains(widget.location.locationType)
        ? widget.location.locationType!
        : 'OTHER';
  }

  @override
  void dispose() {
    _buildingController.dispose();
    _floorController.dispose();
    _noteController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final address = widget.location.streetAddress;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isEdit
                        ? context.tr('location.edit')
                        : context.tr('location.create'),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (widget.allowDismiss)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  PhosphorIconsFill.mapPin,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    address ?? context.tr('location.unspecified_address'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildLabel(context.tr('location.type')),
            const SizedBox(height: 8),
            Row(
              children: _types.map((type) => _buildTypeChip(type)).toList(),
            ),
            const SizedBox(height: 20),
            _buildLabel(context.tr('location.building_details')),
            _buildTextField(
              controller: _buildingController,
              hint: context.tr('location.building_hint'),
              icon: PhosphorIcons.buildings,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _floorController,
                    hint: context.tr('location.floor_unit'),
                    icon: PhosphorIcons.stairs,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _postalController,
                    hint: context.tr('location.postal_code'),
                    icon: PhosphorIcons.envelope,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLabel(context.tr('location.extra_note')),
            _buildTextField(
              controller: _noteController,
              hint: context.tr('location.note_hint'),
              icon: PhosphorIcons.note,
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            PrimaryGradientButton(
              onPressed: () {
                if (address == null || address.isEmpty) {
                  return;
                }
                final updated = widget.location.copyWith(
                  clearLocationName: true,
                  locationType: _selectedType,
                  buildingName: _buildingController.text.trim().isNotEmpty
                      ? _buildingController.text.trim()
                      : null,
                  floor: _floorController.text.trim().isNotEmpty
                      ? _floorController.text.trim()
                      : null,
                  note: _noteController.text.trim().isNotEmpty
                      ? _noteController.text.trim()
                      : null,
                  postalCode: _postalController.text.trim().isNotEmpty
                      ? _postalController.text.trim()
                      : null,
                );
                Navigator.pop(context);
                widget.onSave(updated);
              },
              child: Text(
                widget.isEdit
                    ? context.tr('location.update')
                    : context.tr('location.create'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    final isSelected = _selectedType == type;
    IconData icon;
    switch (type) {
      case 'HOME':
        icon = PhosphorIcons.house;
        break;
      case 'WORK':
        icon = PhosphorIcons.briefcase;
        break;
      default:
        icon = PhosphorIcons.mapPin;
        break;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () => setState(() => _selectedType = type),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.primary : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  type,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
