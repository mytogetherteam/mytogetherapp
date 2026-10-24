import '../../../reviews/data/models/order_review_dto.dart';
import '../../../../core/utils/time_formatter.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/file_url_util.dart';

class OrderHistoryGroupedDto {
  final List<OrderHistoryDto> currentOrders;
  final List<OrderHistoryDto> pastOrders;

  OrderHistoryGroupedDto({
    required this.currentOrders,
    required this.pastOrders,
  });

  factory OrderHistoryGroupedDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return OrderHistoryGroupedDto(
      currentOrders:
          (data['currentOrders'] as List<dynamic>?)
              ?.map((e) => OrderHistoryDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pastOrders:
          (data['pastOrders'] as List<dynamic>?)
              ?.map((e) => OrderHistoryDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class OrderHistoryDto {
  final String id;
  final String? lastOrderNo;
  final String status;
  final String? statusLabel;
  final bool ongoing;
  final String createdAt;
  final String? updatedAt;
  final double totalAmount;
  final String? displayTotalAmount;
  final String? _shopName;
  final String? shopNameEn;
  final String? shopNameMm;
  final String? shopNameTh;
  final String? shopImageUrl;
  final int? shopId;
  final List<OrderHistoryItemDto> items;

  /// Number of dishes on the order. The list only includes a few photos.
  final int itemCount;
  final double? deliveryFee;
  final String? displayDeliveryFee;
  final double? itemPrice;
  final double? taxAmount;
  final String? displayTaxAmount;
  final String? orderType;
  final String? orderDeliveryType;
  final int? waitingTimeMinutes;
  final double? discountAmount;
  final double? transactionDiscount;
  final String? displayTransactionDiscount;
  final bool isFreeDelivery;
  final bool isVerified;
  final bool? taxEnable;
  final OrderReviewDto? orderReview;
  final bool hasChatConversation;
  final String? paymentMethodName;
  final String? paymentMethodIconUrl;
  final String? paymentChannel;

  bool get isOmisePayment =>
      (paymentChannel ?? '').toUpperCase() == 'OMISE' || isVerified;

  OrderHistoryDto({
    required this.id,
    this.lastOrderNo,
    required this.status,
    this.statusLabel,
    required this.ongoing,
    required this.createdAt,
    this.updatedAt,
    required this.totalAmount,
    this.displayTotalAmount,
    String? shopName,
    this.shopNameEn,
    this.shopNameMm,
    this.shopNameTh,
    this.shopImageUrl,
    this.shopId,
    required this.items,
    this.itemCount = 0,
    this.deliveryFee,
    this.displayDeliveryFee,
    this.itemPrice,
    this.taxAmount,
    this.displayTaxAmount,
    this.orderType,
    this.orderDeliveryType,
    this.waitingTimeMinutes,
    this.discountAmount,
    this.transactionDiscount,
    this.displayTransactionDiscount,
    this.isFreeDelivery = false,
    this.isVerified = false,
    this.taxEnable,
    this.orderReview,
    this.hasChatConversation = false,
    this.paymentMethodName,
    this.paymentMethodIconUrl,
    this.paymentChannel,
  }) : _shopName = shopName;

  bool get isPickupFulfillment {
    final type = (orderType ?? '').toUpperCase();
    return type == 'PICK_UP' || type == 'PICKUP';
  }

  bool get isFlexibleDelivery {
    if (isPickupFulfillment) return false;
    final type = (orderDeliveryType ?? '').toUpperCase();
    if (type == 'FAST' || type == 'PREPAID') return false;
    if (type == 'FLEXIBLE' || type == 'NORMAL') return true;
    return type.isEmpty;
  }

  String? get prepTimeLabel {
    final mins = waitingTimeMinutes;
    if (mins == null || mins <= 0) return null;
    return '$mins mins';
  }

  bool get resolvedTaxEnable {
    if (taxEnable != null) return taxEnable!;
    if (itemPrice != null && itemPrice! > 0 && taxAmount != null) {
      return taxAmount! > 0;
    }
    return true;
  }

  String? get shopName {
    final value = LocaleController.instance.localizedOr(
      _shopName ?? '',
      en: shopNameEn ?? _shopName,
      mm: shopNameMm,
      th: shopNameTh,
    );
    return value.isEmpty ? null : value;
  }

  /// The backend only sends an English `statusLabel`, so localize from the
  /// stable `status` enum and fall back to the English label.
  String get displayStatusLabel => LocaleController.instance
      .localizedOrderStatus(status, fallback: statusLabel ?? status);

  String get dateDisplay {
    try {
      final date = DateTime.parse(createdAt);
      return TimeFormatter.formatDateTime(date);
    } catch (e) {
      return createdAt;
    }
  }

  factory OrderHistoryDto.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'] as Map<String, dynamic>?;
    final shopNameEn =
        json['shopName'] as String? ??
        shop?['name'] as String? ??
        shop?['nameEn'] as String?;
    final shopImageUrl = _resolveShopImageUrl(json, shop);

    // The new backend (mapUserOrderListItem) doesn't emit `ongoing`; derive
    // it from `status` so the UI can still split "current" vs "past".
    final status = json['status'] as String? ?? 'PENDING';
    const terminalStatuses = {
      'DELIVERED',
      'PICKED_UP',
      'CANCELED',
      'CANCELLED',
      'COMPLETED',
    };
    final ongoing =
        (json['ongoing'] as bool?) ??
        !terminalStatuses.contains(status.toUpperCase());

    final parsedItems = (json['items'] as List<dynamic>?)
            ?.map(
              (e) => OrderHistoryItemDto.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        <OrderHistoryItemDto>[];

    return OrderHistoryDto(
      id: json['id'].toString(),
      lastOrderNo: json['lastOrderNo']?.toString(),
      status: status,
      statusLabel: json['statusLabel'] as String?,
      ongoing: ongoing,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String?,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      displayTotalAmount: json['displayTotalAmount'] as String?,
      shopName: shopNameEn,
      shopNameEn: shopNameEn,
      shopNameMm: json['shopNameMm'] as String? ?? shop?['nameMm'] as String?,
      shopNameTh: json['shopNameTh'] as String? ?? shop?['nameTh'] as String?,
      shopImageUrl: shopImageUrl,
      shopId: (json['shopId'] as int?) ?? (shop?['id'] as int?),
      items: parsedItems,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? parsedItems.length,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      displayDeliveryFee: json['displayDeliveryFee'] as String?,
      itemPrice: (json['itemPrice'] as num?)?.toDouble(),
      taxAmount: (json['taxAmount'] as num?)?.toDouble(),
      displayTaxAmount: json['displayTaxAmount'] as String?,
      orderType: json['orderType'] as String?,
      orderDeliveryType: json['orderDeliveryType'] as String?,
      waitingTimeMinutes: (json['waitingTimeMinutes'] as num?)?.toInt(),
      discountAmount: (json['discountAmount'] as num?)?.toDouble(),
      transactionDiscount: (json['transactionDiscount'] as num?)?.toDouble(),
      displayTransactionDiscount: json['displayTransactionDiscount'] as String?,
      isFreeDelivery: json['isFreeDelivery'] == true ||
          (json['displayDeliveryFee']?.toString().toUpperCase() == 'FREE'),
      isVerified: (json['isVerified'] as bool?) ??
          (shop?['isVerified'] as bool?) ??
          false,
      taxEnable: _resolveTaxEnable(json, shop),
      orderReview: json['orderReview'] is Map<String, dynamic>
          ? OrderReviewDto.fromJson(json['orderReview'] as Map<String, dynamic>)
          : null,
      hasChatConversation: json['hasChatConversation'] == true,
      paymentMethodName: _paymentName(json['paymentMethod']),
      paymentMethodIconUrl: _paymentIcon(json['paymentMethod']),
      paymentChannel: json['paymentChannel']?.toString() ?? json['payment_channel']?.toString(),
    );
  }

  static String? _paymentName(dynamic raw) {
    if (raw is! Map) return null;
    final name = raw['name']?.toString().trim();
    return name == null || name.isEmpty ? null : name;
  }

  static String? _paymentIcon(dynamic raw) {
    if (raw is! Map) return null;
    final resolved = FileUrlUtil.resolve(raw['iconUrl']);
    return resolved.isEmpty ? null : resolved;
  }

  static bool? _resolveTaxEnable(
    Map<String, dynamic> json,
    Map<String, dynamic>? shop,
  ) {
    if (json['taxEnable'] is bool) return json['taxEnable'] as bool;
    if (shop?['taxEnable'] is bool) return shop!['taxEnable'] as bool;
    return null;
  }

  static String? _resolveShopImageUrl(
    Map<String, dynamic> json,
    Map<String, dynamic>? shop,
  ) {
    final candidates = <String?>[
      json['shopImageUrl'] as String?,
      json['shopLogo'] as String?,
      if (shop != null) ShopImageResolver.resolveShopAvatarFromJson(shop),
      shop?['logoUrl'] as String?,
      shop?['coverUrl'] as String?,
    ];
    for (final raw in candidates) {
      final resolved = FileUrlUtil.resolve(raw);
      if (resolved.isNotEmpty) return resolved;
    }
    return null;
  }
}

class OrderHistoryItemDto {
  final int? id;
  final int? menuItemId;
  final String _menuItemName;
  final String? menuItemNameEn;
  final String? menuItemNameMm;
  final String? menuItemNameTh;
  final String? menuItemImageUrl;
  final double price;
  final int quantity;
  final String? displayPrice;
  final int? variantId;
  final List<int> additionalVariantIds;
  final List<int> optionIds;
  final String? specialInstructions;
  final String? variantNameEn;
  final String? variantNameMm;
  final String? variantNameTh;
  final String? optionNameEn;
  final String? optionNameMm;
  final String? optionNameTh;

  String get menuItemName {
    final value = LocaleController.instance.localizedOr(
      _menuItemName,
      en: menuItemNameEn ?? _menuItemName,
      mm: menuItemNameMm,
      th: menuItemNameTh,
    );
    return value.isEmpty ? 'Item' : value;
  }

  /// Size and add-ons saved on the order, in the current language.
  String? get choiceLabel {
    String? localized(String? en, String? mm, String? th) {
      final value = LocaleController.instance.localizedOr(
        en ?? '',
        en: en,
        mm: mm,
        th: th,
      );
      return value.isEmpty ? null : value;
    }

    final parts = <String>[
      if (localized(variantNameEn, variantNameMm, variantNameTh) != null)
        localized(variantNameEn, variantNameMm, variantNameTh)!,
      if (localized(optionNameEn, optionNameMm, optionNameTh) != null)
        localized(optionNameEn, optionNameMm, optionNameTh)!,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  double get lineTotal => price * quantity;

  OrderHistoryItemDto({
    this.id,
    this.menuItemId,
    required String menuItemName,
    this.menuItemNameEn,
    this.menuItemNameMm,
    this.menuItemNameTh,
    this.menuItemImageUrl,
    required this.price,
    required this.quantity,
    this.displayPrice,
    this.variantId,
    this.additionalVariantIds = const [],
    this.optionIds = const [],
    this.specialInstructions,
    this.variantNameEn,
    this.variantNameMm,
    this.variantNameTh,
    this.optionNameEn,
    this.optionNameMm,
    this.optionNameTh,
  }) : _menuItemName = menuItemName;

  static List<int> _intList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((value) => int.tryParse(value.toString()) ?? 0).where((id) => id > 0).toList();
  }

  factory OrderHistoryItemDto.fromJson(Map<String, dynamic> json) {
    // New backend (mapUserOrderListItem) uses: nameEn / nameMm / imageUrl.
    // Legacy shape used: menuItemName / menuItemNameMm / menuItemImageUrl.
    final menuItemNameEn =
        (json['menuItemName'] as String?) ?? (json['nameEn'] as String?);
    final rawImage =
        (json['menuItemImageUrl'] as String?) ?? (json['imageUrl'] as String?);
    final resolvedImage = FileUrlUtil.resolve(rawImage);
    return OrderHistoryItemDto(
      id: (json['id'] as num?)?.toInt(),
      menuItemId: json['menuItemId'] as int?,
      menuItemName: menuItemNameEn ?? 'Item',
      menuItemNameEn: menuItemNameEn,
      menuItemNameMm:
          (json['menuItemNameMm'] as String?) ?? (json['nameMm'] as String?),
      menuItemNameTh:
          (json['menuItemNameTh'] as String?) ?? (json['nameTh'] as String?),
      menuItemImageUrl: resolvedImage.isEmpty ? null : resolvedImage,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
      displayPrice: json['displayPrice'] as String?,
      variantId: (json['variantId'] as num?)?.toInt(),
      additionalVariantIds: _intList(json['additionalVariantIds']),
      optionIds: _intList(json['optionIds']),
      specialInstructions: json['specialInstructions']?.toString(),
      variantNameEn: json['variantNameEn'] as String?,
      variantNameMm: json['variantNameMm'] as String?,
      variantNameTh: json['variantNameTh'] as String?,
      optionNameEn: json['optionNameEn'] as String?,
      optionNameMm: json['optionNameMm'] as String?,
      optionNameTh: json['optionNameTh'] as String?,
    );
  }
}
