import '../../../../core/utils/image_utils.dart';
import '../../../../core/localization/locale_controller.dart';

/// Master menu category from
/// `GET /api/user/master-menu-categories/popular` (user-visible catalog).
class MasterCategoryDto {
  final int id;
  final String nameEn;
  final String? nameMm;
  final String? nameTh;
  final String? imageUrl;
  final int? displayOrder;
  final int orderCount;
  final bool isActive;

  MasterCategoryDto({
    required this.id,
    required this.nameEn,
    this.nameMm,
    this.nameTh,
    this.imageUrl,
    this.displayOrder,
    this.orderCount = 0,
    this.isActive = true,
  });

  String get displayName {
    final name = LocaleController.instance
        .localized(en: nameEn, mm: nameMm, th: nameTh);
    return name.isNotEmpty ? name : 'Category';
  }

  factory MasterCategoryDto.fromJson(Map<String, dynamic> json) {
    return MasterCategoryDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nameEn: json['nameEn']?.toString() ?? '',
      nameMm: json['nameMm']?.toString(),
      nameTh: json['nameTh']?.toString(),
      imageUrl: ImageUtils.cleanImageUrl(json['imageUrl']),
      displayOrder: (json['displayOrder'] as num?)?.toInt(),
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] != false,
    );
  }
}
