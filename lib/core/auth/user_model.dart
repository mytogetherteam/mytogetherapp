class UserModel {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final String? avatarUrl;
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
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? 'USER',
      avatarUrl: json['avatarUrl'] as String?,
      isVegetarian: json['isVegetarian'] as bool?,
      isHalal: json['isHalal'] as bool?,
      pricePreference: json['pricePreference'] as String?,
      spicinessPreference: json['spicinessPreference'] as String?,
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
      'isVegetarian': isVegetarian,
      'isHalal': isHalal,
      'pricePreference': pricePreference,
      'spicinessPreference': spicinessPreference,
    };
  }
}
