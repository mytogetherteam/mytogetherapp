class UserReferralStatus {
  final MyReferralCode? myCode;
  final ClaimedReferralInfo? claimedReferral;
  final bool canClaim;
  final bool isProgramActive;

  const UserReferralStatus({
    this.myCode,
    this.claimedReferral,
    required this.canClaim,
    required this.isProgramActive,
  });

  factory UserReferralStatus.fromJson(Map<String, dynamic> json) =>
      UserReferralStatus(
        myCode: json['myCode'] != null
            ? MyReferralCode.fromJson(Map<String, dynamic>.from(json['myCode'] as Map))
            : null,
        claimedReferral: json['claimedReferral'] != null
            ? ClaimedReferralInfo.fromJson(
                Map<String, dynamic>.from(json['claimedReferral'] as Map))
            : null,
        canClaim: json['canClaim'] == true,
        isProgramActive: json['isProgramActive'] == true,
      );
}

class MyReferralCode {
  final int id;
  final String code;
  final int usedCount;
  final bool isActive;
  final DateTime? createdAt;

  const MyReferralCode({
    required this.id,
    required this.code,
    required this.usedCount,
    required this.isActive,
    this.createdAt,
  });

  factory MyReferralCode.fromJson(Map<String, dynamic> json) => MyReferralCode(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: json['code']?.toString() ?? '',
        usedCount: (json['usedCount'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] == true,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
      );
}

class ClaimedReferralInfo {
  final String code;
  final String referrerName;
  final DateTime? claimedAt;

  const ClaimedReferralInfo({
    required this.code,
    required this.referrerName,
    this.claimedAt,
  });

  factory ClaimedReferralInfo.fromJson(Map<String, dynamic> json) =>
      ClaimedReferralInfo(
        code: json['code']?.toString() ?? '',
        referrerName: json['referrerName']?.toString() ?? 'Friend',
        claimedAt: json['claimedAt'] != null
            ? DateTime.tryParse(json['claimedAt'].toString())
            : null,
      );
}

class RewardCouponSummary {
  final int id;
  final String code;
  final String name;
  final String? description;
  final double discountValue;
  final String? shopName;

  const RewardCouponSummary({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.discountValue = 0,
    this.shopName,
  });

  factory RewardCouponSummary.fromJson(Map<String, dynamic> json) =>
      RewardCouponSummary(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Special Coupon',
        description: json['description']?.toString(),
        discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
        shopName: json['shopName']?.toString(),
      );
}

class ClaimReferralResult {
  final String claimedCode;
  final String referrerName;
  final bool rewardGranted;
  final RewardCouponSummary? coupon;
  final String? customMessage;

  const ClaimReferralResult({
    required this.claimedCode,
    required this.referrerName,
    required this.rewardGranted,
    this.coupon,
    this.customMessage,
  });

  factory ClaimReferralResult.fromJson(Map<String, dynamic> json) =>
      ClaimReferralResult(
        claimedCode: json['claimedCode']?.toString() ?? '',
        referrerName: json['referrerName']?.toString() ?? 'Friend',
        rewardGranted: json['rewardGranted'] == true,
        coupon: json['coupon'] != null
            ? RewardCouponSummary.fromJson(
                Map<String, dynamic>.from(json['coupon'] as Map))
            : null,
        customMessage: json['customMessage']?.toString(),
      );
}

class CodeAvailabilityResult {
  final String code;
  final bool isAvailable;
  final String? reason;

  const CodeAvailabilityResult({
    required this.code,
    required this.isAvailable,
    this.reason,
  });

  factory CodeAvailabilityResult.fromJson(Map<String, dynamic> json) =>
      CodeAvailabilityResult(
        code: json['code']?.toString() ?? '',
        isAvailable: json['isAvailable'] == true,
        reason: json['reason']?.toString(),
      );
}

class ReferredFriend {
  final int id;
  final String name;
  final String? profileUrl;
  final DateTime? joinedAt;

  const ReferredFriend({
    required this.id,
    required this.name,
    this.profileUrl,
    this.joinedAt,
  });

  factory ReferredFriend.fromJson(Map<String, dynamic> json) {
    final user = json['referredUser'] as Map? ?? {};
    return ReferredFriend(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: user['name']?.toString() ?? user['username']?.toString() ?? 'Friend',
      profileUrl: user['profileUrl']?.toString(),
      joinedAt: json['claimedAt'] != null
          ? DateTime.tryParse(json['claimedAt'].toString())
          : null,
    );
  }
}
