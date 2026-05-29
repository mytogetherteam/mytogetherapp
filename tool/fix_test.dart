import 'dart:io';

void main() {
  final file = File('test/icon_type_test.dart');
  if (file.existsSync()) {
    String content = file.readAsStringSync();
    newContent = content.replaceAll(
      "import 'package:phosphor_flutter/phosphor_flutter.dart';",
      "import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';"
    );
    final styleRegex = RegExp(r'PhosphorIcons\.([a-zA-Z0-9_]+)\(PhosphorIconsStyle\.(fill|bold|thin|light|duotone|regular)\)');
    newContent = newContent.replaceAllMapped(styleRegex, (match) {
      final name = match.group(1)!;
      final style = match.group(2)!;
      final styleCapitalized = style[0].toUpperCase() + style.substring(1);
      return 'PhosphorIcons$styleCapitalized.$name';
    });

    final emptyRegex = RegExp(r'PhosphorIcons\.([a-zA-Z0-9_]+)\(\)');
    newContent = newContent.replaceAllMapped(emptyRegex, (match) {
      final name = match.group(1)!;
      return 'PhosphorIcons.$name';
    });

    file.writeAsStringSync(newContent);
    print("Fixed test file");
  }
}
