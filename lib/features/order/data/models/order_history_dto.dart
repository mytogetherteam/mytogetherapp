import 'package:intl/intl.dart';

import '../../../reviews/data/models/order_review_dto.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/utils/image_utils.dart';

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
  final double? deliveryFee;
  final String? displayDeliveryFee;
  final OrderReviewDto? orderReview;

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
    this.deliveryFee,
    this.displayDeliveryFee,
    this.orderReview,
  }) : _shopName = shopName;

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
  String get displayStatusLabel =>
      LocaleController.instance.localizedOrderStatus(
        status,
        fallback: statusLabel ?? status,
      );

  String get dateDisplay {
    try {
      final date = DateTime.parse(createdAt);
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (e) {
      return createdAt;
    }
  }

  factory OrderHistoryDto.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'] as Map<String, dynamic>?;
    final shopNameEn = json['shopName'] as String? ??
        shop?['name'] as String? ??
        shop?['nameEn'] as String?;
    final shopImageUrl =
        json['shopImageUrl'] as String? ??
        json['imageUrl'] as String? ??
        (shop != null ? ShopImageResolver.resolveBannerFromJson(shop) : null) ??
        shop?['imageUrl'] as String? ??
        shop?['coverUrl'] as String? ??
        shop?['logoUrl'] as String? ??
        shop?['image'] as String?;

    // The new backend (mapUserOrderListItem) doesn't emit `ongoing`; derive
    // it from `status` so the UI can still split "current" vs "past".
    final status = json['status'] as String? ?? 'PENDING';
    const terminalStatuses = {'DELIVERED', 'CANCELED', 'CANCELLED', 'COMPLETED'};
    final ongoing = (json['ongoing'] as bool?) ?? !terminalStatuses.contains(status.toUpperCase());

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
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) => OrderHistoryItemDto.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      displayDeliveryFee: json['displayDeliveryFee'] as String?,
      orderReview: json['orderReview'] is Map<String, dynamic>
          ? OrderReviewDto.fromJson(json['orderReview'] as Map<String, dynamic>)
          : null,
    );
  }
}

class OrderHistoryItemDto {
  final int? menuItemId;
  final String _menuItemName;
  final String? menuItemNameEn;
  final String? menuItemNameMm;
  final String? menuItemNameTh;
  final String? menuItemImageUrl;
  final double price;
  final int quantity;
  final String? displayPrice;

  String get menuItemName {
    final value = LocaleController.instance.localizedOr(
      _menuItemName,
      en: menuItemNameEn ?? _menuItemName,
      mm: menuItemNameMm,
      th: menuItemNameTh,
    );
    return value.isEmpty ? 'Item' : value;
  }

  OrderHistoryItemDto({
    this.menuItemId,
    required String menuItemName,
    this.menuItemNameEn,
    this.menuItemNameMm,
    this.menuItemNameTh,
    this.menuItemImageUrl,
    required this.price,
    required this.quantity,
    this.displayPrice,
  }) : _menuItemName = menuItemName;

  factory OrderHistoryItemDto.fromJson(Map<String, dynamic> json) {
    // New backend (mapUserOrderListItem) uses: nameEn / nameMm / imageUrl.
    // Legacy shape used: menuItemName / menuItemNameMm / menuItemImageUrl.
    final menuItemNameEn = (json['menuItemName'] as String?) ??
        (json['nameEn'] as String?);
    return OrderHistoryItemDto(
      menuItemId: json['menuItemId'] as int?,
      menuItemName: menuItemNameEn ?? 'Item',
      menuItemNameEn: menuItemNameEn,
      menuItemNameMm: (json['menuItemNameMm'] as String?) ??
          (json['nameMm'] as String?),
      menuItemNameTh: (json['menuItemNameTh'] as String?) ??
          (json['nameTh'] as String?),
      menuItemImageUrl: (json['menuItemImageUrl'] as String?) ??
          (json['imageUrl'] as String?),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
      displayPrice: json['displayPrice'] as String?,
    );
  }
}
