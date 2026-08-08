import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/local_database.dart';

// Re-export LocalDatabase so every file that imports isar_service.dart
// automatically gets the correct platform implementation.
export '../database/local_database.dart';

/// Riverpod provider for [LocalDatabase].
/// Must be overridden in main() with the initialized instance.
final isarServiceProvider = Provider<LocalDatabase>((ref) {
  throw UnimplementedError('isarServiceProvider must be overridden in main()');
});

// Backwards-compatible alias — existing code references IsarService by name.
// The typedef keeps all call-sites working without renaming anything.
// ignore: non_constant_identifier_names
typedef IsarService = LocalDatabase;
