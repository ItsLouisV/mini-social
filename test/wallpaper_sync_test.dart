import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Wallpaper History & Sorting Logic Tests', () {
    test('Should sort active wallpaper to the 1st position in list', () {
      final rawHistory = ['path_A', 'path_B', 'path_C', 'path_D'];
      final activeWallpaper = 'path_C';

      final historyList = List<String>.from(rawHistory);
      if (activeWallpaper.isNotEmpty && historyList.contains(activeWallpaper)) {
        historyList.remove(activeWallpaper);
        historyList.insert(0, activeWallpaper);
      }

      expect(historyList.first, equals('path_C'));
      expect(historyList.length, equals(4));
      expect(historyList, equals(['path_C', 'path_A', 'path_B', 'path_D']));
    });

    test('Should not modify history if active wallpaper is not in history', () {
      final rawHistory = ['path_A', 'path_B', 'path_D'];
      final activeWallpaper = 'path_C';

      final historyList = List<String>.from(rawHistory);
      if (activeWallpaper.isNotEmpty && historyList.contains(activeWallpaper)) {
        historyList.remove(activeWallpaper);
        historyList.insert(0, activeWallpaper);
      }

      expect(historyList, equals(['path_A', 'path_B', 'path_D']));
    });

    test('Should filter out temporary web blob: URLs from history list', () {
      final rawList = [
        'blob:http://localhost:8080/abc-123',
        'https://supabase.co/storage/v1/object/public/wallpapers/user1/image.jpg',
        'sys:aurora',
        'blob:http://localhost:8080/def-456',
      ];

      final cleanList = rawList.where((path) => !path.startsWith('blob:')).toList();

      expect(cleanList.length, equals(2));
      expect(cleanList, equals([
        'https://supabase.co/storage/v1/object/public/wallpapers/user1/image.jpg',
        'sys:aurora'
      ]));
    });

    test('Should check if system wallpaper ID helper functions match patterns', () {
      bool isSystemWallpaper(String path) => path.startsWith('sys:');

      expect(isSystemWallpaper('sys:aurora'), isTrue);
      expect(isSystemWallpaper('sys:sunset'), isTrue);
      expect(isSystemWallpaper('https://supabase.co/image.png'), isFalse);
      expect(isSystemWallpaper('/var/mobile/containers/Data/1.png'), isFalse);
    });
  });
}
