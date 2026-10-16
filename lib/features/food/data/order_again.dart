import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/features/auth/data/repositories/user_location_repository.dart';
import 'package:mytogetherapp/features/home/data/repositories/restaurant_repository.dart';
import 'package:mytogetherapp/features/home/data/restaurant_data.dart';
import 'package:mytogetherapp/features/order/data/models/order_history_dto.dart';
import 'package:mytogetherapp/features/order/data/repositories/order_repository.dart';

/// Choices from the most recent finished order of one dish.
class PastMenuChoice {
  final int? variantId;
  final List<int> additionalVariantIds;
  final List<int> optionIds;
  final String? instructions;

  const PastMenuChoice({
    this.variantId,
    this.additionalVariantIds = const [],
    this.optionIds = const [],
    this.instructions,
  });
}

const _finishedStatuses = ['DELIVERED', 'PICKED_UP'];

/// Restaurants the user has received an order from, newest order first.
Future<List<Restaurant>> loadOrderAgainRestaurants({int maxShops = 8}) async {
  if (!AuthService().isLoggedIn) return const [];

  final orders = await OrderRepository().getOrderHistory(
    statuses: _finishedStatuses,
    page: 1,
    size: 40,
  );

  final shopIds = <int>[];
  final seen = <int>{};
  for (final order in orders) {
    final shopId = order.shopId;
    if (shopId == null || shopId <= 0 || !seen.add(shopId)) continue;
    final status = order.status.toUpperCase();
    if (status != 'DELIVERED' && status != 'PICKED_UP') {
      seen.remove(shopId);
      continue;
    }
    shopIds.add(shopId);
    if (shopIds.length >= maxShops) break;
  }
  if (shopIds.isEmpty) return const [];

  final coords =
      await UserLocationRepository.instance.resolveActiveCoordinates();
  final loaded = await Future.wait(
    shopIds.map((id) async {
      try {
        return await RestaurantRepository.instance.getShopById(
          id,
          lat: coords.lat,
          lon: coords.lon,
        );
      } catch (_) {
        return null;
      }
    }),
  );

  return [for (final shop in loaded) ?shop];
}

/// One line from the customer's most recent finished order at a restaurant.
class LastOrderDish {
  final int menuItemId;
  final int quantity;
  final String name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final String imageUrl;
  final double price;
  final PastMenuChoice choice;

  const LastOrderDish({
    required this.menuItemId,
    required this.quantity,
    required this.name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    required this.imageUrl,
    required this.price,
    required this.choice,
  });
}

/// Dishes from the newest finished order at [shopId], in that order.
Future<List<LastOrderDish>> loadLastOrderDishes(int shopId) async {
  if (!AuthService().isLoggedIn || shopId <= 0) return const [];

  final orders = await OrderRepository().getOrderHistory(
    statuses: _finishedStatuses,
    shopId: shopId,
    page: 1,
    size: 10,
  );

  for (final order in orders) {
    final status = order.status.toUpperCase();
    if (status != 'DELIVERED' && status != 'PICKED_UP') continue;
    final dishes = <LastOrderDish>[];
    final lines = await _linesForLastOrder(order);
    for (final item in lines) {
      final menuItemId = item.menuItemId;
      if (menuItemId == null || menuItemId <= 0) continue;
      dishes.add(
        LastOrderDish(
          menuItemId: menuItemId,
          quantity: item.quantity < 1 ? 1 : item.quantity,
          name: item.menuItemName,
          nameEn: item.menuItemNameEn,
          nameMm: item.menuItemNameMm,
          nameTh: item.menuItemNameTh,
          imageUrl: item.menuItemImageUrl ?? '',
          price: item.price,
          choice: _choiceFrom(item),
        ),
      );
    }
    return dishes;
  }
  return const [];
}

/// Ids from [menuItemIds] that can still be ordered at [shopId].
/// Deleted, hidden, and sold-out dishes are absent. `null` means the check
/// failed, so the row should not pretend every dish is gone.
Future<Set<int>?> loadOrderableMenuItemIds(
  int shopId,
  List<int> menuItemIds,
) async {
  final ids = menuItemIds.where((id) => id > 0).toSet();
  if (shopId <= 0 || ids.isEmpty) return <int>{};
  try {
    final response = await ApiClient().dio.get(
      '${ApiClient.apiPrefix}/user/menu-items/orderable',
      queryParameters: {
        'shopId': shopId,
        'ids': ids.join(','),
      },
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final raw = data is Map ? data['ids'] : null;
    if (raw is! List) return null;
    return raw
        .map((id) => int.tryParse(id.toString()) ?? 0)
        .where((id) => id > 0)
        .toSet();
  } catch (_) {
    return null;
  }
}

Future<List<OrderHistoryItemDto>> _linesForLastOrder(
  OrderHistoryDto order,
) async {
  final orderId = int.tryParse(order.id);
  if (orderId == null) return order.items;
  try {
    final loaded = await OrderRepository().getAllOrderItems(orderId: orderId);
    if (loaded.isNotEmpty) {
      return loaded.length > 40 ? loaded.sublist(0, 40) : loaded;
    }
  } catch (_) {}
  return order.items;
}

PastMenuChoice _choiceFrom(OrderHistoryItemDto item) {
  final note = item.specialInstructions?.trim();
  return PastMenuChoice(
    variantId: item.variantId,
    additionalVariantIds: item.additionalVariantIds,
    optionIds: item.optionIds,
    instructions: note == null || note.isEmpty ? null : note,
  );
}
