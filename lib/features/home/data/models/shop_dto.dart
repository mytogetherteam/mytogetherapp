import 'menu_item_dto.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/utils/time_formatter.dart';

class ShopRequestDto {
  final double lat;
  final double lon;
  final double? radius;
  final int? page;
  final int? size;
  final String? search;

  ShopRequestDto({
    required this.lat,
    required this.lon,
    this.radius = 5.0,
    this.page = 0,
    this.size = 20,
    this.search,
  });

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      'radius': radius,
      'page': page,
      'size': size,
      if (search != null && search!.isNotEmpty) 'search': search,
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
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final String? descriptionEn;
  final String? descriptionMm;
  final String? descriptionTh;
  final String? _category;
  final String? categoryEn;
  final String? categoryMm;
  final String? categoryTh;
  final double rating;
  final int reviewCount;
  final String? primaryPhotoUrl;
  final String? logoUrl;
  final String? coverUrl;
  final double distance;
  final String? address;
  final bool isOpen;
  final bool deliveryEnabled;
  final List<OperatingHourDto> operatingHours;
  final String? _estimatedTime;
  final bool isFavorite;
  final double? latitude;
  final double? longitude;
  final List<String> imageUrls;
  final String? displayDeliveryFee;
  final String? originalDeliveryFee;

  String get name => LocaleController.instance.localizedOr(
    _name,
    en: nameEn,
    mm: nameMm,
    th: nameTh,
  );

  String? get category {
    if (categoryEn != null || categoryMm != null || categoryTh != null) {
      final v = LocaleController.instance.localized(
        en: categoryEn,
        mm: categoryMm,
        th: categoryTh,
      );
      if (v.isNotEmpty) return v;
    }
    return _category;
  }

  String? get estimatedTime {
    if (distance > 0) {
      int minTime = (distance * 2.0).round();
      if (minTime < 1) minTime = 1;
      final int maxTime = minTime + 5;
      return '$minTime-$maxTime min';
    }
    return _estimatedTime;
  }

  /// Best banner/cover image for cards and headers.
  String? get bannerImageUrl => ShopImageResolver.resolveBannerUrl(
    coverUrl: coverUrl,
    imageUrls: imageUrls,
    logoUrl: logoUrl,
    primaryPhotoUrl: primaryPhotoUrl,
  );

  ShopListItemDto({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.descriptionEn,
    this.descriptionMm,
    this.descriptionTh,
    String? category,
    this.categoryEn,
    this.categoryMm,
    this.categoryTh,
    required this.rating,
    required this.reviewCount,
    this.primaryPhotoUrl,
    this.logoUrl,
    this.coverUrl,
    required this.distance,
    this.address,
    required this.isOpen,
    this.deliveryEnabled = true,
    this.operatingHours = const [],
    String? estimatedTime,
    required this.isFavorite,
    this.latitude,
    this.longitude,
    this.imageUrls = const <String>[],
    this.displayDeliveryFee,
    this.originalDeliveryFee,
  }) : _name = name,
       _category = category,
       _estimatedTime = estimatedTime;

