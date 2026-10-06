import '../../../../core/network/media_url.dart';

class BannerImageDto {
  final int id;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final String? descriptionEn;
  final String? descriptionMm;
  final String? descriptionTh;
  final String imageUrl;
  final String? link;
  final String position;
  final String status;
  final int displayOrder;

  BannerImageDto({
    required this.id,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.descriptionEn,
    this.descriptionMm,
    this.descriptionTh,
    required this.imageUrl,
    this.link,
    required this.position,
    required this.status,
    this.displayOrder = 0,
  });

  /// Backward-compatible alias used by [HomePage].
  String get image => imageUrl;

  factory BannerImageDto.fromJson(Map<String, dynamic> json) {
    final rawImage =
        json['imageUrl']?.toString() ?? json['image']?.toString() ?? '';
    return BannerImageDto(
      id: (json['id'] as num).toInt(),
      nameEn: json['nameEn']?.toString(),
      nameMm: json['nameMm']?.toString(),
      nameTh: json['nameTh']?.toString(),
      descriptionEn: json['descriptionEn']?.toString(),
      descriptionMm: json['descriptionMm']?.toString(),
      descriptionTh: json['descriptionTh']?.toString(),
      imageUrl: resolveMediaUrl(rawImage),
      link: json['link']?.toString(),
      position: json['position']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameEn': nameEn,
      'nameMm': nameMm,
      'nameTh': nameTh,
      'descriptionEn': descriptionEn,
      'descriptionMm': descriptionMm,
      'descriptionTh': descriptionTh,
      'imageUrl': imageUrl,
      'link': link,
      'position': position,
      'status': status,
      'displayOrder': displayOrder,
    };
  }
}
