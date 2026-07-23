import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class ImageCompressor {
  /// Nén XFile hình ảnh và trả về danh sách byte Uint8List đã nén.
  /// Mặc định chất lượng 80%, kích thước tối đa 1920px.
  static Future<Uint8List> compressXFile(
    XFile file, {
    int quality = 80,
    int minWidth = 1920,
    int minHeight = 1080,
  }) async {
    try {
      final bytes = await file.readAsBytes();

      // Nếu dung lượng file dưới 300KB thì giữ nguyên
      if (bytes.lengthInBytes < 300 * 1024) {
        return bytes;
      }

      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      return result;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      // Trả về file gốc nếu gặp lỗi nén
      return await file.readAsBytes();
    }
  }

  /// Nén dữ liệu byte Uint8List trực tiếp.
  static Future<Uint8List> compressBytes(
    Uint8List bytes, {
    int quality = 80,
    int minWidth = 1920,
    int minHeight = 1080,
  }) async {
    try {
      if (bytes.lengthInBytes < 300 * 1024) {
        return bytes;
      }

      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      return result;
    } catch (e) {
      debugPrint('Error compressing bytes: $e');
      return bytes;
    }
  }
}
