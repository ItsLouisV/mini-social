import 'itunes_jsonp_stub.dart'
    if (dart.library.html) 'itunes_jsonp_web.dart';

Future<List<Map<String, dynamic>>> getItunesJsonp(String term) =>
    fetchItunesJsonp(term);
