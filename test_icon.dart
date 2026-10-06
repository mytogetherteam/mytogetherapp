import 'dart:io';
import 'dart:convert';

void main() async {
  var f = File('.dart_tool/package_config.json');
  var j = jsonDecode(await f.readAsString());
  var p = j['packages'].firstWhere((p) => p['name'] == 'phosphoricons_flutter');
  var rootUri = p['rootUri'];
  var libPath = Uri.parse(rootUri + '/lib/src/phosphor_icons.dart').toFilePath();
  var source = await File(libPath).readAsString();
  
  var lines = source.split('\n');
  for (var line in lines) {
    if (line.toLowerCase().contains('camera') || 
        line.toLowerCase().contains('plus') || 
        line.toLowerCase().contains('circle') ||
        line.toLowerCase().contains('film')) {
      print(line.trim());
    }
  }
}
