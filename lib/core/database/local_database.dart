// Conditional import entry point for LocalDatabase.
//
// - On native (mobile/desktop): dart.library.io  → local_database_native.dart (Isar)
// - On web:                     dart.library.html → local_database_web.dart (Hive/IndexedDB)
//
// Consumers must ONLY import this file — never import the platform-specific
// implementations directly, or dart2js will attempt to compile Isar's FFI code.
export 'local_database_stub.dart'
    if (dart.library.io) 'local_database_native.dart'
    if (dart.library.html) 'local_database_web.dart';
