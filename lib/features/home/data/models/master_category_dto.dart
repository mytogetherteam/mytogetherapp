import '../../../../core/utils/image_utils.dart';

/// A popular master menu category returned by
/// `GET /api/user/master-menu-categories/popular`.
class MasterCategoryDto {
  final int id;
  final String nameEn;
  final String? nameMm;
  final String? nameTh;
  final String? imageUrl;
  final int? displayOrder;
  final int orderCount;

  MasterCategoryDto({
    required this.id,
    required this.nameEn,
    this.nameMm,
    this.nameTh,
    this.imageUrl,
    this.displayOrder,
    this.orderCount = 0,
  });

  String get displayName => nameEn.isNotEmpty ? nameEn : (nameMm ?? nameTh ?? 'Category');

  factory MasterCategoryDto.fromJson(Map<String, dynamic> json) {
    return MasterCategoryDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nameEn: json['nameEn']?.toString() ?? '',
      nameMm: json['nameMm']?.toString(),
      nameTh: json['nameTh']?.toString(),
      imageUrl: ImageUtils.cleanImageUrl(json['imageUrl']),
      displayOrder: (json['displayOrder'] as num?)?.toInt(),
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
    );
  }
}
