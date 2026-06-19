import 'models/shop_dto.dart' show OperatingHourDto;

/// Shop-level order eligibility fields extracted from a menu-item or shop JSON
/// payload (flat or nested under `shop`).
class ShopOrderStateFields {
  final bool deliveryEnabled;
  final bool isOpen;
  final List<OperatingHourDto> operatingHours;

  const ShopOrderStateFields({
    this.deliveryEnabled = true,
    this.isOpen = true,
    this.operatingHours = const [],
  });

  String get status => isOpen ? 'Open' : 'Closed';

  static ShopOrderStateFields fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? shop,
  }) {
    final nested = shop ?? (json['shop'] is Map ? json['shop'] as Map : null);

    bool? readBoolKey(String key) {
      final dynamic v =
          json[key] ?? (nested is Map ? nested[key] : null);
      return v is bool ? v : null;
    }

    List<OperatingHourDto> readHours() {
      final dynamic raw = json['operatingHours'] ??
          (nested is Map ? nested['operatingHours'] : null) ??
          json['shopOperatingHours'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(OperatingHourDto.fromJson)
          .toList();
    }

    return ShopOrderStateFields(
      deliveryEnabled: readBoolKey('deliveryEnabled') ?? true,
      isOpen: readBoolKey('shopIsOpen') ?? readBoolKey('isOpen') ?? true,
      operatingHours: readHours(),
    );
  }
}
