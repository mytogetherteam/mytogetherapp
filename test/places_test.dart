import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytogetherapp/core/location/location_search_service.dart';

void main() {
  testWidgets('test places', (tester) async {
    final res = await LocationSearchService.instance.searchPlaces('Bangkok');
    debugPrint(res.toString());
  });
}
