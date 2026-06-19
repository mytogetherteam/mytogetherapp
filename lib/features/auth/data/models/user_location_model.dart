class UserLocationModel {
  final int id;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? locationType; // HOME, WORK, OFFICE, OTHER
  final String? address;
  final String? addressMm;
  final String? addressTh;
  final String? buildingName;
  final String? postalCode;
  final String? floor;
  final String? note;
  final bool isPrimary;

  UserLocationModel({
    required this.id,
    this.latitude,
    this.longitude,
    this.locationName,
    this.locationType,
    this.address,
    this.addressMm,
    this.addressTh,
    this.buildingName,
    this.postalCode,
    this.floor,
    this.note,
    this.isPrimary = false,
  });

  factory UserLocationModel.fromJson(Map<String, dynamic> json) {
    // Backend (myshop_demo_api / UserLocation) returns: id, userId, label,
    // latitude, longitude, isCurrent, isActive, createdAt, updatedAt.
    // Legacy shape used by older code still supported as fallback.
    final label = (json['label'] as String?) ?? (json['locationName'] as String?);

    return UserLocationModel(
      id: json['id'] as int? ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationName: label,
      locationType: json['locationType'] as String?,
      address: (json['addressEn'] as String?) ?? (json['address'] as String?),
      addressMm: json['addressMm'] as String?,
      addressTh: json['addressTh'] as String?,
      buildingName: json['buildingName'] as String?,
      postalCode: json['postalCode'] as String?,
      floor: json['floor'] as String?,
      note: json['note'] as String?,
      isPrimary: (json['isCurrent'] as bool?) ?? (json['isPrimary'] as bool? ?? false),
    );
  }

  /// Street address for delivery display and orders (excludes nickname/label).
  String? get streetAddress {
    for (final candidate in [address, addressTh, addressMm]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  /// Payload for `CreateUserLocationDto` / `UpdateUserLocationDto`.
  Map<String, dynamic> toJson() {
    return {
      if (locationName != null && locationName!.trim().isNotEmpty)
        'label': locationName!.trim(),
      if (address != null && address!.trim().isNotEmpty)
        'address': address!.trim(),
      if (buildingName != null && buildingName!.trim().isNotEmpty)
        'buildingName': buildingName!.trim(),
      if (floor != null && floor!.trim().isNotEmpty) 'floor': floor!.trim(),
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'isCurrent': isPrimary,
    };
  }

  UserLocationModel copyWith({
    int? id,
    double? latitude,
    double? longitude,
    String? locationName,
    String? locationType,
    String? address,
    String? addressMm,
    String? addressTh,
    String? buildingName,
    String? postalCode,
    String? floor,
    String? note,
    bool? isPrimary,
  }) {
    return UserLocationModel(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      locationType: locationType ?? this.locationType,
      address: address ?? this.address,
      addressMm: addressMm ?? this.addressMm,
      addressTh: addressTh ?? this.addressTh,
      buildingName: buildingName ?? this.buildingName,
      postalCode: postalCode ?? this.postalCode,
      floor: floor ?? this.floor,
      note: note ?? this.note,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
