import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  test('Debug Phosphor Icons Method', () {
    // Check if House is a function returning IconData
    var iconRegular = PhosphorIcons.house;
    var iconFill = PhosphorIconsFill.house;
    
    expect(iconRegular, isA<IconData>());
    expect(iconFill, isA<IconData>());
  });
}
