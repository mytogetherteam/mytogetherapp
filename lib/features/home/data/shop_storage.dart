import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/shop_dto.dart';

class ShopStorage {
  static const String _prefix = 'shop_detail_';

  static Future<void> saveShop(int shopId, Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$shopId', jsonEncode(json));
  }

  static Future<Map<String, dynamic>?> getShop(int shopId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_prefix$shopId');
    if (jsonStr == null) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<List<ShopPaymentTypeDto>?> getPaymentTypes(int shopId) async {
    final shopJson = await getShop(shopId);
    if (shopJson == null) return null;
    
    // The JSON stored is the full response or the data part. 
    // Assuming we store the 'data' part of ApiResponseShopDetailDto
    final paymentTypesJson = shopJson['paymentTypes'] as List?;
    if (paymentTypesJson == null) return null;
    
    return paymentTypesJson
        .map((e) => ShopPaymentTypeDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
