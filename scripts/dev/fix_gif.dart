import 'dart:io';

void main() async {
  final file = File('assets/images/cooking.gif');
  if (!await file.exists()) {
    print('GIF not found');
    return;
  }
  final bytes = await file.readAsBytes();
  
  // Find NETSCAPE2.0 block
  bool hasLoop = false;
  for (int i = 0; i < bytes.length - 19; i++) {
    if (bytes[i] == 0x21 && bytes[i+1] == 0xFF && bytes[i+2] == 0x0B) {
      String sig = String.fromCharCodes(bytes.sublist(i+3, i+14));
      if (sig == "NETSCAPE2.0") {
        hasLoop = true;
        print('Found NETSCAPE2.0 extension at $i');
        // Check loop count
        int loopCount = bytes[i+16] | (bytes[i+17] << 8);
        print('Loop count: $loopCount');
        
        // Fix loop count to 0 (infinite)
        if (loopCount != 0) {
          final newBytes = bytes.toList();
          newBytes[i+16] = 0;
          newBytes[i+17] = 0;
          await file.writeAsBytes(newBytes);
          print('Patched loop count to 0');
        }
        break;
      }
    }
  }
  
  if (!hasLoop) {
    print('No loop extension found. We can inject it.');
    // GIF format: Header (6) + Logical Screen Descriptor (7) + Global Color Table (if any)
    // We should inject it right after the GCT or LSD.
    int offset = 13;
    bool hasGCT = (bytes[10] & 0x80) != 0;
    if (hasGCT) {
      int gctSize = 2 << (bytes[10] & 0x07);
      offset += gctSize * 3;
    }
    
    List<int> newBytes = [];
    newBytes.addAll(bytes.sublist(0, offset));
    
    // Inject NETSCAPE2.0 extension (loop infinitely)
    newBytes.addAll([
      0x21, 0xFF, 0x0B,
      0x4E, 0x45, 0x54, 0x53, 0x43, 0x41, 0x50, 0x45, 0x32, 0x2E, 0x30, // NETSCAPE2.0
      0x03, 0x01, 0x00, 0x00, 0x00
    ]);
    
    newBytes.addAll(bytes.sublist(offset));
    
    await file.writeAsBytes(newBytes);
    print('Injected loop extension.');
  }
}
