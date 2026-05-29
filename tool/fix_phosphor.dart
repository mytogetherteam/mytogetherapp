import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    String newContent = content;

    // 1. Imports
    newContent = newContent.replaceAll(
      "import 'package:phosphor_flutter/phosphor_flutter.dart';",
      "import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';"
    );

    // 2. PhosphorIcons.name(PhosphorIconsStyle.style)
    final styleRegex = RegExp(r'PhosphorIcons\.([a-zA-Z0-9_]+)\(PhosphorIconsStyle\.(fill|bold|thin|light|duotone|regular)\)');
    newContent = newContent.replaceAllMapped(styleRegex, (match) {
      final name = match.group(1)!;
      final style = match.group(2)!;
      final styleCapitalized = style[0].toUpperCase() + style.substring(1);
      return 'PhosphorIcons$styleCapitalized.$name';
    });

    // 3. PhosphorIcons.name()
    final emptyRegex = RegExp(r'PhosphorIcons\.([a-zA-Z0-9_]+)\(\)');
    newContent = newContent.replaceAllMapped(emptyRegex, (match) {
      final name = match.group(1)!;
      return 'PhosphorIcons.$name';
    });

    if (content != newContent) {
      print('Updated ${file.path}');
      file.writeAsStringSync(newContent);
    }
  }
}
