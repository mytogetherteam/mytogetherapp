import 'package:intl/intl.dart';

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
      currentOrders: (data['currentOrders'] as List<dynamic>?)
              ?.map((e) => OrderHistoryDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pastOrders: (data['pastOrders'] as List<dynamic>?)
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
  final String? statusLabelMm;
  final bool ongoing;
  final String createdAt;
  final String? updatedAt;
  final double totalAmount;
  final String? displayTotalAmount;
  final String? shopName;
  final String? shopImageUrl;
  final int? shopId;
  final List<OrderHistoryItemDto> items;
  final double? deliveryFee;
  final String? displayDeliveryFee;

  OrderHistoryDto({
    required this.id,
    this.lastOrderNo,
    required this.status,
    this.statusLabel,
    this.statusLabelMm,
    required this.ongoing,
    required this.createdAt,
    this.updatedAt,
    required this.totalAmount,
    this.displayTotalAmount,
    this.shopName,
    this.shopImageUrl,
    this.shopId,
    required this.items,
    this.deliveryFee,
    this.displayDeliveryFee,
  });

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
    final shopName = json['shopName'] as String? ?? 
                     shop?['name'] as String? ?? 
                     shop?['nameEn'] as String?;
    final shopImageUrl = json['shopImageUrl'] as String? ?? 
                         json['imageUrl'] as String? ?? 
                         shop?['imageUrl'] as String? ?? 
                         shop?['logoUrl'] as String? ??
                         shop?['image'] as String?;

    return OrderHistoryDto(
      id: json['id'].toString(),
      lastOrderNo: json['lastOrderNo']?.toString(),
      status: json['status'] as String? ?? 'PENDING',
      statusLabel: json['statusLabel'] as String?,
      statusLabelMm: json['statusLabelMm'] as String?,
      ongoing: json['ongoing'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String?,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      displayTotalAmount: json['displayTotalAmount'] as String?,
      shopName: shopName,
      shopImageUrl: shopImageUrl,
      shopId: json['shopId'] as int?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderHistoryItemDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      displayDeliveryFee: json['displayDeliveryFee'] as String?,
    );
  }
}

class OrderHistoryItemDto {
  final int? menuItemId;
  final String menuItemName;
  final String? menuItemNameMm;
  final String? menuItemImageUrl;
  final double price;
  final int quantity;
  final String? displayPrice;

  OrderHistoryItemDto({
    this.menuItemId,
    required this.menuItemName,
    this.menuItemNameMm,
    this.menuItemImageUrl,
    required this.price,
    required this.quantity,
    this.displayPrice,
  });

  factory OrderHistoryItemDto.fromJson(Map<String, dynamic> json) {
    return OrderHistoryItemDto(
      menuItemId: json['menuItemId'] as int?,
      menuItemName: json['menuItemName'] as String? ?? 'Item',
      menuItemNameMm: json['menuItemNameMm'] as String?,
      menuItemImageUrl: json['menuItemImageUrl'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
      displayPrice: json['displayPrice'] as String?,
    );
  }
}
