import 'package:dio/dio.dart';
import '../auth/auth_interceptor.dart';

class ApiClient {
  static const String apiPrefix = '/api/v1/mobile';
  
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://mytogetherapi-production.up.railway.app',
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 45),
        headers: {
          'Content-Type': 'application/json',
          'Accept': '*/*',
        },
      ),
    );

    // Auth interceptor: attaches Bearer token and handles 401 auto-refresh
    _dio.interceptors.add(AuthInterceptor(_dio));

    // No logging interceptor to keep console clean for production beta
  }

  Dio get dio => _dio;
}
