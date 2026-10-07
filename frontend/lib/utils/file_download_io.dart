import 'dart:io';

Future<void> downloadTextFile({
  required String filename,
  required String content,
  required String mimeType,
}) async {
  try {
    Directory? dir;
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        dir = downloadDir;
      }
    }
    dir ??= Directory.systemTemp;
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content, flush: true);
  } catch (_) {
    final tempFile = File('${Directory.systemTemp.path}/$filename');
    await tempFile.writeAsString(content, flush: true);
  }
}
