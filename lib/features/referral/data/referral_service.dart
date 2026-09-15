import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'referral_model.dart';

class ReferralException implements Exception {
  final String message;
  const ReferralException(this.message);
  @override
  String toString() => message;
}

class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();

  Future<UserReferralStatus> getStatus() async {
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/referral/my-code',
      );
      final data = _unwrap(response.data);
      if (data == null) {
        throw const ReferralException('Unable to load referral details');
      }
      return UserReferralStatus.fromJson(data);
    } on DioException catch (e) {
      throw ReferralException(_messageFromDio(e));
    }
  }

  Future<MyReferralCode> setMyCode(String code) async {
    try {
      final response = await ApiClient().dio.post(
        '${ApiClient.apiPrefix}/user/referral/my-code',
        data: {'code': code.trim().toUpperCase()},
      );
      final data = _unwrap(response.data);
      if (data == null) {
        throw const ReferralException('Failed to save promote code');
      }
      return MyReferralCode.fromJson(data);
    } on DioException catch (e) {
      throw ReferralException(_messageFromDio(e));
    }
  }

  Future<void> deleteMyCode() async {
    try {
      await ApiClient().dio.delete(
        '${ApiClient.apiPrefix}/user/referral/my-code',
      );
    } on DioException catch (e) {
      throw ReferralException(_messageFromDio(e));
    }
  }

  Future<CodeAvailabilityResult> checkAvailability(String code) async {
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/referral/check-code',
        queryParameters: {'code': code.trim().toUpperCase()},
      );
      final data = _unwrap(response.data);
      if (data == null) {
        return const CodeAvailabilityResult(
          code: '',
          isAvailable: false,
          reason: 'Unable to verify code availability',
        );
      }
      return CodeAvailabilityResult.fromJson(data);
    } on DioException catch (e) {
      return CodeAvailabilityResult(
        code: code,
        isAvailable: false,
        reason: _messageFromDio(e),
      );
    }
  }

  Future<ClaimReferralResult> claimReferral(String code) async {
    try {
      final response = await ApiClient().dio.post(
        '${ApiClient.apiPrefix}/user/referral/claim',
        data: {'code': code.trim().toUpperCase()},
      );
      final data = _unwrap(response.data);
      if (data == null) {
        throw const ReferralException('Failed to apply referral code');
      }
      return ClaimReferralResult.fromJson(data);
    } on DioException catch (e) {
      throw ReferralException(_messageFromDio(e));
    }
  }

  Future<List<ReferredFriend>> getMyReferrals({int page = 1, int size = 20}) async {
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/referral/my-referrals',
        queryParameters: {'page': page, 'size': size},
      );
      final body = response.data;
      List? items;
      if (body is Map) {
        if (body['data'] is List) {
          items = body['data'] as List;
        } else if (body['data'] is Map && (body['data'] as Map)['items'] is List) {
          items = (body['data'] as Map)['items'] as List;
        }
      }
      if (items == null) return const [];
      return items
          .whereType<Map>()
          .map((e) => ReferredFriend.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (data is String && data.isNotEmpty) return data;
    return e.message ?? 'An unexpected error occurred';
  }

  Map<String, dynamic>? _unwrap(dynamic body) {
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);
    if (map['data'] is Map) {
      return Map<String, dynamic>.from(map['data'] as Map);
    }
    return map;
  }
}
