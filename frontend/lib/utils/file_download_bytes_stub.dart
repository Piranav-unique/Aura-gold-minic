import 'package:flutter/foundation.dart';

Future<void> downloadBytesFile({
  required String filename,
  required List<int> bytes,
  required String mimeType,
}) async {
  debugPrint(
    'Download $filename (${bytes.length} bytes) — binary handler unavailable',
  );
}
