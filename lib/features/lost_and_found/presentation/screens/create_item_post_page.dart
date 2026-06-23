import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/media/picked_image.dart';
import 'package:mytogetherapp/core/location/location_service.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
// ignore: unused_import
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import '../../data/models/item_post_dto.dart';
import '../../data/repositories/item_post_repository.dart';
import '../../../reviews/presentation/widgets/image_upload_bottom_sheet.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';

class CreateItemPostPage extends StatefulWidget {
  /// When provided, the page edits this post instead of creating a new one.
  final ItemPostDto? existingPost;

  const CreateItemPostPage({super.key, this.existingPost});

  @override
  State<CreateItemPostPage> createState() => _CreateItemPostPageState();
}

class _CreateItemPostPageState extends State<CreateItemPostPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _picker = ImagePicker();

  String _type = 'LOST';
  bool _isSubmitting = false;
  final List<PickedImage> _photos = [];
  // Existing (already-uploaded) photos when editing, and ids to remove.
  final List<ItemPostPhotoDto> _existingPhotos = [];
  final List<int> _removePhotoIds = [];
  double? _latitude;
  double? _longitude;

  bool get _isEditing => widget.existingPost != null;

  int get _totalPhotoCount => _existingPhotos.length + _photos.length;

  @override
  void initState() {
    super.initState();
    final post = widget.existingPost;
    if (post != null) {
      _type = post.type;
      _descriptionController.text = post.description;
      _locationController.text = post.locationName ?? '';
      _phoneController.text = post.phoneNumber ?? '';
      _latitude = post.latitude;
      _longitude = post.longitude;
      _existingPhotos.addAll(post.photos);
    } else {
      _loadLocation();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await LocationService().getCurrentPosition();
      _latitude = pos.latitude;
      _longitude = pos.longitude;
      final address = LocationService().currentAddress;
      if (address != null && _locationController.text.isEmpty) {
        _locationController.text = address.split(',').first;
      }
    } catch (_) {}
  }

  Future<void> _pickPhotos() async {
    if (_totalPhotoCount >= 10) {
      AppDialog.showToast(context, context.tr('lost.max_photos'), isError: true);
      return;
    }

    final action = await ImageUploadBottomSheet.show(context);
    if (action == null) return;

    final source = action == ImageUploadAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    try {
      if (source == ImageSource.gallery) {
        final picked = await _picker.pickMultiImage(imageQuality: 85);
        for (final file in picked) {
          if (_totalPhotoCount >= 10) break;
          _photos.add(await PickedImage.fromXFile(file));
        }
      } else {
        final picked = await _picker.pickImage(
          source: source,
          imageQuality: 85,
        );
        if (picked != null && _totalPhotoCount < 10) {
          _photos.add(await PickedImage.fromXFile(picked));
        }
      }
      setState(() {});
    } catch (_) {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('lost.pick_failed'),
          isError: true,
        );
      }
    }
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Select Category',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(PhosphorIcons.magnifyingGlass, color: Colors.orange),
              title: Text(context.tr('lost.type_lost'), style: GoogleFonts.notoSansMyanmar()),
              trailing: _type == 'LOST' ? Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                setState(() => _type = 'LOST');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(PhosphorIcons.checkCircle, color: Colors.green),
              title: Text(context.tr('lost.type_found'), style: GoogleFonts.notoSansMyanmar()),
              trailing: _type == 'FOUND' ? Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                setState(() => _type = 'FOUND');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final locationName = _locationController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    try {
      if (_isEditing) {
        await ItemPostRepository.instance.update(
          widget.existingPost!.id,
          description: _descriptionController.text.trim(),
          type: _type,
          latitude: _latitude,
          longitude: _longitude,
          locationName: locationName,
          phoneNumber: phoneNumber,
          photos: _photos,
          removePhotoIds: _removePhotoIds,
        );
      } else {
        await ItemPostRepository.instance.create(
          description: _descriptionController.text.trim(),
          type: _type,
          latitude: _latitude,
          longitude: _longitude,
          locationName: locationName.isEmpty ? null : locationName,
          phoneNumber: phoneNumber.isEmpty ? null : phoneNumber,
          photos: _photos,
        );
      }
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr(_isEditing ? 'lost.updated' : 'lost.created'),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr(_isEditing ? 'lost.update_failed' : 'lost.create_failed'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _removeExistingPhoto(int index) {
    setState(() {
      _removePhotoIds.add(_existingPhotos[index].id);
      _existingPhotos.removeAt(index);
    });
  }

  Widget _photoThumb({required Widget child, required VoidCallback onRemove, double? width, double? height}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: width, height: height, child: child),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoGrid() {
    final allPhotos = <Widget>[
      for (var i = 0; i < _existingPhotos.length; i++)
        _photoThumb(
          child: CachedNetworkImage(
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            imageUrl: _existingPhotos[i].url,
            fit: BoxFit.cover,
          ),
          onRemove: () => _removeExistingPhoto(i),
        ),
      for (var i = 0; i < _photos.length; i++)
        _photoThumb(
          child: Image.memory(_photos[i].bytes, fit: BoxFit.cover),
          onRemove: () => setState(() => _photos.removeAt(i)),
        ),
    ];

    final count = allPhotos.length;
    const maxShow = 5;
    const h = 260.0;
    // ignore: unused_local_variable
    final screenW = MediaQuery.of(context).size.width - 32;

    if (count == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: h,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              allPhotos[0],
              Positioned(
                top: 4, right: 4,
                child: GestureDetector(
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (count == 2) {
      return SizedBox(
        height: h,
        child: Row(
          children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: h, child: allPhotos[0]))),
            const SizedBox(width: 4),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: h, child: allPhotos[1]))),
          ],
        ),
      );
    }

    if (count == 3) {
      return SizedBox(
        height: h,
        child: Row(
          children: [
            Expanded(flex: 2, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: h, child: allPhotos[0]))),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: double.infinity, child: allPhotos[1]))),
                  const SizedBox(height: 4),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: double.infinity, child: allPhotos[2]))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4+ photos
    final showPhotos = allPhotos.take(maxShow).toList();
    final remaining = count - maxShow;
    return Column(
      children: [
        SizedBox(
          height: h / 2 - 2,
          child: Row(
            children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: double.infinity, child: showPhotos[0]))),
              const SizedBox(width: 4),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: double.infinity, child: showPhotos[1]))),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: h / 2 - 2,
          child: Row(
            children: [
              for (var i = 2; i < showPhotos.length; i++) ...[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        showPhotos[i],
                        if (i == showPhotos.length - 1 && remaining > 0)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '+$remaining',
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (i < showPhotos.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService().currentUser;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          context.tr(_isEditing ? 'lost.edit_title' : 'lost.create_title'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : ShaderMask(
                      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                      child: Text(
                        context.tr(_isEditing ? 'lost.save' : 'lost.publish'),
                        style: GoogleFonts.notoSansMyanmar(
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // Color is masked by ShaderMask
                          fontSize: 16,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: currentUser?.avatarUrl != null ? CachedNetworkImageProvider(currentUser!.avatarUrl!) : null,
                  child: currentUser?.avatarUrl == null ? Icon(PhosphorIcons.user, color: Colors.grey[500], size: 28) : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser?.fullName ?? context.tr('news.you'),
                      style: GoogleFonts.notoSansMyanmar(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _showCategoryPicker,
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _type == 'LOST' ? context.tr('lost.type_lost') : context.tr('lost.type_found'),
                              style: GoogleFonts.notoSansMyanmar(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: null,
              minLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: context.tr('lost.description'),
                hintStyle: GoogleFonts.notoSansMyanmar(color: Colors.grey[400], fontSize: 18),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: "",
              ),
              style: GoogleFonts.notoSansMyanmar(fontSize: 18),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('lost.description_required');
                }
                return null;
              },
            ),
            if (_existingPhotos.isNotEmpty || _photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _buildPhotoGrid(),
              ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(PhosphorIcons.mapPinFill, color: Colors.red[400], size: 28),
                title: TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: context.tr('lost.location_name'),
                    hintStyle: GoogleFonts.notoSansMyanmar(color: Colors.grey[400]),
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.notoSansMyanmar(),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(PhosphorIcons.phoneCallFill, color: Colors.blue[400], size: 28),
                title: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: context.tr('lost.phone_number'),
                    hintStyle: GoogleFonts.notoSansMyanmar(color: Colors.grey[400]),
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.notoSansMyanmar(),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: _pickPhotos,
                leading: Icon(PhosphorIcons.imageFill, color: Colors.green[500], size: 28),
                title: Text(
                  context.tr('lost.add'),
                  style: GoogleFonts.notoSansMyanmar(color: Colors.black87),
                ),
                trailing: Text(
                  '$_totalPhotoCount/10',
                  style: GoogleFonts.notoSansMyanmar(color: Colors.grey[500]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

