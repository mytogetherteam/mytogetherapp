/// Mirrors the backend's `OrderReview` projection returned by:
///   POST /api/user/order-reviews
///   GET  /api/user/order-reviews
///   GET  /api/user/order-reviews/by-order/:orderId
///   GET  /api/user/order-reviews/:id
///
/// Backend service: myshop_demo_api/src/modules/order-review/user/user-order-review.service.ts
library;

import '../../../../core/localization/locale_controller.dart';

class OrderReviewDto {
  final int id;
  final double rating;
  final String? comment;
  final int? orderId;
  final String? createdAt;
  final String? updatedAt;
  final OrderReviewOrderInfo? order;

  OrderReviewDto({
    required this.id,
    required this.rating,
    this.comment,
    this.orderId,
    this.createdAt,
    this.updatedAt,
    this.order,
  });

  factory OrderReviewDto.fromJson(Map<String, dynamic> json) {
    final orderMap = json['order'];
    return OrderReviewDto(
      id: (json['id'] as num).toInt(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] as String?,
      orderId: (json['orderId'] as num?)?.toInt(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      order: orderMap is Map<String, dynamic>
          ? OrderReviewOrderInfo.fromJson(orderMap)
          : null,
    );
  }
}

class OrderReviewOrderInfo {
  final int id;
  final String? lastOrderNo;
  final String? status;
  final int? shopId;
  final OrderReviewShopInfo? shop;

  OrderReviewOrderInfo({
    required this.id,
    this.lastOrderNo,
    this.status,
    this.shopId,
    this.shop,
  });

  factory OrderReviewOrderInfo.fromJson(Map<String, dynamic> json) {
    final shopMap = json['shop'];
    return OrderReviewOrderInfo(
      id: (json['id'] as num).toInt(),
      lastOrderNo: json['lastOrderNo']?.toString(),
      status: json['status']?.toString(),
      shopId: (json['shopId'] as num?)?.toInt(),
      shop: shopMap is Map<String, dynamic>
          ? OrderReviewShopInfo.fromJson(shopMap)
          : null,
    );
  }
}

class OrderReviewShopInfo {
  final int id;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;

  OrderReviewShopInfo({
    required this.id,
    this.nameEn,
    this.nameMm,
    this.nameTh,
  });

  factory OrderReviewShopInfo.fromJson(Map<String, dynamic> json) {
    return OrderReviewShopInfo(
      id: (json['id'] as num).toInt(),
      nameEn: json['nameEn']?.toString(),
      nameMm: json['nameMm']?.toString(),
      nameTh: json['nameTh']?.toString(),
    );
  }

  String get displayName => LocaleController.instance
      .localized(en: nameEn, mm: nameMm, th: nameTh);
}
