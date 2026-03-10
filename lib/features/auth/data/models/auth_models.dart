class LoginRequest {
  final String usernameOrEmail;
  final String password;

  LoginRequest({required this.usernameOrEmail, required this.password});

  Map<String, dynamic> toJson() => {
        'usernameOrEmail': usernameOrEmail,
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

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'password': password,
        'fullName': fullName,
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
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? 'USER',
    );
  }
}
