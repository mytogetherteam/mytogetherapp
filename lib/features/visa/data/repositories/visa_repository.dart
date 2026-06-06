import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/visa_dto.dart';

class VisaSectionData {
  final List<VisaCategoryDto> categories;
  final Map<int, List<VisaDto>> visasByCategory;

  const VisaSectionData({
    required this.categories,
    required this.visasByCategory,
  });
}

class VisaRepository {
  static final VisaRepository instance = VisaRepository._();
  VisaRepository._();

  final Dio _dio = ApiClient().dio;

  Future<VisaSectionData> loadSection(String section, {int size = 100}) async {
    final categoriesResponse = await _dio.get(
      '${ApiClient.apiPrefix}/user/visa/categories/list',
      queryParameters: {'section': section},
    );
    final categories = ApiResponseUtils.parseDataList(
      categoriesResponse.data,
      VisaCategoryDto.fromJson,
    )..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final visasResponse = await _dio.get(
      '${ApiClient.apiPrefix}/user/visa',
      queryParameters: {'section': section, 'page': 1, 'size': size},
    );
    final visas = ApiResponseUtils.parseDataList(
      visasResponse.data,
      VisaDto.fromJson,
    )..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final grouped = <int, List<VisaDto>>{};
    for (final visa in visas) {
      grouped.putIfAbsent(visa.visaCategoryId, () => []).add(visa);
    }

    return VisaSectionData(categories: categories, visasByCategory: grouped);
  }

  Future<VisaDto?> fetchOne(int id) async {
    final response = await _dio.get('${ApiClient.apiPrefix}/user/visa/$id');
    return ApiResponseUtils.parseDataObject(response.data, VisaDto.fromJson);
  }
}
