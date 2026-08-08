import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

@JS('BarcodeDetector')
@staticInterop
class BarcodeDetector {
  external factory BarcodeDetector(JSObject options);
}

extension BarcodeDetectorExtension on BarcodeDetector {
  external JSPromise<JSArray<JSObject>> detect(JSObject image);
}

Future<String?> decodeQrFromWebImage(XFile imageFile) async {
  try {
    final bytes = await imageFile.readAsBytes();
    final blobBytes = <JSAny>[bytes.toJS].toJS;
    final blob = web.Blob(blobBytes);
    final url = web.URL.createObjectURL(blob);
    final img = web.HTMLImageElement();
    img.src = url;

    final completer = Completer<void>();
    img.addEventListener('load', (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS);
    img.addEventListener('error', (web.Event _) {
      if (!completer.isCompleted) completer.completeError('Failed to load image');
    }.toJS);

    await completer.future;

    final options = {'formats': ['qr_code']}.jsify() as JSObject;
    final detector = BarcodeDetector(options);
    final jsResults = await detector.detect(img).toDart;
    final results = jsResults.toDart;

    web.URL.revokeObjectURL(url);

    if (results.isNotEmpty) {
      final first = results.first;
      final rawValue = (first.getProperty('rawValue'.toJS) as JSString?)?.toDart;
      return rawValue;
    }
  } catch (e) {
    debugPrint('Web BarcodeDetector error: $e');
  }
  return null;
}
