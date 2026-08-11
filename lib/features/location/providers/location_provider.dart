import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../data/device_location_service.dart';
import '../data/photo_location_service.dart';
import '../data/places_repository.dart';

final deviceLocationServiceProvider = Provider((ref) => DeviceLocationService());
final photoLocationServiceProvider = Provider((ref) => PhotoLocationService());
final placesRepositoryProvider = Provider(
  (ref) => PlacesRepository(ref.watch(supabaseClientProvider)),
);