  factory ShopListItemDto.fromJson(Map<String, dynamic> json) {
    final ratingRaw = json['rating'];
    final double rating = ratingRaw is Map
        ? (ratingRaw['avg'] ?? 0.0).toDouble()
        : (json['rating'] ?? 0.0).toDouble();
    final int reviewCount = ratingRaw is Map
        ? int.tryParse(
                (ratingRaw['count'] ?? ratingRaw['ratingCount'] ?? 0)
                    .toString(),
              ) ??
              0
        : int.tryParse(
                (json['reviewCount'] ?? json['ratingCount'] ?? 0).toString(),
              ) ??
              0;

    final imageUrls = ShopImageResolver.parseImageUrls(json);
    final primaryPhotoUrl =
        ImageUtils.cleanImageUrl(json['primaryPhotoUrl']) ??
        (imageUrls.isNotEmpty ? imageUrls.first : null);

    final shopCategory = json['shopCategory'] is Map
        ? json['shopCategory'] as Map
        : null;

    return ShopListItemDto(
      id: json['id'] ?? 0,
      name: (json['name'] as String? ?? json['nameEn'] as String?) ?? '',
      nameEn: json['nameEn'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      descriptionEn: json['descriptionEn'] as String?,
      descriptionMm: json['descriptionMm'] as String?,
      descriptionTh: json['descriptionTh'] as String?,
      category: json['category'] as String?,
      categoryEn: shopCategory?['nameEn'] as String?,
      categoryMm: shopCategory?['nameMm'] as String?,
      categoryTh: shopCategory?['nameTh'] as String?,
      rating: rating,
      reviewCount: reviewCount,
      primaryPhotoUrl: primaryPhotoUrl,
      logoUrl: ImageUtils.cleanImageUrl(json['logoUrl']),
      coverUrl: ImageUtils.cleanImageUrl(json['coverUrl']),
      distance: (json['distanceKm'] ?? json['distance'] ?? 0.0).toDouble(),
      address: json['address']?.toString(),
      isOpen: json['isOpen'] ?? false,
      deliveryEnabled: json['deliveryEnabled'] as bool? ?? true,
      operatingHours: (json['operatingHours'] as List? ?? [])
          .map((e) => OperatingHourDto.fromJson(e))
          .toList(),
      estimatedTime: json['estimatedTime']?.toString(),
      isFavorite: json['isFavorite'] ?? false,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      imageUrls: imageUrls,
      displayDeliveryFee: _parseDeliveryFee(json),
      originalDeliveryFee: _parseOriginalDeliveryFee(json),
    );
  }

  static String? _parseDeliveryFee(Map<String, dynamic> json) {
    // API returns displayDeliveryFee as a number (e.g. 1000)
    final raw =
        json['displayDeliveryFee'] ??
        json['displayBaseDeliveryFee'] ??
        json['baseDeliveryFee'];
    if (raw == null) return null;
    final num? fee = num.tryParse(raw.toString());
    if (fee == null) return raw.toString();
    if (fee == 0) return LocaleController.instance.tr('common.free');
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
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final String? descriptionEn;
  final String? descriptionMm;
  final String? descriptionTh;
  final String? category;
  final CuisineTypeDto? cuisineType;
  final double rating;
  final int reviewCount;
  final bool hasParking;
  final bool hasWifi;
  final bool isHalal;
  final bool isVegetarian;
  final String? logoUrl;
  final String? coverUrl;
  final String? primaryPhotoUrl;
  final double distance;
  final String? _estimatedTime;
  final bool isOpen;
  final bool deliveryEnabled;
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

  String get name => LocaleController.instance.localizedOr(
    _name,
    en: nameEn,
    mm: nameMm,
    th: nameTh,
  );

  /// Localized shop description, empty when none is available.
  String get description => LocaleController.instance.localized(
    en: descriptionEn,
    mm: descriptionMm,
    th: descriptionTh,
  );

  String? get estimatedTime {
    if (distance > 0) {
      int minTime = (distance * 2.0).round();
      if (minTime < 1) minTime = 1;
      final int maxTime = minTime + 5;
      return '$minTime-$maxTime min';
    }
    return _estimatedTime;
  }

  /// Best banner/cover image for the detail header.
  String? get bannerImageUrl => ShopImageResolver.resolveBannerUrl(
    coverUrl: coverUrl,
    imageUrls: photos,
    logoUrl: logoUrl,
    primaryPhotoUrl: primaryPhotoUrl,
  );

  ShopDetailDto({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.descriptionEn,
    this.descriptionMm,
    this.descriptionTh,
    this.category,
    required this.rating,
    required this.reviewCount,
    this.hasParking = false,
    this.hasWifi = false,
    this.isHalal = false,
    this.isVegetarian = false,
    this.logoUrl,
    this.coverUrl,
    this.primaryPhotoUrl,
    required this.distance,
    String? estimatedTime,
    required this.isOpen,
    this.deliveryEnabled = true,
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
  }) : _name = name,
       _estimatedTime = estimatedTime;

  factory ShopDetailDto.fromJson(Map<String, dynamic> json) {
    return ShopDetailDto(
      id: json['id'] ?? 0,
      name: (json['name'] as String? ?? json['nameEn'] as String?) ?? '',
      nameEn: json['nameEn'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      descriptionEn: json['descriptionEn'] as String?,
      descriptionMm: json['descriptionMm'] as String?,
      descriptionTh: json['descriptionTh'] as String?,
      category: json['category'],
      cuisineType: json['cuisineType'] != null
          ? CuisineTypeDto.fromJson(json['cuisineType'])
          : null,
      rating: (json['rating'] ?? json['ratingAvg'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? json['ratingCount'] ?? 0,
      logoUrl: ImageUtils.cleanImageUrl(json['logoUrl']),
      coverUrl: ImageUtils.cleanImageUrl(json['coverUrl']),
      primaryPhotoUrl: ImageUtils.cleanImageUrl(json['primaryPhotoUrl']),
      distance: (json['distance'] ?? 0.0).toDouble(),
      estimatedTime: json['estimatedTime']?.toString(),
      isOpen: json['isOpen'] ?? false,
      deliveryEnabled: json['deliveryEnabled'] as bool? ?? true,
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
      photos: ShopImageResolver.parseImageUrls(json),
      popularDishes: (json['popularDishes'] as List? ?? [])
          .map((e) => MenuItemDto.fromDishJson(e))
          .toList(),
      recommendations: (json['recommendations'] as List? ?? [])
          .map((e) => MenuItemDto.fromDishJson(e))
          .toList(),
      hotDeals: (json['hotDeals'] as List? ?? [])
          .map((e) => MenuItemDto.fromDishJson(e))
          .toList(),
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
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

  /// Maps `GET /api/user/shop-profile/:id` (enriched user-visible shop) into
  /// the detail shape the UI already expects from the removed public endpoint.
  factory ShopDetailDto.fromUserProfileJson(
    Map<String, dynamic> json, {
    double? distanceKm,
  }) {
    final normalized = Map<String, dynamic>.from(json);

    final galleries = json['galleries'];
    if (galleries is List && galleries.isNotEmpty) {
      normalized['photos'] = galleries
          .whereType<Map>()
          .map((g) => g['imageUrl'] ?? g['image'])
          .whereType<String>()
          .toList();
    }

    final shopPaymentMethods = json['shopPaymentMethods'];
    if (shopPaymentMethods is List) {
      normalized['paymentTypes'] = shopPaymentMethods
          .whereType<Map<String, dynamic>>()
          .where((row) => row['isActive'] != false)
          .map((row) {
            final pm = row['paymentMethod'] as Map<String, dynamic>?;
            final name = pm?['name']?.toString() ?? '';
            return {
              'paymentMethodId': row['paymentMethodId'] ?? pm?['id'],
              'paymentMethodName': name,
              'paymentMethodCode': name.trim().toUpperCase().replaceAll(
                RegExp(r'\s+'),
                '_',
              ),
              'isActive': row['isActive'] ?? true,
              'qrImageUrl': row['qr'],
              'accountNumber': row['accountNumber'],
              'accountName': row['accountName'],
              'iconUrl': pm?['iconUrl'],
            };
          })
          .toList();
    }

    final shopCategory = json['shopCategory'];
    if (shopCategory is Map) {
      normalized['category'] ??= shopCategory['nameEn'];
    }

    final shopCuisines = json['shopCuisines'];
    if (shopCuisines is List && shopCuisines.isNotEmpty) {
      final first = shopCuisines.first;
      if (first is Map && first['cuisineType'] is Map) {
        normalized['cuisineType'] = first['cuisineType'];
      }
    }

    final menuItems = json['menuItems'];
    if (menuItems is List) {
      final dishes = menuItems.whereType<Map<String, dynamic>>().toList();
      normalized['popularDishes'] = dishes
          .where((m) => m['isRecommended'] == true)
          .take(12)
          .toList();
      normalized['hotDeals'] = dishes
          .where((m) => m['isHotDeal'] == true)
          .take(12)
          .toList();
      normalized['recommendations'] = normalized['popularDishes'];
    }

    normalized['rating'] = json['ratingAvg'] ?? json['rating'];
    normalized['reviewCount'] = json['ratingCount'] ?? json['reviewCount'];
    if (distanceKm != null) {
      normalized['distance'] = distanceKm;
    } else {
      normalized['distance'] = json['distanceKm'] ?? json['distance'] ?? 0;
    }

    return ShopDetailDto.fromJson(normalized);
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
    if (isClosed) return LocaleController.instance.tr('common.closed');
    if (openingTime == null || closingTime == null) {
      return LocaleController.instance.tr('common.na');
    }
    return '${openingTime!.format24h} - ${closingTime!.format24h}';
  }

  /// Alias for [displayTime] — operating hours are always shown in 24-hour format.
  String get displayTime24h => displayTime;
}

class LocalTimeDto {
  final int hour;
  final int minute;

  LocalTimeDto({required this.hour, required this.minute});

  factory LocalTimeDto.fromJson(Map<String, dynamic> json) {
    return LocalTimeDto(hour: json['hour'] ?? 0, minute: json['minute'] ?? 0);
  }

  /// 24-hour clock display, e.g. `06:00` or `18:30`.
  String get format24h => TimeFormatter.formatParts(hour, minute);

  /// Alias for [format24h].
  String get format => format24h;
}

class ShopPaymentTypeDto {
  final int paymentMethodId;
  final String paymentMethodCode;
  final String? paymentMethodName;
  final bool isActive;
  final String? qrImageUrl;
  final String? accountNumber;
  final String? accountName;
  final String? iconUrl;

  ShopPaymentTypeDto({
    required this.paymentMethodId,
    this.paymentMethodCode = '',
    this.paymentMethodName,
    required this.isActive,
    this.qrImageUrl,
    this.accountNumber,
    this.accountName,
    this.iconUrl,
  });

  /// Human-readable label for the tile (falls back to the code, then a generic).
  String get displayName {
    if (paymentMethodName != null && paymentMethodName!.trim().isNotEmpty) {
      return paymentMethodName!.trim();
    }
    if (paymentMethodCode.isNotEmpty) return paymentMethodCode;
    return 'Payment';
  }

  /// Cash-on-delivery is identified by name/code since the backend
  /// `PaymentMethod` model has no dedicated `code` column.
  bool get isCashOnDelivery {
    final value = (paymentMethodName ?? paymentMethodCode).toUpperCase();
    return value.contains('CASH') ||
        value.contains('COD') ||
        value.contains('DELIVERY');
  }

  factory ShopPaymentTypeDto.fromJson(Map<String, dynamic> json) {
    // The public shop-detail endpoint flattens each method to the
    // `paymentMethod` row shape (`{ id, name, iconUrl, isActive }`), while
    // other endpoints use the `paymentMethodId`/`paymentMethodName` shape.
    // Support both so the name and icon always resolve.
    final name = json['paymentMethodName'] ?? json['name'];
    return ShopPaymentTypeDto(
      paymentMethodId:
          (json['paymentMethodId'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          0,
      paymentMethodCode: json['paymentMethodCode'] ?? '',
      paymentMethodName: name?.toString(),
      isActive: json['isActive'] ?? false,
      qrImageUrl: json['qrImageUrl'] ?? json['qr'],
      accountNumber: json['accountNumber'],
      accountName: json['accountName'],
      iconUrl: json['iconUrl'],
    );
  }

  /// Parses a row from `GET /api/user/shops/:shopId/payment-methods`
  /// (`UserShopPaymentMethodsController`). Each row is a `shopPaymentMethod`
  /// with an included `paymentMethod` relation:
  /// `{ shopId, paymentMethodId, accountName, accountNumber, isActive, qr,
  ///    paymentMethod: { id, name, iconUrl, isActive } }`.
  factory ShopPaymentTypeDto.fromUserApiJson(Map<String, dynamic> json) {
    final pm = json['paymentMethod'] as Map<String, dynamic>?;
    final name = pm?['name']?.toString();
    return ShopPaymentTypeDto(
      paymentMethodId:
          (json['paymentMethodId'] as num?)?.toInt() ??
          (pm?['id'] as num?)?.toInt() ??
          0,
      paymentMethodName: name,
      // Synthesize a stable code from the name for icon heuristics
      // (e.g. "PromptPay" -> "PROMPTPAY", "Cash on Delivery" -> "CASH_ON_DELIVERY").
      paymentMethodCode: (name ?? '').trim().toUpperCase().replaceAll(
        RegExp(r'\s+'),
        '_',
      ),
      isActive: json['isActive'] as bool? ?? true,
      qrImageUrl: json['qr']?.toString(),
      accountNumber: json['accountNumber']?.toString(),
      accountName: json['accountName']?.toString(),
      iconUrl: pm?['iconUrl']?.toString(),
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
    return LocaleController.instance.localized(
      en: nameEn,
      mm: nameMm,
      th: nameTh,
    );
  }
}
