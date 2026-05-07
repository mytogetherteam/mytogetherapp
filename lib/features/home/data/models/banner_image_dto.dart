import '../../../../core/utils/image_utils.dart';

class BannerImageDto {
  final int id;
  final String image;
  final String? link;
  final String position;
  final String status;

  BannerImageDto({
    required this.id,
    required this.image,
    this.link,
    required this.position,
    required this.status,
  });

  factory BannerImageDto.fromJson(Map<String, dynamic> json) {
    return BannerImageDto(
      id: json['id'],
      image: ImageUtils.cleanImageUrl(json['image']) ?? '',
      link: json['link'],
      position: json['position'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image': image,
      'link': link,
      'position': position,
      'status': status,
    };
  }
}
