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
    return UserLocationModel(
      id: json['id'] as int? ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationName: json['locationName'] as String?,
      locationType: json['locationType'] as String?,
      address: (json['addressEn'] as String?) ?? (json['address'] as String?),
      addressMm: json['addressMm'] as String?,
      addressTh: json['addressTh'] as String?,
      buildingName: json['buildingName'] as String?,
      postalCode: json['postalCode'] as String?,
      floor: json['floor'] as String?,
      note: json['note'] as String?,
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'locationType': locationType,
      'address': address,
      'addressEn': address, // Send same as address for compatibility
      'addressMm': addressMm,
      'addressTh': addressTh,
      'buildingName': buildingName,
      'postalCode': postalCode,
      'floor': floor,
      'note': note,
      'isPrimary': isPrimary,
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
