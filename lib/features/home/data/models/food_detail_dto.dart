import '../../../../core/utils/image_utils.dart';
import '../../../../core/localization/locale_controller.dart';
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
  final String? _shopName;
  final String? shopNameEn;
  final String? shopNameMm;
  final String? shopNameTh;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
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

  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  String? get shopName {
    if (shopNameEn != null || shopNameMm != null || shopNameTh != null) {
      final v = LocaleController.instance
          .localized(en: shopNameEn, mm: shopNameMm, th: shopNameTh);
      if (v.isNotEmpty) return v;
    }
    return _shopName;
  }

  FoodDetailDto({
    required this.id,
    this.shopId,
    String? shopName,
    this.shopNameEn,
    this.shopNameMm,
    this.shopNameTh,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
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
  })  : _name = name,
        _shopName = shopName;

  factory FoodDetailDto.fromJson(Map<String, dynamic> json) {
    return FoodDetailDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      shopId: json['shopId'],
      shopName: (json['shopName'] as String? ?? json['shopNameEn'] as String?),
      shopNameEn: json['shopNameEn'] as String? ?? json['shopName'] as String?,
      shopNameMm: json['shopNameMm'] as String?,
      shopNameTh: json['shopNameTh'] as String?,
      name: (json['name'] as String? ?? json['nameEn'] as String?) ?? '',
      nameEn: json['nameEn'] as String? ?? json['name'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      description: json['description'],
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      originalPrice: double.tryParse(json['originalPrice']?.toString() ?? '') ?? 0.0,
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
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final double price;
  final String? displayPrice;
  final bool isAvailable;

  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  MenuItemVariantDto({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    required this.price,
    this.displayPrice,
    this.isAvailable = true,
  }) : _name = name;

  factory MenuItemVariantDto.fromJson(Map<String, dynamic> json) {
    return MenuItemVariantDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['nameEn'] as String? ?? json['name'] as String?) ?? '',
      nameEn: json['nameEn'] as String? ?? json['name'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      displayPrice: json['displayPrice'] as String?,
      isAvailable: json['isAvailable'] ?? true,
    );
  }
}

class MenuItemOptionGroupDto {
  final int id;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final String groupType; // SINGLE_SELECT, MULTI_SELECT
  final bool isRequired;
  final int minSelection;
  final int maxSelection;
  final List<MenuItemOptionDto> options;

  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  MenuItemOptionGroupDto({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    required this.groupType,
    this.isRequired = false,
    this.minSelection = 0,
    this.maxSelection = 0,
    required this.options,
  }) : _name = name;

  factory MenuItemOptionGroupDto.fromJson(Map<String, dynamic> json) {
    return MenuItemOptionGroupDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['nameEn'] as String? ?? json['name'] as String?) ?? '',
      nameEn: json['nameEn'] as String? ?? json['name'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
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
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final double price;
  final String? displayPrice;

  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  MenuItemOptionDto({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    required this.price,
    this.displayPrice,
  }) : _name = name;

  factory MenuItemOptionDto.fromJson(Map<String, dynamic> json) {
    return MenuItemOptionDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['nameEn'] as String? ?? json['name'] as String?) ?? '',
      nameEn: json['nameEn'] as String? ?? json['name'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      displayPrice: json['displayPrice'] as String?,
    );
  }
}
