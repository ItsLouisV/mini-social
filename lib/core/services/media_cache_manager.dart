import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MediaCacheManager {
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();

  /// Retrieve cached file on Mobile, or null on Web (where browser handles caching natively)
  static Future<File?> getCachedFile(String url) async {
    if (kIsWeb || url.isEmpty) return null;
    try {
      final fileInfo = await _cacheManager.getFileFromCache(url);
      if (fileInfo != null && fileInfo.file.existsSync()) {
        return fileInfo.file;
      }
    } catch (e) {
      debugPrint('⚠️ [MediaCacheManager] Error checking cache: $e');
    }
    return null;
  }

  /// Download and cache media file when user views/plays media on Mobile
  static Future<File?> downloadAndCacheMedia(String url) async {
    if (kIsWeb || url.isEmpty) return null;
    try {
      final file = await _cacheManager.getSingleFile(url);
      return file;
    } catch (e) {
      debugPrint('⚠️ [MediaCacheManager] Error caching media file: $e');
      return null;
    }
  }

  /// Clear media cache disk storage
  static Future<void> clearMediaCache() async {
    if (kIsWeb) return;
    try {
      await _cacheManager.emptyCache();
      debugPrint('🧹 [MediaCacheManager] Cleared media cache disk storage');
    } catch (e) {
      debugPrint('⚠️ [MediaCacheManager] Error clearing cache: $e');
    }
  }
}
