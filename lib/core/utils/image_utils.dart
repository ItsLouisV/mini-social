import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  ImageUtils._();

  /// Nén ảnh xuống ~800px width, quality 85%
  /// Nén ảnh xuống ~800px width, quality 85%
  static Future<XFile?> compressImage(XFile xFile) async {
    if (kIsWeb) return xFile; // No compression on Web for now

    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        xFile.path,
        targetPath,
        minWidth: 800,
        minHeight: 800,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      return result != null ? XFile(result.path) : xFile;
    } catch (e) {
      return xFile; // fallback: return original
    }
  }

  static String generateStoragePath(
      String bucket, String userId, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$bucket/$userId/$timestamp.$extension';
  }
}
