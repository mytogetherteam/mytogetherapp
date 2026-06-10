import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mytogetherapp/core/presentation/widgets/local_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/features/auth/data/repositories/auth_repository.dart';
import 'package:mytogetherapp/features/reviews/presentation/widgets/image_upload_bottom_sheet.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _currentAvatarUrl = user?.avatarUrl;
  }

  String _resolveAvatarUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${ApiClient.baseUrl}/$path';
  }

  Future<void> _pickAvatar() async {
    final action = await ImageUploadBottomSheet.show(context);
    if (action == null) return;

    final source = action == ImageUploadAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (picked != null) {
        setState(() => _pickedImage = picked);
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showToast(context, context.tr('auth.could_not_pick_image'), isError: true);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    try {
      // Profile fields and the optional new photo are sent in a single
      // multipart request (backend: PUT /api/user/profile, field `profilePhoto`).
      await AuthRepository.instance.updateProfile(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        profilePhoto: _pickedImage,
      );
      if (mounted) {
        AppDialog.showToast(context, context.tr('auth.profile_updated'));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showToast(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          context.tr('profile.edit_profile'),
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  _buildAvatarPicker(),
                  const SizedBox(height: 28),
                  _buildField(
                    controller: _nameController,
                    label: context.tr('auth.full_name'),
                    icon: PhosphorIcons.userBold,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.tr('auth.name_required')
                        : null,
                  ),
                  _buildField(
                    controller: _usernameController,
                    label: context.tr('auth.username'),
                    icon: PhosphorIcons.at,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.tr('auth.username_required')
                        : null,
                  ),
                  _buildField(
                    controller: _phoneController,
                    label: context.tr('auth.phone'),
                    icon: PhosphorIcons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  _buildField(
                    controller: _addressController,
                    label: context.tr('auth.address'),
                    icon: PhosphorIcons.mapPin,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    ImageProvider? avatarImage;
    if (_pickedImage != null) {
      avatarImage = localImageProvider(_pickedImage!);
    } else if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      avatarImage = CachedNetworkImageProvider(
        _resolveAvatarUrl(_currentAvatarUrl!),
      );
    }

    return Center(
      child: GestureDetector(
        onTap: _isSaving ? null : _pickAvatar,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Icon(PhosphorIcons.userBold, size: 40, color: Colors.grey[400])
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFFF96232)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: PrimaryGradientButton(
            onPressed: _isSaving ? null : _save,
            isLoading: _isSaving,
            child: Text(
              context.tr('auth.save_changes'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            maxLines: maxLines,
            textAlignVertical: TextAlignVertical.top,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              hintText: context.trArgs('common.enter_label', {'label': label}),
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.red.shade300),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
