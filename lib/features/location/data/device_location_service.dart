import 'package:geolocator/geolocator.dart';

class LocationPermissionException implements Exception {
  final bool permanentlyDenied;
  const LocationPermissionException({this.permanentlyDenied = false});
}

class LocationServicesDisabledException implements Exception {}

class DeviceLocationService {
  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationServicesDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationPermissionException(
        permanentlyDenied: permission == LocationPermission.deniedForever,
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }
}
