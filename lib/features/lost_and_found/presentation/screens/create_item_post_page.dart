import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/location/location_service.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import '../../data/models/item_post_dto.dart';
import '../../data/repositories/item_post_repository.dart';
import '../../../reviews/presentation/widgets/image_upload_bottom_sheet.dart';

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
  final List<File> _photos = [];
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
          _photos.add(File(file.path));
        }
      } else {
        final picked = await _picker.pickImage(
          source: source,
          imageQuality: 85,
        );
        if (picked != null && _totalPhotoCount < 10) {
          _photos.add(File(picked.path));
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

  Widget _photoThumb({required Widget child, required VoidCallback onRemove}) {
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          context.tr(_isEditing ? 'lost.edit_title' : 'lost.create_title'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'LOST',
                  label: Text(context.tr('lost.type_lost')),
                ),
                ButtonSegment(
                  value: 'FOUND',
                  label: Text(context.tr('lost.type_found')),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) {
                setState(() => _type = value.first);
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: context.tr('lost.description'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('lost.description_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: context.tr('lost.location_name'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: context.tr('lost.phone_number'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  context.trArgs('lost.photos_count', {
                    'count': '$_totalPhotoCount',
                  }),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(context.tr('lost.add')),
                ),
              ],
            ),
            if (_existingPhotos.isNotEmpty || _photos.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var index = 0; index < _existingPhotos.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _photoThumb(
                          child: CachedNetworkImage(
                            imageUrl: _existingPhotos[index].url,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                          onRemove: () => _removeExistingPhoto(index),
                        ),
                      ),
                    for (var index = 0; index < _photos.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _photoThumb(
                          child: Image.file(
                            _photos[index],
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                          onRemove: () =>
                              setState(() => _photos.removeAt(index)),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            PrimaryGradientButton(
              onPressed: _isSubmitting ? null : _submit,
              isLoading: _isSubmitting,
              child: Text(
                context.tr(_isEditing ? 'lost.save' : 'lost.publish'),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
