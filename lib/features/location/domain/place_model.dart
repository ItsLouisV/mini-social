class PlaceModel {
  final String providerPlaceId;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String provider;

  const PlaceModel({
    required this.providerPlaceId,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.provider = 'openstreetmap',
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) => PlaceModel(
        providerPlaceId: (json['provider_place_id'] ?? json['place_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        address: json['address']?.toString(),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        provider: (json['provider'] ?? 'openstreetmap').toString(),
      );

  static PlaceModel? fromPostJson(Map<String, dynamic>? json) {
    if (json == null ||
        json['location_name'] == null ||
        json['location_latitude'] == null ||
        json['location_longitude'] == null) {
      return null;
    }
    return PlaceModel(
      providerPlaceId: json['location_place_id']?.toString() ?? '',
      name: json['location_name'].toString(),
      address: json['location_address']?.toString(),
      latitude: (json['location_latitude'] as num).toDouble(),
      longitude: (json['location_longitude'] as num).toDouble(),
      provider: json['location_provider']?.toString() ?? 'openstreetmap',
    );
  }

  Map<String, dynamic> toJson() => {
        'provider_place_id': providerPlaceId,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'provider': provider,
      };
}
