import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/job_post_dto.dart';

class JobsFeedPage {
  final List<JobPostDto> items;
  final int total;
  final int page;
  final bool hasMore;

  const JobsFeedPage({
    required this.items,
    required this.total,
    required this.page,
    required this.hasMore,
  });
}

class JobPostRepository {
  static final JobPostRepository instance = JobPostRepository._();
  JobPostRepository._();

  final Dio _dio = ApiClient().dio;

  Future<JobsFeedPage> fetchJobs({
    int page = 1,
    int size = 20,
    String? search,
    JobType? jobType,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/job-posts',
      queryParameters: {
        'page': page,
        'size': size,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (jobType != null) 'jobType': jobTypeToApi(jobType),
      },
    );
    final items = ApiResponseUtils.parseDataList(
      response.data,
      JobPostDto.fromJson,
    );
    final currentPage = ApiResponseUtils.parseCurrentPage(
      response.data,
      requestedPage: page,
    );
    return JobsFeedPage(
      items: items,
      total: ApiResponseUtils.parseTotalElements(response.data),
      page: currentPage,
      hasMore: ApiResponseUtils.hasMoreFromMeta(
        body: response.data,
        currentPage: currentPage,
        itemCount: items.length,
        pageSize: size,
      ),
    );
  }

  Future<JobPostDto?> fetchJob(int id) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/job-posts/$id',
    );
    return ApiResponseUtils.parseDataObject(
      response.data,
      JobPostDto.fromJson,
    );
  }
}
