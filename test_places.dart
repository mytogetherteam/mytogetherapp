import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

void main() async {
  final dio = Dio();
  try {
    final response = await dio.get('https://maps.googleapis.com/maps/api/place/autocomplete/json', queryParameters: {
      'input': 'Bangkok',
      'key': 'AIzaSyDDp0l6jJqFbpSzfX7tBN2nsFkSY9x_5RU',
      'components': 'country:th',
      'language': 'en',
    });
    debugPrint(response.data.toString());
  } catch (e) {
    if (e is DioException) {
      debugPrint(e.response?.data?.toString());
    } else {
      debugPrint(e.toString());
    }
  }
}
