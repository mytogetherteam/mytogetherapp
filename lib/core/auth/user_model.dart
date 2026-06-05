class UserModel {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final String? phone;
  final String? address;
  final bool? isVegetarian;
  final bool? isHalal;
  final String? pricePreference;
  final String? spicinessPreference;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.address,
    this.isVegetarian,
    this.isHalal,
    this.pricePreference,
    this.spicinessPreference,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? json['userId']) as int? ?? 0,
      username: json['username'] as String? ?? json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'USER',
      avatarUrl: json['avatarUrl'] as String? ?? json['profileUrl'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      isVegetarian: json['isVegetarian'] as bool?,
      isHalal: json['isHalal'] as bool?,
      pricePreference: json['pricePreference'] as String?,
      spicinessPreference: json['spicinessPreference'] as String?,
    );
  }

  UserModel copyWith({
    String? username,
    String? email,
    String? fullName,
    String? avatarUrl,
    String? phone,
    String? address,
  }) {
    return UserModel(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      isVegetarian: isVegetarian,
      isHalal: isHalal,
      pricePreference: pricePreference,
      spicinessPreference: spicinessPreference,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'role': role,
      'avatarUrl': avatarUrl,
      'phone': phone,
      'address': address,
      'isVegetarian': isVegetarian,
      'isHalal': isHalal,
      'pricePreference': pricePreference,
      'spicinessPreference': spicinessPreference,
    };
  }
}
