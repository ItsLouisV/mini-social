// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

Future<List<Map<String, dynamic>>> fetchItunesJsonp(String term) {
  final completer = Completer<List<Map<String, dynamic>>>();
  final callbackName = '__itunes_cb_${DateTime.now().millisecondsSinceEpoch}';

  js.context[callbackName] = (dynamic data) {
    try {
      final jsonString = js.context['JSON']['stringify'](data) as String;
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final results = (map['results'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      js.context[callbackName] = null;
      if (!completer.isCompleted) completer.complete(results);
    } catch (e) {
      if (!completer.isCompleted) completer.complete([]);
    }
  };

  final url =
      'https://itunes.apple.com/search?term=${Uri.encodeComponent(term)}&media=music&entity=song&limit=25&callback=$callbackName';
  final script = html.ScriptElement()..src = url;

  script.onError.listen((_) {
    js.context[callbackName] = null;
    script.remove();
    if (!completer.isCompleted) completer.complete([]);
  });

  html.document.body?.children.add(script);

  return completer.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      js.context[callbackName] = null;
      script.remove();
      return [];
    },
  );
}
