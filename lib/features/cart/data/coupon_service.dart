import 'dart:math' as math;
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../search/data/search_repository.dart';

/// A BUY / GET item attached to a coupon (used for BUY_X_GET_FREE coupons).
class CouponItem {
  final String type; // BUY | GET
  final int menuItemId;
  final String name;
  final String? imageUrl;
  final double? price;
  final int quantity;

  const CouponItem({
    required this.type,
    required this.menuItemId,
    required this.name,
    this.imageUrl,
    this.price,
    this.quantity = 1,
  });

  factory CouponItem.fromJson(Map<String, dynamic> json) => CouponItem(
        type: json['type']?.toString() ?? 'GET',
        menuItemId: (json['menuItemId'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString(),
        price: (json['price'] as num?)?.toDouble(),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );

  bool get isGet => type.toUpperCase() == 'GET';
}

/// The shop a coupon belongs to (returned by the cross-shop coupon list).
class CouponShop {
  final int id;
  final String nameEn;
  final String? nameMm;
  final String? nameTh;
  final String? slug;

  const CouponShop({
    required this.id,
    required this.nameEn,
    this.nameMm,
    this.nameTh,
    this.slug,
  });

  factory CouponShop.fromJson(Map<String, dynamic> json) => CouponShop(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nameEn: json['nameEn']?.toString() ?? '',
        nameMm: json['nameMm']?.toString(),
        nameTh: json['nameTh']?.toString(),
        slug: json['slug']?.toString(),
      );
}

/// A coupon the user can apply to a pending order, with the previewed discount.
class CouponModel {
  final int id;
  final String code;
  final String name;
  final String? description;
  final String promotionType; // BUY_X_GET_DISCOUNT | BUY_X_GET_FREE
  final String? discountType; // PERCENTAGE | FIXED_AMOUNT
  final double discountValue;
  final String target; // ALL | EARLY_BIRD
  final String limitType; // ONE_TIME | PERMANENT
  final double discountPreview;
  final List<CouponItem> items;
  final bool bogoAllItems;
  final int? shopId;
  final CouponShop? shop;
  final DateTime? validFrom;
  final DateTime? validUntil;

  const CouponModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.promotionType,
    this.discountType,
    this.discountValue = 0,
    this.target = 'ALL',
    this.limitType = 'ONE_TIME',
    this.discountPreview = 0,
    this.items = const [],
    this.bogoAllItems = false,
    this.shopId,
    this.shop,
    this.validFrom,
    this.validUntil,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) => CouponModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        promotionType: json['promotionType']?.toString() ?? 'BUY_X_GET_DISCOUNT',
        discountType: json['discountType']?.toString(),
        discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
        target: json['target']?.toString() ?? 'ALL',
        limitType: json['limitType']?.toString() ?? 'ONE_TIME',
        discountPreview: (json['discountPreview'] as num?)?.toDouble() ?? 0,
        items: (json['items'] as List?)
                ?.map((e) => CouponItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        bogoAllItems: json['bogoAllItems'] == true,
        shopId: (json['shopId'] as num?)?.toInt(),
        shop: json['shop'] is Map
            ? CouponShop.fromJson(Map<String, dynamic>.from(json['shop'] as Map))
            : null,
        validFrom: DateTime.tryParse(json['validFrom']?.toString() ?? ''),
        validUntil: DateTime.tryParse(json['validUntil']?.toString() ?? ''),
      );

  CouponModel copyWith({double? discountPreview}) => CouponModel(
        id: id,
        code: code,
        name: name,
        description: description,
        promotionType: promotionType,
        discountType: discountType,
        discountValue: discountValue,
        target: target,
        limitType: limitType,
        discountPreview: discountPreview ?? this.discountPreview,
        items: items,
        bogoAllItems: bogoAllItems,
        shopId: shopId,
        shop: shop,
        validFrom: validFrom,
        validUntil: validUntil,
      );

  /// The shop id to navigate to, preferring the top-level field, then [shop].
  int? get resolvedShopId => shopId ?? shop?.id;

  /// Items the customer must buy to unlock a BUY_X_GET_FREE coupon.
  List<CouponItem> get buyItems =>
      items.where((i) => i.type.toUpperCase() == 'BUY').toList();

  bool get isFreeItem => promotionType.toUpperCase() == 'BUY_X_GET_FREE';
  bool get isPercentage => (discountType ?? '').toUpperCase() == 'PERCENTAGE';
  bool get isFixed => (discountType ?? '').toUpperCase() == 'FIXED_AMOUNT';
  bool get isEarlyBird => target.toUpperCase() == 'EARLY_BIRD';

  /// Shop-wide buy-one-get-one (no configured BUY/GET lines in the API payload).
  bool get isBogoAllItems =>
      bogoAllItems || (isFreeItem && items.isEmpty);

  /// Percentage or fixed-amount discount coupon (not BOGO / gift menu).
  bool get isPercentOrAmountDiscount =>
      !isFreeItem &&
      (isPercentage || isFixed || promotionType.toUpperCase() == 'BUY_X_GET_DISCOUNT');

  /// The big headline shown on the ticket stub (e.g. "30%", "฿50", "1+1", "FREE").
  String get stubHeadline {
    if (isFreeItem) return isBogoAllItems ? '1+1' : 'FREE';
    if (isPercentage) return '${_trimNum(discountValue)}%';
    return '฿${_trimNum(discountValue)}';
  }

  /// The free GET items granted by a BUY_X_GET_FREE coupon.
  List<CouponItem> get freeItems => items.where((i) => i.isGet).toList();

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// The result of applying a coupon to a pending order.
class CouponApplyResult {
  final int orderId;
  final int couponId;
  final String couponCode;
  final String couponName;
  final double discountAmount;
  final double itemPrice;
  final double taxAmount;
  final double totalAmount;

  const CouponApplyResult({
    required this.orderId,
    required this.couponId,
    required this.couponCode,
    required this.couponName,
    required this.discountAmount,
    required this.itemPrice,
    required this.taxAmount,
    required this.totalAmount,
  });

  factory CouponApplyResult.fromJson(Map<String, dynamic> json) =>
      CouponApplyResult(
        orderId: (json['orderId'] as num?)?.toInt() ?? 0,
        couponId: (json['couponId'] as num?)?.toInt() ?? 0,
        couponCode: json['couponCode']?.toString() ?? '',
        couponName: json['couponName']?.toString() ?? '',
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
        itemPrice: (json['itemPrice'] as num?)?.toDouble() ?? 0,
        taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      );
}

/// Thrown when applying a coupon fails, carrying the backend's message.
class CouponApplyException implements Exception {
  final String message;
  const CouponApplyException(this.message);
  @override
  String toString() => message;
}

/// A rotating, short-lived redeem QR token issued for in-shop redemption.
class RedeemTokenResult {
  final int userId;
  final String token;
  final int expiresInSec;

  const RedeemTokenResult({
    required this.userId,
    required this.token,
    required this.expiresInSec,
  });

  factory RedeemTokenResult.fromJson(Map<String, dynamic> json) =>
      RedeemTokenResult(
        userId: (json['userId'] as num?)?.toInt() ?? 0,
        token: json['token']?.toString() ?? '',
        expiresInSec: (json['expiresInSec'] as num?)?.toInt() ?? 0,
      );

  /// The payload encoded into the QR. The shop app reads `userId` + `token`.
  String get qrPayload => '{"userId":$userId,"token":"$token"}';
}

/// A cart line used to preview a coupon's discount client-side.
typedef CouponCartLine = ({int menuItemId, int quantity, double price});

/// Talks to the user-facing coupon endpoints for the in-app checkout flow.
class CouponService {
  CouponService._();
  static final CouponService instance = CouponService._();

  /// Eligible coupons for a shop (active, in-window, target-eligible, not used).
  /// Used to let the user pick a coupon on the summary page *before* the order
  /// exists; the precise discount is previewed client-side via [computePreview]
  /// and re-validated server-side on apply. Returns [] on any failure.
  Future<List<CouponModel>> fetchByShop(int shopId) async {
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/coupons/shops/$shopId',
      );
      final data = _unwrap(response.data);
      final coupons = data?['coupons'];
      if (coupons is! List) return const [];
      return coupons
          .whereType<Map>()
          .map((e) => CouponModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Active coupons across all shops the user can still use, paginated.
  /// [target] filters by `all` or `earlybird`; omit for default backend rules
  /// (early-bird users see ALL + EARLY_BIRD).
  ///
  /// Throws on a request/parse failure so callers can tell a genuine empty
  /// result (hide the rail) apart from a transient error (retry). This matters
  /// on the Home tab, where many sections fetch at once and a swallowed failure
  /// would otherwise make the early-bird rail silently vanish until refresh.
  Future<List<CouponModel>> fetchAllCoupons({
    String? target,
    int page = 1,
    int size = 20,
  }) async {
    final response = await ApiClient().dio.get(
      '${ApiClient.apiPrefix}/user/coupons',
      queryParameters: {
        'page': page,
        'size': size,
        if (target != null && target.isNotEmpty) 'target': target,
      },
    );
    final body = response.data;
    if (body is! Map) return const [];
    final list = body['data'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => CouponModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// In-memory cache of resolved shop logo URLs, keyed by shopId, so the two
  /// coupon rails and the details sheet share a single lookup per shop.
  final Map<int, Future<String?>> _shopLogoCache = {};

  /// Resolves a shop's logo URL from the existing shop-profile endpoint, since
  /// the coupon list endpoint doesn't include it. Cached and de-duped per shop;
  /// returns null on any failure (the card falls back to a letter avatar).
  Future<String?> fetchShopLogo(int shopId) {
    return _shopLogoCache.putIfAbsent(shopId, () async {
      try {
        final shop = await SearchRepository.instance.getShopProfileById(shopId);
        return _resolveImageUrl(shop?.logoUrl ?? shop?.coverUrl);
      } catch (_) {
        return null;
      }
    });
  }

  static String? _resolveImageUrl(String? path) {
    if (path == null) return null;
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed.startsWith('assets/')) return null;
    if (trimmed.startsWith('http')) return trimmed;
    return '${ApiClient.baseUrl}/'
        '${trimmed.startsWith('/') ? trimmed.substring(1) : trimmed}';
  }

  /// Issues a fresh rotating redeem QR token for the current user (for the
  /// in-shop "Use now" flow). Throws [CouponApplyException] on failure.
  Future<RedeemTokenResult> issueRedeemToken() async {
    try {
      final response = await ApiClient().dio.post(
        '${ApiClient.apiPrefix}/user/coupons/redeem-token',
      );
      final data = _unwrap(response.data);
      if (data == null) {
        throw const CouponApplyException('Could not generate a QR code');
      }
      return RedeemTokenResult.fromJson(data);
    } on DioException catch (e) {
      throw CouponApplyException(_messageFromDio(e));
    }
  }

  /// Mirrors the backend's discount calculation so the summary page can show an
  /// accurate, live preview before the order is created. The authoritative value
  /// is still computed server-side when the coupon is applied to the order.
  static double computePreview({
    required CouponModel coupon,
    required double subtotal,
    required List<CouponCartLine> items,
  }) {
    if (subtotal <= 0) return 0;

    if (!coupon.isFreeItem) {
      if (coupon.isPercentage) {
        return _round2(math.min(subtotal, subtotal * coupon.discountValue / 100));
      }
      if (coupon.isFixed) {
        return _round2(math.min(coupon.discountValue, subtotal));
      }
      return 0;
    }

    // Shop-wide BOGO: free quantity equals paid quantity → discount equals subtotal.
    if (coupon.isBogoAllItems) {
      return items.isEmpty ? 0 : _round2(subtotal);
    }

    // BUY_X_GET_FREE: GET items are made free (cheapest matching units) only
    // when every required BUY item is present in the cart at its quantity.
    final buyItems =
        coupon.items.where((i) => i.type.toUpperCase() == 'BUY').toList();
    final getItems = coupon.items.where((i) => i.isGet).toList();
    if (getItems.isEmpty) return 0;

    final orderedQty = <int, int>{};
    for (final it in items) {
      orderedQty[it.menuItemId] = (orderedQty[it.menuItemId] ?? 0) + it.quantity;
    }

    final hasAllBuy =
        buyItems.every((b) => (orderedQty[b.menuItemId] ?? 0) >= b.quantity);
    if (!hasAllBuy) return 0;

    double freeValue = 0;
    for (final get in getItems) {
      final unitPrices = <double>[];
      for (final it in items) {
        if (it.menuItemId != get.menuItemId) continue;
        for (var k = 0; k < it.quantity; k++) {
          unitPrices.add(it.price);
        }
      }
      unitPrices.sort();
      final freeUnits = math.min(get.quantity, unitPrices.length);
      for (var k = 0; k < freeUnits; k++) {
        freeValue += unitPrices[k];
      }
    }
    if (freeValue <= 0) return 0;
    return _round2(math.min(freeValue, subtotal));
  }

  static double _round2(double n) => (n * 100).round() / 100;

  /// Coupons that apply to a freshly created PENDING order, with a discount
  /// preview for each. Returns an empty list on any failure (coupons are an
  /// optional enhancement and must never block checkout).
  Future<List<CouponModel>> fetchAvailable(int orderId) async {
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/coupons/available',
        queryParameters: {'orderId': orderId},
      );
      final data = _unwrap(response.data);
      final coupons = data?['coupons'];
      if (coupons is! List) return const [];
      return coupons
          .whereType<Map>()
          .map((e) => CouponModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Applies the chosen coupon to the user's pending order. Throws a
  /// [DioException] (with the backend message) on failure so the UI can react.
  Future<CouponApplyResult> apply({
    required int orderId,
    required int couponId,
  }) async {
    try {
      final response = await ApiClient().dio.post(
        '${ApiClient.apiPrefix}/user/coupons/apply',
        data: {'orderId': orderId, 'couponId': couponId},
      );
      final data = _unwrap(response.data);
      if (data == null) {
        throw const CouponApplyException('Could not apply the coupon');
      }
      return CouponApplyResult.fromJson(data);
    } on DioException catch (e) {
      throw CouponApplyException(_messageFromDio(e));
    }
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (data is String && data.isNotEmpty) return data;
    return e.message ?? 'Could not apply the coupon';
  }

  Map<String, dynamic>? _unwrap(dynamic body) {
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);
    if (map['data'] is Map) {
      return Map<String, dynamic>.from(map['data'] as Map);
    }
    return map;
  }
}
