import 'package:dio/dio.dart';

/// Pulls a human-readable message from a [DioException] response body.
/// NestJS errors usually expose `{ message: "..." }` or `{ message: ["..."] }`.
String dioErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is DioException) {
    final serverMessage = _readServerMessage(error.response?.data);
    if (serverMessage != null) return serverMessage;

    final status = error.response?.statusCode;
    if (status == null ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please try again.';
    }
    if (status == 409) {
      return 'This action conflicts with an existing record. Please try again.';
    }
  }
  return fallback;
}

String? _readServerMessage(dynamic body) {
  if (body is! Map) return null;
  final raw = body['message'] ?? body['error'];
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  if (raw is List && raw.isNotEmpty) {
    return raw.map((e) => e.toString()).join('\n');
  }
  return null;
}
