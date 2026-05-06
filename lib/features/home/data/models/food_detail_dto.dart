import '../../../../core/utils/image_utils.dart';
import 'shop_dto.dart';

class ApiResponseFoodDetailDto {
  final int statusCode;
  final String? message;
  final FoodDetailDto? data;

  ApiResponseFoodDetailDto({
    required this.statusCode,
    this.message,
    this.data,
  });

  factory ApiResponseFoodDetailDto.fromJson(Map<String, dynamic> json) {
    return ApiResponseFoodDetailDto(
      statusCode: json['statusCode'] ?? 0,
      message: json['message'],
      data: json['data'] != null ? FoodDetailDto.fromJson(json['data']) : null,
    );
  }
}

class FoodDetailDto {
  final int id;
  final int? shopId;
  final String? shopName;
  final String name;
  final String? nameMm;
  final String? description;
  final double price;
  final double? originalPrice;
  final String currency;
  final String imageUrl;
  final List<String> photoUrls;
  final List<MenuItemVariantDto> variants;
  final List<MenuItemOptionGroupDto> optionGroups;
  final bool isFavorite;

  final CuisineTypeDto? cuisineType;

  FoodDetailDto({
    required this.id,
    this.shopId,
    this.shopName,
    required this.name,
    this.nameMm,
    this.description,
    required this.price,
    this.originalPrice,
    this.currency = '฿',
    required this.imageUrl,
    this.photoUrls = const [],
    this.variants = const [],
    this.optionGroups = const [],
    required this.isFavorite,
    this.cuisineType,
  });

  factory FoodDetailDto.fromJson(Map<String, dynamic> json) {
    return FoodDetailDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      shopId: json['shopId'],
      shopName: json['shopName'] as String? ?? json['shopNameEn'] as String? ?? json['shopNameMm'] as String?,
      name: json['name'] as String? ?? json['nameEn'] as String? ?? json['nameMm'] as String? ?? '',
      nameMm: json['nameMm'] as String?,
      description: json['description'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: json['originalPrice'] != null ? (json['originalPrice'] as num).toDouble() : null,
      currency: json['currency'] as String? ?? '฿',
      imageUrl: ImageUtils.cleanImageUrl(json['imageUrl']) ?? '',
      cuisineType: json['cuisineType'] != null ? CuisineTypeDto.fromJson(json['cuisineType']) : null,
      photoUrls: (json['photos'] as List? ?? [])
          .map((e) {
            if (e is Map) return ImageUtils.cleanImageUrl(e['url']?.toString());
            return ImageUtils.cleanImageUrl(e.toString());
          })
          .whereType<String>()
          .toList(),
      variants: (json['variants'] as List? ?? [])
          .where((e) => e != null)
          .map((e) => MenuItemVariantDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      optionGroups: (json['optionGroups'] as List? ?? [])
          .where((e) => e != null)
          .map((e) => MenuItemOptionGroupDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      isFavorite: json['isFavorite'] ?? false,
    );
  }
}

class MenuItemVariantDto {
  final int id;
  final String name;
  final String? nameMm;
  final double price;
  final String? displayPrice;
  final bool isAvailable;

  MenuItemVariantDto({
    required this.id,
    required this.name,
    this.nameMm,
    required this.price,
    this.displayPrice,
    this.isAvailable = true,
  });

  factory MenuItemVariantDto.fromJson(Map<String, dynamic> json) {
    return MenuItemVariantDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['nameEn'] as String? ?? json['name'] as String? ?? '',
      nameMm: json['nameMm'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      displayPrice: json['displayPrice'] as String?,
      isAvailable: json['isAvailable'] ?? true,
    );
  }
}

class MenuItemOptionGroupDto {
  final int id;
  final String name;
  final String? nameMm;
  final String groupType; // SINGLE_SELECT, MULTI_SELECT
  final bool isRequired;
  final int minSelection;
  final int maxSelection;
  final List<MenuItemOptionDto> options;

  MenuItemOptionGroupDto({
    required this.id,
    required this.name,
    this.nameMm,
    required this.groupType,
    this.isRequired = false,
    this.minSelection = 0,
    this.maxSelection = 0,
    required this.options,
  });

  factory MenuItemOptionGroupDto.fromJson(Map<String, dynamic> json) {
    return MenuItemOptionGroupDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['nameEn'] as String? ?? json['name'] as String? ?? '',
      nameMm: json['nameMm'] as String?,
      groupType: json['groupType'] ?? 'MULTI_SELECT',
      isRequired: json['isRequired'] ?? false,
      minSelection: json['minSelection'] ?? 0,
      maxSelection: json['maxSelection'] ?? 0,
      options: (json['options'] as List? ?? [])
          .where((e) => e != null)
          .map((e) => MenuItemOptionDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class MenuItemOptionDto {
  final int id;
  final String name;
  final String? nameMm;
  final double price;
  final String? displayPrice;

  MenuItemOptionDto({
    required this.id,
    required this.name,
    this.nameMm,
    required this.price,
    this.displayPrice,
  });

  factory MenuItemOptionDto.fromJson(Map<String, dynamic> json) {
    return MenuItemOptionDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['nameEn'] as String? ?? json['name'] as String? ?? '',
      nameMm: json['nameMm'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      displayPrice: json['displayPrice'] as String?,
    );
  }
}
