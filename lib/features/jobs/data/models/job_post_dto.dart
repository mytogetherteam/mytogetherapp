import 'package:intl/intl.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/network/media_url.dart';

enum JobType { fullTime, partTime }

enum JobPostStatus { active, inactive }

JobType jobTypeFromApi(String? value) {
  switch (value?.toUpperCase()) {
    case 'PART_TIME':
      return JobType.partTime;
    case 'FULL_TIME':
    default:
      return JobType.fullTime;
  }
}

String jobTypeToApi(JobType type) =>
    type == JobType.partTime ? 'PART_TIME' : 'FULL_TIME';

JobPostStatus jobPostStatusFromApi(String? value) =>
    value?.toUpperCase() == 'INACTIVE'
        ? JobPostStatus.inactive
        : JobPostStatus.active;

class JobShopDto {
  final int id;
  final String nameEn;
  final String? nameMm;
  final String? nameTh;
  final String slug;
  final String? logoUrl;

  const JobShopDto({
    required this.id,
    required this.nameEn,
    this.nameMm,
    this.nameTh,
    required this.slug,
    this.logoUrl,
  });

  String get displayName => LocaleController.instance.localizedOr(
        nameEn,
        en: nameEn,
        mm: nameMm,
        th: nameTh,
      );

  String get logo => resolveMediaUrl(logoUrl);

  factory JobShopDto.fromJson(Map<String, dynamic> json) {
    return JobShopDto(
      id: (json['id'] as num).toInt(),
      nameEn: json['nameEn']?.toString() ?? '',
      nameMm: json['nameMm']?.toString(),
      nameTh: json['nameTh']?.toString(),
      slug: json['slug']?.toString() ?? '',
      logoUrl: json['logoUrl']?.toString(),
    );
  }
}

class JobPostDto {
  final int id;
  final int shopId;
  final String title;
  final String description;
  final JobType jobType;
  final bool salaryNegotiable;
  final int? salaryMin;
  final int? salaryMax;
  final String? applyLink;
  final String? contactPhone;
  final JobPostStatus status;
  final DateTime? closingDate;
  final DateTime? createdAt;
  final JobShopDto? shop;

  const JobPostDto({
    required this.id,
    required this.shopId,
    required this.title,
    required this.description,
    required this.jobType,
    required this.salaryNegotiable,
    this.salaryMin,
    this.salaryMax,
    this.applyLink,
    this.contactPhone,
    required this.status,
    this.closingDate,
    this.createdAt,
    this.shop,
  });

  bool get isActive => status == JobPostStatus.active;

  String salaryLabel(String negotiableLabel) {
    if (salaryNegotiable &&
        salaryMin == null &&
        salaryMax == null) {
      return negotiableLabel;
    }
    final fmt = NumberFormat('#,##0', 'en_US');
    if (salaryMin != null && salaryMax != null) {
      if (salaryMin == salaryMax) {
        return '${fmt.format(salaryMin)} THB';
      }
      return '${fmt.format(salaryMin)} – ${fmt.format(salaryMax)} THB';
    }
    if (salaryMin != null) {
      return '${fmt.format(salaryMin)}+ THB';
    }
    if (salaryMax != null) {
      return '≤ ${fmt.format(salaryMax)} THB';
    }
    return negotiableLabel;
  }

  factory JobPostDto.fromJson(Map<String, dynamic> json) {
    final shopRaw = json['shop'];
    return JobPostDto(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num).toInt(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      jobType: jobTypeFromApi(json['jobType']?.toString()),
      salaryNegotiable: json['salaryNegotiable'] == true,
      salaryMin: (json['salaryMin'] as num?)?.toInt(),
      salaryMax: (json['salaryMax'] as num?)?.toInt(),
      applyLink: json['applyLink']?.toString(),
      contactPhone: json['contactPhone']?.toString(),
      status: jobPostStatusFromApi(json['status']?.toString()),
      closingDate: _parseDate(json['closingDate']),
      createdAt: _parseDate(json['createdAt']),
      shop: shopRaw is Map<String, dynamic>
          ? JobShopDto.fromJson(shopRaw)
          : null,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
