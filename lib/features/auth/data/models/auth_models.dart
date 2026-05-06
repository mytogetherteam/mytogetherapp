class LoginRequest {
  final String usernameOrEmail;
  final String password;

  LoginRequest({required this.usernameOrEmail, required this.password});

  // Shop API expects: { emailOrUsername, password }
  Map<String, dynamic> toJson() => {
        'emailOrUsername': usernameOrEmail,
        'password': password,
      };
}

class RegisterRequest {
  final String username;
  final String email;
  final String password;
  final String fullName;

  RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    required this.fullName,
  });

  // Shop API expects: { email, password, name, username, role }
  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'password': password,
        'name': fullName,      // shop API uses 'name' not 'fullName'
        'role': 'CUSTOMER',    // always register as customer
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
