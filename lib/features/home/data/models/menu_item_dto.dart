import '../../../../core/utils/image_utils.dart';

class MenuItemDto {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String title;
  final double price;
  final String currency;
  final String imagePath;
  final String category;
  final bool isFavorite;
  final double rating;
  final double? originalPrice;
  final String? displayPrice;

  MenuItemDto({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.title,
    required this.price,
    required this.currency,
    required this.imagePath,
    required this.category,
    this.isFavorite = false,
    this.rating = 0.0,
    this.originalPrice,
    this.displayPrice,
  });

  factory MenuItemDto.fromJson(Map<String, dynamic> json) {
    return MenuItemDto(
      id: json['id']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName'] ?? '',
      title: json['title'] ?? '',
      price: _parsePrice(json['price']),
      currency: json['currency'] as String? ?? '฿',
      imagePath: ImageUtils.cleanImageUrl(json['imagePath']) ?? '',
      category: json['category'] ?? '',
      isFavorite: json['isFavorite'] ?? false,
      rating: _parsePrice(json['rating']),
      originalPrice: json['originalPrice'] != null ? _parsePrice(json['originalPrice']) : null,
      displayPrice: json['displayPrice'] as String?,
    );
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'title': title,
      'price': price,
      'currency': currency,
      'imagePath': imagePath,
      'category': category,
      'isFavorite': isFavorite,
      'rating': rating,
       'originalPrice': originalPrice,
      'displayPrice': displayPrice,
    };
  }

  factory MenuItemDto.fromDishJson(Map<String, dynamic> json) {
    return MenuItemDto(
      id: json['id']?.toString() ?? '',
      restaurantId: json['shopId']?.toString() ?? '',
      restaurantName: json['shopNameEn'] as String? ?? json['shopName'] as String? ?? json['shopNameMm'] as String? ?? '',
      title: json['nameEn'] as String? ?? json['name'] as String? ?? json['nameMm'] as String? ?? '',
      price: _parsePrice(json['price']),
      currency: json['currency'] as String? ?? '฿',
      imagePath: ImageUtils.cleanImageUrl(json['imageUrl']) ?? '',
      category: '',
      isFavorite: json['isFavorite'] ?? false,
      rating: _parsePrice(json['rating']),
      originalPrice: json['originalPrice'] != null ? _parsePrice(json['originalPrice']) : null,
      displayPrice: json['displayPrice'] as String?,
    );
  }
}
