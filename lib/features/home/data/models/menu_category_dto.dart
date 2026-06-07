import '../../../../core/utils/image_utils.dart';
import '../../../../core/localization/locale_controller.dart';

/// A shop's menu category returned by
/// `GET /api/user/menu-categories?shopId=...`. Used to group the menu items on
/// the restaurant detail page into category sections (ordered by
/// [displayOrder]).
class MenuCategoryDto {
  final int id;
  final String nameEn;
  final String? nameMm;
  final String? nameTh;
  final String? imageUrl;
  final int? displayOrder;
  final int itemCount;
  final int? masterCategoryId;

  MenuCategoryDto({
    required this.id,
    required this.nameEn,
    this.nameMm,
    this.nameTh,
    this.imageUrl,
    this.displayOrder,
    this.itemCount = 0,
    this.masterCategoryId,
  });

  /// Resolved live against the active language so a language switch updates
  /// already-loaded section headers without a refetch.
  String get displayName {
    final name = LocaleController.instance
        .localized(en: nameEn, mm: nameMm, th: nameTh);
    return name.isNotEmpty ? name : 'Menu';
  }

  factory MenuCategoryDto.fromJson(Map<String, dynamic> json) {
    return MenuCategoryDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nameEn: json['nameEn']?.toString() ?? '',
      nameMm: json['nameMm']?.toString(),
      nameTh: json['nameTh']?.toString(),
      imageUrl: ImageUtils.cleanImageUrl(json['imageUrl']),
      displayOrder: (json['displayOrder'] as num?)?.toInt(),
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      masterCategoryId: (json['masterCategoryId'] as num?)?.toInt(),
    );
  }
}
