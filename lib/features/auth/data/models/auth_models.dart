class LoginRequest {
  final String phone;
  final String pin;

  LoginRequest({required this.phone, required this.pin});

  // Shop API expects: { phone, pin }
  Map<String, dynamic> toJson() => {
        'phone': phone,
        'pin': pin,
      };
}

class RegisterRequest {
  final String idToken;
  final String pin;
  final String? name;
  final String? email;

  RegisterRequest({
    required this.idToken,
    required this.pin,
    this.name,
    this.email,
  });

  Map<String, dynamic> toJson() => {
        'idToken': idToken,
        'pin': pin,
        if (name != null && name!.isNotEmpty) 'name': name,
        if (email != null && email!.isNotEmpty) 'email': email,
      };
}

class AuthResponse {
  final String token;
  final String refreshToken;
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String role;

  AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      id: (json['id'] ?? json['userId']) as int? ?? 0,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      // Shop API returns 'fullName' (mapped from 'name' in mapOrder)
      fullName: json['fullName'] as String? ?? json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'CUSTOMER',
    );
  }
}
