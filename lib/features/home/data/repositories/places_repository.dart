import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/place_dto.dart';

class PlacesFeedPage {
  final List<PlaceDto> items;
  final int total;
  final int page;

  const PlacesFeedPage({
    required this.items,
    required this.total,
    required this.page,
  });
}

class PlacesRepository {
  static final PlacesRepository instance = PlacesRepository._();
  PlacesRepository._();

  final Dio _dio = ApiClient().dio;

  Future<PlacesFeedPage> fetchPlaces({
    int page = 1,
    int size = 20,
    String? search,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/places',
      queryParameters: {
        'page': page,
        'size': size,
        if (search != null && search.isNotEmpty) 'search': search,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'radiusKm': ?radiusKm,
      },
    );
    final items = ApiResponseUtils.parseDataList(
      response.data,
      PlaceDto.fromJson,
    );
    return PlacesFeedPage(
      items: items,
      total: ApiResponseUtils.parseTotalElements(response.data),
      page: page,
    );
  }

  Future<PlaceDto?> fetchPlace(
    int id, {
    double? latitude,
    double? longitude,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/places/$id',
      queryParameters: {
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
    );
    return ApiResponseUtils.parseDataObject(
      response.data,
      PlaceDto.fromJson,
    );
  }
}
