import 'package:dio/dio.dart';
import '../../../core/auth/auth_service.dart';
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
  /// Server-computed ฿-off (0 for BUY_X_GET_FREE — free lines, not food wipe).
  final double discountPreview;
  final List<CouponItem> items;

  /// Server-predicted free lines (from POST /user/coupons/preview).
  final List<CouponItem> freeItemGrants;
  final bool bogoAllItems;
  final int? shopId;
  final CouponShop? shop;
  final DateTime? validFrom;
  final DateTime? validUntil;

  /// Wishlist API sets this; browse/shop lists omit it (defaults to usable).
  final bool isUsable;
  final bool isExpired;

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
    this.freeItemGrants = const [],
    this.bogoAllItems = false,
    this.shopId,
    this.shop,
    this.validFrom,
    this.validUntil,
    this.isUsable = true,
    this.isExpired = false,
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
    items:
        (json['items'] as List?)
            ?.map(
              (e) => CouponItem.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList() ??
        const [],
    freeItemGrants:
        (json['freeItems'] as List?)
            ?.map(
              (e) => CouponItem.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList() ??
        const [],
    bogoAllItems: json['bogoAllItems'] == true,
    shopId:
        (json['shopId'] as num?)?.toInt() ??
        (json['shop'] is Map ? (json['shop']['id'] as num?)?.toInt() : null),
    shop: json['shop'] is Map
        ? CouponShop.fromJson(Map<String, dynamic>.from(json['shop'] as Map))
        : null,
    validFrom: DateTime.tryParse(json['validFrom']?.toString() ?? ''),
    validUntil: DateTime.tryParse(json['validUntil']?.toString() ?? ''),
    isUsable: json['isUsable'] != false,
    isExpired: json['isExpired'] == true,
  );

  /// Drops admin-deleted / inactive wishlist entries the API still bookmarks.
  static List<CouponModel> onlyUsable(Iterable<CouponModel> coupons) =>
      coupons.where((c) => c.isUsable).toList();

  CouponModel copyWith({
    double? discountPreview,
    List<CouponItem>? freeItemGrants,
    bool? bogoAllItems,
  }) => CouponModel(
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
    freeItemGrants: freeItemGrants ?? this.freeItemGrants,
    bogoAllItems: bogoAllItems ?? this.bogoAllItems,
    shopId: shopId,
    shop: shop,
    validFrom: validFrom,
    validUntil: validUntil,
    isUsable: isUsable,
    isExpired: isExpired,
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
  bool get isBogoAllItems => bogoAllItems || (isFreeItem && items.isEmpty);

  /// Percentage or fixed-amount discount coupon (not BOGO / gift menu).
  bool get isPercentOrAmountDiscount =>
      !isFreeItem &&
      (isPercentage ||
          isFixed ||
          promotionType.toUpperCase() == 'BUY_X_GET_DISCOUNT');

  /// The big headline shown on the ticket stub (e.g. "30%", "฿50", "1+1", "FREE").
  String get stubHeadline {
    if (isFreeItem) return isBogoAllItems ? '1+1' : 'FREE';
    if (isPercentage) return '${_trimNum(discountValue)}%';
    return '฿${_trimNum(discountValue)}';
  }

  /// The free GET items granted by a BUY_X_GET_FREE coupon (config).
  List<CouponItem> get freeItems => items.where((i) => i.isGet).toList();

  /// Preview grants from the server when present; otherwise configured GET items.
  List<CouponItem> get previewFreeItems =>
      freeItemGrants.isNotEmpty ? freeItemGrants : freeItems;

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
  final bool bogoAllItems;
  final List<CouponItem> freeItems;

  const CouponApplyResult({
    required this.orderId,
    required this.couponId,
    required this.couponCode,
    required this.couponName,
    required this.discountAmount,
    required this.itemPrice,
    required this.taxAmount,
    required this.totalAmount,
    this.bogoAllItems = false,
    this.freeItems = const [],
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
        bogoAllItems: json['bogoAllItems'] == true,
        freeItems:
            (json['freeItems'] as List?)
                ?.map(
                  (e) =>
                      CouponItem.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList() ??
            const [],
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

/// Cart line for [previewForCart] (prices are sent to the server; not discounted here).
typedef CouponCartLine = ({int menuItemId, int quantity, double price});

/// Talks to the user-facing coupon endpoints for the in-app checkout flow.
class CouponService {
  CouponService._();
  static final CouponService instance = CouponService._();

  /// Eligible coupons for a shop (active, in-window, target-eligible, not used).
  /// Cart-specific discount / free-item amounts come from [previewForCart].
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

  /// Server-side preview for the current cart (฿-off and/or free items).
  /// The app must display these values — do not invent Buy 1 Get 1 math locally.
  Future<List<CouponModel>> previewForCart({
    required int shopId,
    required List<CouponCartLine> items,
    int? couponId,
  }) async {
    if (items.isEmpty) return const [];
    try {
      final response = await ApiClient().dio.post(
        '${ApiClient.apiPrefix}/user/coupons/preview',
        data: {
          'shopId': shopId,
          'couponId': ?couponId,
          'items': items
              .map(
                (i) => {
                  'menuItemId': i.menuItemId,
                  'quantity': i.quantity,
                  'price': i.price,
                },
              )
              .toList(),
        },
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

  /// In-memory cache of resolved shop logo URLs, keyed by shopId.
  final Map<int, Future<String?>> _shopLogoCache = {};

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

  /// Cached wishlist coupon ids (populated by [fetchWishlist] / [isWishlisted]).
  Set<int>? _wishlistedIds;

  void invalidateWishlistCache() => _wishlistedIds = null;

  /// Saved coupons (`GET /user/coupons/wishlist`).
  Future<List<CouponModel>> fetchWishlist({int page = 1, int size = 50}) async {
    if (!AuthService().isLoggedIn) return const [];
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/coupons/wishlist',
        queryParameters: {'page': page, 'size': size},
      );
      final body = response.data;
      if (body is! Map) return const [];
      final list = body['data'];
      if (list is! List) return const [];
      final coupons = CouponModel.onlyUsable(
        list.whereType<Map>().map(
          (e) => CouponModel.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
      if (page == 1) {
        _wishlistedIds = coupons.map((c) => c.id).toSet();
      }
      return coupons;
    } catch (_) {
      return const [];
    }
  }

  /// Whether [couponId] is in the user's saved-coupon wishlist.
  Future<bool> isWishlisted(int couponId) async {
    if (!AuthService().isLoggedIn) return false;
    if (_wishlistedIds != null) {
      return _wishlistedIds!.contains(couponId);
    }
    await fetchWishlist(size: 200);
    return _wishlistedIds?.contains(couponId) ?? false;
  }

  /// Toggle save on a coupon (`POST /user/coupons/wishlist/toggle`).
  Future<bool> toggleWishlist(int couponId) async {
    final response = await ApiClient().dio.post(
      '${ApiClient.apiPrefix}/user/coupons/wishlist/toggle',
      data: {'couponId': couponId},
    );
    final data = _unwrap(response.data);
    final wishlisted = data?['wishlisted'] == true;
    _wishlistedIds ??= {};
    if (wishlisted) {
      _wishlistedIds!.add(couponId);
    } else {
      _wishlistedIds!.remove(couponId);
    }
    return wishlisted;
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
