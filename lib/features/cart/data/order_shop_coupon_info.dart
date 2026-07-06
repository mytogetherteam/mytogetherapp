import 'package:flutter/widgets.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/localization/locale_controller.dart';

/// One BUY/GET line from `shopCoupon.items` on an order API response.
class OrderShopCouponItem {
  final String type;
  final int menuItemId;
  final int quantity;
  final String? name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;

  const OrderShopCouponItem({
    this.type = 'GET',
    this.menuItemId = 0,
    this.quantity = 1,
    this.name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
  });

  factory OrderShopCouponItem.fromJson(Map<String, dynamic> json) =>
      OrderShopCouponItem(
        type: json['type']?.toString() ?? 'GET',
        menuItemId: (json['menuItemId'] as num?)?.toInt() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        name: json['name']?.toString(),
        nameEn: json['nameEn']?.toString(),
        nameMm: json['nameMm']?.toString(),
        nameTh: json['nameTh']?.toString(),
      );

  bool get isBuy => type.toUpperCase() == 'BUY';
  bool get isGet => type.toUpperCase() == 'GET';

  String get displayName {
    final localized = LocaleController.instance.localized(
      en: nameEn ?? name ?? '',
      mm: nameMm,
      th: nameTh,
    ).trim();
    if (localized.isNotEmpty) return localized;
    return 'Item #$menuItemId';
  }
}

/// Applied coupon snapshot from order `shopCoupon` (read-only).
class OrderShopCouponInfo {
  final String name;
  final String? code;
  final String promotionType;
  final String? discountType;
  final double discountValue;
  final bool bogoAllItems;
  final List<OrderShopCouponItem> items;

  const OrderShopCouponInfo({
    this.name = '',
    this.code,
    this.promotionType = 'BUY_X_GET_DISCOUNT',
    this.discountType,
    this.discountValue = 0,
    this.bogoAllItems = false,
    this.items = const [],
  });

  factory OrderShopCouponInfo.fromJson(Map<String, dynamic> json) =>
      OrderShopCouponInfo(
        name: json['name']?.toString() ?? '',
        code: json['code']?.toString(),
        promotionType:
            json['promotionType']?.toString() ?? 'BUY_X_GET_DISCOUNT',
        discountType: json['discountType']?.toString(),
        discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
        bogoAllItems: json['bogoAllItems'] == true,
        items: (json['items'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    OrderShopCouponItem.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'promotionType': promotionType,
        'discountType': discountType,
        'discountValue': discountValue,
        'bogoAllItems': bogoAllItems,
        'items': items
            .map((i) => {
                  'type': i.type,
                  'menuItemId': i.menuItemId,
                  'quantity': i.quantity,
                  'name': i.name,
                  'nameEn': i.nameEn,
                  'nameMm': i.nameMm,
                  'nameTh': i.nameTh,
                })
            .toList(),
      };

  bool get isFreeItem => promotionType.toUpperCase() == 'BUY_X_GET_FREE';
  bool get isBogoAllItems =>
      bogoAllItems || (isFreeItem && items.isEmpty);
  List<OrderShopCouponItem> get buyItems =>
      items.where((i) => i.isBuy).toList();
  List<OrderShopCouponItem> get freeItems =>
      items.where((i) => i.isGet).toList();

  /// Human-readable gift/BOGO line for order summary UIs.
  String itemsHint(BuildContext context) {
    if (!isFreeItem) return '';

    final free = freeItems;
    if (free.isNotEmpty) {
      final names = free
          .map((i) =>
              i.quantity > 1 ? '${i.displayName} x${i.quantity}' : i.displayName)
          .join(', ');
      final buy = buyItems.map((i) => i.displayName).where((e) => e.isNotEmpty);
      if (buy.isNotEmpty) {
        return context.trArgs('coupon.buy_get_summary', {
          'buy': buy.join(', '),
          'free': names,
        });
      }
      return context.trArgs('coupon.free_items', {'items': names});
    }

    if (isBogoAllItems) {
      return context.tr('coupon.bogo_on_order');
    }
    return context.tr('coupon.free_item_generic');
  }
}
