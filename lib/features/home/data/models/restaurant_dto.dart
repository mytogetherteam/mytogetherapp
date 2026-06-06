import '../../../../core/localization/locale_controller.dart';

class RestaurantResponseDto {
  final String id;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final String category;
  final double rating;
  final String distance;
  final String image;
  final String logo;
  final String deliveryTime;
  final String status;
  final List<String> imageUrls;

  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  RestaurantResponseDto({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    required this.category,
    required this.rating,
    required this.distance,
    required this.image,
    required this.logo,
    required this.deliveryTime,
    required this.status,
    this.imageUrls = const [],
  }) : _name = name;

  factory RestaurantResponseDto.fromJson(Map<String, dynamic> json) {
    final imageUrlsList = (json['imageUrls'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    
    final imageUrl = json['image'] ?? 
        (imageUrlsList.isNotEmpty ? imageUrlsList.first : '');

    return RestaurantResponseDto(
      id: json['id'] ?? '',
      name: (json['name'] as String? ?? json['nameEn'] as String?) ?? '',
      nameEn: json['nameEn'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      category: json['category'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      distance: json['distance'] ?? '',
      image: imageUrl,
      logo: json['logo'] ?? '',
      deliveryTime: json['deliveryTime'] ?? '',
      status: json['status'] ?? '',
      imageUrls: imageUrlsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'rating': rating,
      'distance': distance,
      'image': image,
      'logo': logo,
      'deliveryTime': deliveryTime,
      'status': status,
    };
  }
}

class RestaurantRequestDto {
  final String? filterCategory;
  final String? searchQuery;

  RestaurantRequestDto({
    this.filterCategory,
    this.searchQuery,
  });

  Map<String, dynamic> toJson() {
    return {
      if (filterCategory != null) 'category': filterCategory,
      if (searchQuery != null) 'q': searchQuery,
    };
  }
}
