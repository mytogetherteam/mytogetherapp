import 'menu_item_dto.dart';
import '../../../../core/utils/image_utils.dart';

class ShopRequestDto {
  final double lat;
  final double lon;
  final double? radius;
  final int? page;
  final int? size;

  ShopRequestDto({
    required this.lat,
    required this.lon,
    this.radius = 5.0,
    this.page = 0,
    this.size = 20,
  });

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      'radius': radius,
      'page': page,
      'size': size,
    };
  }
}

class ApiResponseSliceShopListDto {
  final bool success;
  final String message;
  final SliceShopListDto data;
  final int status;
  final String timestamp;

  ApiResponseSliceShopListDto({
    required this.success,
    required this.message,
    required this.data,
    required this.status,
    required this.timestamp,
  });

  factory ApiResponseSliceShopListDto.fromJson(Map<String, dynamic> json) {
    return ApiResponseSliceShopListDto(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: SliceShopListDto.fromJson(json['data'] ?? {}),
      status: json['status'] ?? 0,
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class SliceShopListDto {
  final List<ShopListItemDto> content;
  final PageableDto pageable;
  final bool first;
  final bool last;
  final int size;
  final int number;
  final int numberOfElements;
  final bool empty;

  SliceShopListDto({
    required this.content,
    required this.pageable,
    required this.first,
    required this.last,
    required this.size,
    required this.number,
    required this.numberOfElements,
    required this.empty,
  });

  factory SliceShopListDto.fromJson(Map<String, dynamic> json) {
    return SliceShopListDto(
      content: (json['content'] as List? ?? [])
          .map((item) => ShopListItemDto.fromJson(item))
          .toList(),
      pageable: PageableDto.fromJson(json['pageable'] ?? {}),
      // API sometimes returns these as strings, handle both
      first: json['first'] == true || json['first'] == 'true',
      last: json['last'] == true || json['last'] == 'true',
      size: int.tryParse(json['size'].toString()) ?? 0,
      number: int.tryParse(json['number'].toString()) ?? 0,
      numberOfElements: int.tryParse(json['numberOfElements'].toString()) ?? 0,
      empty: json['empty'] == true || json['empty'] == 'true',
    );
  }
}

class ShopListItemDto {
  final int id;
  final String name;
  final String? nameEn;
  final String? category;
  final double rating;
  final int reviewCount;
  final String? primaryPhotoUrl;
  final String? logoUrl;
  final String? coverUrl;
  final double distance;
  final String? address;
  final bool isOpen;
  final String? estimatedTime;
  final bool isFavorite;
  final double? latitude;
  final double? longitude;
  final List<String> imageUrls;
  final String? displayDeliveryFee;
  final String? originalDeliveryFee;

  ShopListItemDto({
    required this.id,
    required this.name,
    this.nameEn,
    this.category,
    required this.rating,
    required this.reviewCount,
    this.primaryPhotoUrl,
    this.logoUrl,
    this.coverUrl,
    required this.distance,
    this.address,
    required this.isOpen,
    this.estimatedTime,
    required this.isFavorite,
    this.latitude,
    this.longitude,
    this.imageUrls = const <String>[],
    this.displayDeliveryFee,
    this.originalDeliveryFee,
  });

  factory ShopListItemDto.fromJson(Map<String, dynamic> json) {
    return ShopListItemDto(
      id: json['id'] ?? 0,
      name: json['name'] as String? ?? json['nameEn'] as String? ?? json['nameMm'] as String? ?? '',
      nameEn: json['nameEn'],
      category: json['category'],
      rating: (json['rating'] ?? json['ratingAvg'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? json['ratingCount'] ?? 0,
      primaryPhotoUrl: ImageUtils.cleanImageUrl(json['primaryPhotoUrl']),
      logoUrl: ImageUtils.cleanImageUrl(json['logoUrl']),
      coverUrl: ImageUtils.cleanImageUrl(json['coverUrl']),
      distance: (json['distance'] ?? 0.0).toDouble(),
      address: json['address']?.toString(),
      isOpen: json['isOpen'] ?? false,
      estimatedTime: json['estimatedTime']?.toString(),
      isFavorite: json['isFavorite'] ?? false,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      imageUrls: (json['imageUrls'] as List? ?? [])
          .map((e) => ImageUtils.cleanImageUrl(e.toString()))
          .whereType<String>()
          .toList(),
      displayDeliveryFee: _parseDeliveryFee(json),
      originalDeliveryFee: _parseOriginalDeliveryFee(json),
    );
  }

  static String? _parseDeliveryFee(Map<String, dynamic> json) {
    // API returns displayDeliveryFee as a number (e.g. 1000)
    final raw = json['displayDeliveryFee'] ?? json['displayBaseDeliveryFee'] ?? json['baseDeliveryFee'];
    if (raw == null) return null;
    final num? fee = num.tryParse(raw.toString());
    if (fee == null) return raw.toString();
    if (fee == 0) return 'Free';
    return '฿${fee.toStringAsFixed(0)}';
  }

  static String? _parseOriginalDeliveryFee(Map<String, dynamic> json) {
    final raw = json['originalDeliveryFee'];
    if (raw == null) return null;
    final num? fee = num.tryParse(raw.toString());
    if (fee == null) return raw.toString();
    if (fee == 0) return null;
    return '฿${fee.toStringAsFixed(0)}';
  }
}

class PageableDto {
  final int pageNumber;
  final int pageSize;
  final int offset;
  final bool paged;
  final bool unpaged;

  PageableDto({
    required this.pageNumber,
    required this.pageSize,
    required this.offset,
    required this.paged,
    required this.unpaged,
  });

  factory PageableDto.fromJson(Map<String, dynamic> json) {
    return PageableDto(
      pageNumber: json['pageNumber'] ?? 0,
      pageSize: json['pageSize'] ?? 0,
      offset: json['offset'] ?? 0,
      paged: json['paged'] ?? false,
      unpaged: json['unpaged'] ?? false,
    );
  }
}
class ApiResponseShopDetailDto {
  final bool success;
  final String message;
  final ShopDetailDto data;
  final int status;
  final String timestamp;

  ApiResponseShopDetailDto({
    required this.success,
    required this.message,
    required this.data,
    required this.status,
    required this.timestamp,
  });

  factory ApiResponseShopDetailDto.fromJson(Map<String, dynamic> json) {
    return ApiResponseShopDetailDto(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: ShopDetailDto.fromJson(json['data'] ?? {}),
      status: json['status'] ?? 0,
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class ShopDetailDto {
  final int id;
  final String name;
  final String? category;
  final CuisineTypeDto? cuisineType;
  final double rating;
  final int reviewCount;
  final String? logoUrl;
  final String? coverUrl;
  final String? primaryPhotoUrl;
  final double distance;
  final String? estimatedTime;
  final bool isOpen;
  final String? address;
  final String? addressMm;
  final String? addressTh;
  final String? addressEn;
  final String? phone;
  final String? email;
  final String? googleMapsLink;
  final List<OperatingHourDto> operatingHours;
  final List<String> photos;
  final List<MenuItemDto> popularDishes;
  final List<MenuItemDto> recommendations;
  final List<MenuItemDto> hotDeals;
  final double? latitude;
  final double? longitude;
  final bool isFavorite;
  final List<ShopPaymentTypeDto> paymentTypes;
  final String? paymentQrUrl;
  final int? minEta;
  final int? maxEta;
  final List<DeliveryTierDto> deliveryTiers;

  ShopDetailDto({
    required this.id,
    required this.name,
    this.category,
    required this.rating,
    required this.reviewCount,
    this.logoUrl,
    this.coverUrl,
    this.primaryPhotoUrl,
    required this.distance,
    this.estimatedTime,
    required this.isOpen,
    this.address,
    this.addressMm,
    this.addressTh,
    this.addressEn,
    this.phone,
    this.email,
    this.googleMapsLink,
    required this.operatingHours,
    required this.photos,
    required this.popularDishes,
    required this.recommendations,
    required this.hotDeals,
    this.latitude,
    this.longitude,
    required this.isFavorite,
    this.cuisineType,
    this.paymentTypes = const [],
    this.paymentQrUrl,
    this.minEta,
    this.maxEta,
    this.deliveryTiers = const [],
  });

  factory ShopDetailDto.fromJson(Map<String, dynamic> json) {
    return ShopDetailDto(
      id: json['id'] ?? 0,
      name: json['name'] as String? ?? json['nameEn'] as String? ?? json['nameMm'] as String? ?? '',
      category: json['category'],
      cuisineType: json['cuisineType'] != null ? CuisineTypeDto.fromJson(json['cuisineType']) : null,
      rating: (json['rating'] ?? json['ratingAvg'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? json['ratingCount'] ?? 0,
      logoUrl: ImageUtils.cleanImageUrl(json['logoUrl']),
      coverUrl: ImageUtils.cleanImageUrl(json['coverUrl']),
      primaryPhotoUrl: ImageUtils.cleanImageUrl(json['primaryPhotoUrl']),
      distance: (json['distance'] ?? 0.0).toDouble(),
      estimatedTime: json['estimatedTime']?.toString(),
      isOpen: json['isOpen'] ?? false,
      address: json['address']?.toString(),
      addressMm: json['addressMm']?.toString(),
      addressTh: json['addressTh']?.toString(),
      addressEn: json['addressEn']?.toString(),
      phone: json['phone'],
      email: json['email'],
      googleMapsLink: json['googleMapsLink'],
      operatingHours: (json['operatingHours'] as List? ?? [])
          .map((e) => OperatingHourDto.fromJson(e))
          .toList(),
      photos: (json['photos'] as List? ?? [])
          .map((e) {
            if (e is Map) {
              return ImageUtils.cleanImageUrl(e['url']?.toString());
            }
            return ImageUtils.cleanImageUrl(e.toString());
          })
          .whereType<String>()
          .toList(),
      popularDishes: (json['popularDishes'] as List? ?? []).map((e) => MenuItemDto.fromDishJson(e)).toList(),
      recommendations: (json['recommendations'] as List? ?? []).map((e) => MenuItemDto.fromDishJson(e)).toList(),
      hotDeals: (json['hotDeals'] as List? ?? []).map((e) => MenuItemDto.fromDishJson(e)).toList(),
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      isFavorite: json['isFavorite'] ?? false,
      paymentTypes: (json['paymentTypes'] as List? ?? [])
          .map((e) => ShopPaymentTypeDto.fromJson(e))
          .toList(),
      paymentQrUrl: json['paymentQrUrl'],
      minEta: json['minEta'],
      maxEta: json['maxEta'],
      deliveryTiers: (json['deliveryTiers'] as List? ?? [])
          .map((e) => DeliveryTierDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DeliveryTierDto {
  final String tier;
  final double fee;
  final String? displayFee;
  final String? estimatedTime;
  final String? icon;
  final String? label;
  final String? labelMm;

  DeliveryTierDto({
    required this.tier,
    required this.fee,
    this.displayFee,
    this.estimatedTime,
    this.icon,
    this.label,
    this.labelMm,
  });

  factory DeliveryTierDto.fromJson(Map<String, dynamic> json) {
    return DeliveryTierDto(
      tier: json['tier'] ?? '',
      fee: (json['fee'] ?? 0.0).toDouble(),
      displayFee: json['displayFee'],
      estimatedTime: json['estimatedTime']?.toString(),
      icon: json['icon'],
      label: json['label'],
      labelMm: json['labelMm'],
    );
  }
}

class OperatingHourDto {
  final String dayOfWeek;
  final LocalTimeDto? openingTime;
  final LocalTimeDto? closingTime;
  final bool isClosed;

  OperatingHourDto({
    required this.dayOfWeek,
    this.openingTime,
    this.closingTime,
    required this.isClosed,
  });

  factory OperatingHourDto.fromJson(Map<String, dynamic> json) {
    // Robust parsing for int or string values
    int? parseSafe(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value.toString());
    }

    LocalTimeDto? openTime;
    final hOpen = parseSafe(json['openTimeHour']);
    final mOpen = parseSafe(json['openTimeMin']);
    
    if (hOpen != null && mOpen != null) {
      openTime = LocalTimeDto(hour: hOpen, minute: mOpen);
    } else if (json['openingTime'] != null) {
      openTime = LocalTimeDto.fromJson(json['openingTime']);
    }

    LocalTimeDto? closeTime;
    final hClose = parseSafe(json['closeTimeHour']);
    final mClose = parseSafe(json['closeTimeMin']);

    if (hClose != null && mClose != null) {
      closeTime = LocalTimeDto(hour: hClose, minute: mClose);
    } else if (json['closingTime'] != null) {
      closeTime = LocalTimeDto.fromJson(json['closingTime']);
    }

    return OperatingHourDto(
      dayOfWeek: json['dayOfWeek']?.toString() ?? '',
      openingTime: openTime,
      closingTime: closeTime,
      isClosed: json['isClosed'] ?? false,
    );
  }

  String get displayTime {
    if (isClosed) return 'Closed';
    if (openingTime == null || closingTime == null) return 'N/A';
    return '${openingTime!.format} - ${closingTime!.format}';
  }

  String get displayTime24h {
    if (isClosed) return 'Closed';
    if (openingTime == null || closingTime == null) return 'N/A';
    return '${openingTime!.format24h} - ${closingTime!.format24h}';
  }
}

class LocalTimeDto {
  final int hour;
  final int minute;

  LocalTimeDto({required this.hour, required this.minute});

  factory LocalTimeDto.fromJson(Map<String, dynamic> json) {
    return LocalTimeDto(
      hour: json['hour'] ?? 0,
      minute: json['minute'] ?? 0,
    );
  }

  String get format {
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }

  String get format24h {
    final h = hour.toString();
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class ShopPaymentTypeDto {
  final int paymentMethodId;
  final String paymentMethodCode;
  final String? paymentMethodName;
  final bool isActive;
  final String? qrImageUrl;
  final String? accountNumber;
  final String? accountName;

  ShopPaymentTypeDto({
    required this.paymentMethodId,
    required this.paymentMethodCode,
    this.paymentMethodName,
    required this.isActive,
    this.qrImageUrl,
    this.accountNumber,
    this.accountName,
  });

  factory ShopPaymentTypeDto.fromJson(Map<String, dynamic> json) {
    return ShopPaymentTypeDto(
      paymentMethodId: json['paymentMethodId'] ?? 0,
      paymentMethodCode: json['paymentMethodCode'] ?? '',
      paymentMethodName: json['paymentMethodName'],
      isActive: json['isActive'] ?? false,
      qrImageUrl: json['qrImageUrl'],
      accountNumber: json['accountNumber'],
      accountName: json['accountName'],
    );
  }
}

class CuisineTypeDto {
  final int id;
  final String? nameMm;
  final String? nameTh;
  final String? nameEn;
  final String? slug;
  final String? imageUrl;

  CuisineTypeDto({
    required this.id,
    this.nameMm,
    this.nameTh,
    this.nameEn,
    this.slug,
    this.imageUrl,
  });

  factory CuisineTypeDto.fromJson(Map<String, dynamic> json) {
    return CuisineTypeDto(
      id: json['id'] ?? 0,
      nameMm: json['nameMm'],
      nameTh: json['nameTh'],
      nameEn: json['nameEn'],
      slug: json['slug'],
      imageUrl: json['imageUrl'],
    );
  }

  String get displayName {
    return nameEn ?? nameMm ?? nameTh ?? '';
  }
}
