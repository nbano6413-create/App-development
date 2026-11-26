import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  static Future<File> saveFileToDownloads(File tempFile, String preferredFileName) async {
    Directory? downloadDir;

    if (Platform.isAndroid) {
      // Standard Android Downloads directory
      downloadDir = Directory('/storage/emulated/0/Download');
      try {
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
      } catch (_) {
        downloadDir = await getExternalStorageDirectory();
      }
    } else {
      downloadDir = await getApplicationDocumentsDirectory();
    }

    if (downloadDir == null || !await downloadDir.exists()) {
      downloadDir = await getApplicationDocumentsDirectory();
    }

    String fileName = preferredFileName;
    File targetFile = File('${downloadDir.path}/$fileName');

    // Avoid overwriting existing files by appending a timestamp if needed
    int counter = 1;
    while (await targetFile.exists()) {
      final nameWithoutExt = preferredFileName.contains('.')
          ? preferredFileName.substring(0, preferredFileName.lastIndexOf('.'))
          : preferredFileName;
      final ext = preferredFileName.contains('.')
          ? preferredFileName.substring(preferredFileName.lastIndexOf('.'))
          : '';
      fileName = '${nameWithoutExt}_$counter$ext';
      targetFile = File('${downloadDir.path}/$fileName');
      counter++;
    }

    return await tempFile.copy(targetFile.path);
  }
}
