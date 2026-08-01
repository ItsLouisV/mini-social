import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

@JS('BarcodeDetector')
extension type BarcodeDetector._(JSObject _) implements JSObject {
  external BarcodeDetector(JSObject options);
  external JSPromise<JSArray<DetectedBarcode>> detect(JSObject image);
}

@JS()
extension type DetectedBarcode._(JSObject _) implements JSObject {
  external String get rawValue;
}

Future<String?> decodeQrFromWebImage(XFile imageFile) async {
  try {
    final bytes = await imageFile.readAsBytes();
    final blobBytes = <JSAny>[bytes.toJS].toJS;
    final blob = web.Blob(blobBytes);
    final url = web.URL.createObjectURL(blob);
    final img = web.HTMLImageElement();
    img.src = url;

    // Wait for image to load
    await web.EventStreamProviders.loadEvent.forTarget(img).first;

    final options = {'formats': ['qr_code']}.jsify() as JSObject;
    final detector = BarcodeDetector(options);
    final jsResults = await detector.detect(img).toDart;
    final results = jsResults.toDart;

    web.URL.revokeObjectURL(url);

    if (results.isNotEmpty) {
      return results.first.rawValue;
    }
  } catch (e) {
    debugPrint('Web BarcodeDetector error: $e');
  }
  return null;
}
