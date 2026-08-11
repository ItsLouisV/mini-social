import 'package:exif/exif.dart';
import 'package:image_picker/image_picker.dart';

class PhotoCoordinates {
  final double latitude;
  final double longitude;
  const PhotoCoordinates(this.latitude, this.longitude);
}

class PhotoLocationService {
  Future<PhotoCoordinates?> readCoordinates(XFile image) async {
    try {
      final tags = await readExifFromBytes(await image.readAsBytes());
      final lat = _coordinate(tags['GPS GPSLatitude']);
      final lng = _coordinate(tags['GPS GPSLongitude']);
      if (lat == null || lng == null) return null;

      final latRef = tags['GPS GPSLatitudeRef']?.printable.toUpperCase();
      final lngRef = tags['GPS GPSLongitudeRef']?.printable.toUpperCase();
      return PhotoCoordinates(
        latRef == 'S' ? -lat : lat,
        lngRef == 'W' ? -lng : lng,
      );
    } catch (_) {
      return null;
    }
  }

  double? _coordinate(IfdTag? tag) {
    if (tag?.values is! IfdRatios) return null;
    final values = (tag!.values as IfdRatios).ratios;
    if (values.length < 3) return null;
    double value(Ratio ratio) => ratio.numerator / ratio.denominator;
    return value(values[0]) + value(values[1]) / 60 + value(values[2]) / 3600;
  }
}
