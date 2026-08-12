import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

/// Downloads remote media and opens the platform save/share sheet.
/// This works on Android, iOS, desktop and web without requiring broad
/// storage permissions; the user chooses the final destination.
class MediaSaveService {
  MediaSaveService._();

  static Future<void> saveUrls(
    List<String> urls, {
    required String fallbackBaseName,
  }) async {
    if (urls.isEmpty) throw StateError('Không có nội dung để lưu');

    final files = <XFile>[];
    for (var index = 0; index < urls.length; index++) {
      final uri = Uri.parse(urls[index]);
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Không thể tải nội dung (${response.statusCode})');
      }

      final contentType = response.headers['content-type']?.split(';').first;
      final sourceName =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final fileName = sourceName.contains('.')
          ? sourceName
          : '${fallbackBaseName}_${index + 1}.${_extensionFor(contentType)}';
      files.add(XFile.fromData(
        Uint8List.fromList(response.bodyBytes),
        name: fileName,
        mimeType: contentType,
      ));
    }

    await Share.shareXFiles(files);
  }

  static String _extensionFor(String? contentType) {
    switch (contentType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'video/mp4':
        return 'mp4';
      case 'application/pdf':
        return 'pdf';
      default:
        return contentType?.startsWith('video/') == true ? 'mp4' : 'jpg';
    }
  }
}
