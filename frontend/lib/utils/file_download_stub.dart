import 'package:flutter/foundation.dart';

Future<void> downloadTextFile({
  required String filename,
  required String content,
  required String mimeType,
}) async {
  debugPrint(
    'Download $filename (${content.length} bytes) — platform handler unavailable',
  );
}
