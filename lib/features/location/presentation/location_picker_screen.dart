import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../data/device_location_service.dart';
import '../data/photo_location_service.dart';
import '../domain/place_model.dart';
import '../providers/location_provider.dart';

class LocationPickerScreen extends ConsumerStatefulWidget {
  final List<XFile> images;
  final List<PhotoCoordinates> photoCoordinates;
  const LocationPickerScreen({
    super.key,
    this.images = const [],
    this.photoCoordinates = const [],
  });

  @override
  ConsumerState<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  Position? _position;
  List<PlaceModel> _nearby = const [];
  List<PlaceModel> _photoPlaces = const [];
  List<PlaceModel> _searchResults = const [];
  bool _loadingNearby = true;
  bool _loadingPhoto = false;
  bool _searching = false;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    _loadNearby();
    _loadPhotoSuggestion();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNearby() async {
    setState(() {
      _loadingNearby = true;
      _locationMessage = null;
    });
    try {
      final position = await ref.read(deviceLocationServiceProvider).getCurrentPosition();
      final places = await ref.read(placesRepositoryProvider).nearby(
            position.latitude,
            position.longitude,
          );
      if (!mounted) return;
      setState(() {
        _position = position;
        _nearby = places;
      });
    } on LocationServicesDisabledException {
      _setLocationMessage('Dịch vụ vị trí đang tắt. Bạn vẫn có thể tìm kiếm địa điểm.');
    } on LocationPermissionException catch (error) {
      _setLocationMessage(error.permanentlyDenied
          ? 'Quyền vị trí đã bị tắt. Hãy cấp quyền trong Cài đặt hoặc tìm kiếm thủ công.'
          : 'Chưa được cấp quyền vị trí. Bạn vẫn có thể tìm kiếm địa điểm.');
    } catch (_) {
      _setLocationMessage('Không thể tải địa điểm gần bạn. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _loadingNearby = false);
    }
  }

  void _setLocationMessage(String value) {
    if (mounted) setState(() => _locationMessage = value);
  }

  Future<void> _loadPhotoSuggestion() async {
    final images = widget.images.where((file) {
      final ext = file.name.split('.').last.toLowerCase();
      return !['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext);
    }).toList();
    if (images.isEmpty && widget.photoCoordinates.isEmpty) return;
    setState(() => _loadingPhoto = true);
    try {
      for (final coordinates in widget.photoCoordinates) {
        final places = await ref.read(placesRepositoryProvider).reverse(
              coordinates.latitude,
              coordinates.longitude,
            );
        if (places.isNotEmpty) {
          if (mounted) setState(() => _photoPlaces = [places.first]);
          return;
        }
      }
      for (final image in images) {
        final coordinates = await ref.read(photoLocationServiceProvider).readCoordinates(image);
        if (coordinates == null) continue;
        final places = await ref.read(placesRepositoryProvider).reverse(
              coordinates.latitude,
              coordinates.longitude,
            );
        if (places.isNotEmpty) {
          if (mounted) setState(() => _photoPlaces = [places.first]);
          break;
        }
      }
    } catch (_) {
      // EXIF location is optional and must never block posting.
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _searchResults = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final results = await ref.read(placesRepositoryProvider).search(
            query,
            latitude: _position?.latitude,
            longitude: _position?.longitude,
          );
      if (mounted && _searchController.text.trim() == query) {
        setState(() => _searchResults = results);
      }
    } catch (_) {
      if (mounted) setState(() => _searchResults = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final isSearching = query.length >= 2;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm vị trí'),
        actions: [
          if (_locationMessage?.contains('Cài đặt') == true)
            TextButton(onPressed: Geolocator.openAppSettings, child: const Text('Cài đặt')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (value) {
                setState(() {});
                _onSearchChanged(value);
              },
              decoration: InputDecoration(
                hintText: 'Tìm kiếm địa điểm...',
                prefixIcon: const Icon(CupertinoIcons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                        icon: const Icon(CupertinoIcons.clear_circled_solid),
                      ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: isSearching ? _buildSearchResults() : _buildSuggestions(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) return const Center(child: CircularProgressIndicator());
    if (_searchResults.isEmpty) {
      return const Center(child: Text('Không tìm thấy địa điểm phù hợp'));
    }
    return ListView(children: _searchResults.map(_placeTile).toList());
  }

  Widget _buildSuggestions() {
    return RefreshIndicator(
      onRefresh: _loadNearby,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (_loadingPhoto)
            const LinearProgressIndicator(minHeight: 2)
          else if (_photoPlaces.isNotEmpty) ...[
            _sectionTitle('TỪ ẢNH', CupertinoIcons.photo_fill, Colors.purpleAccent),
            ..._photoPlaces.map(_placeTile),
            const Divider(),
          ],
          _sectionTitle('GẦN BẠN', CupertinoIcons.location_solid, Colors.redAccent),
          if (_loadingNearby)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_locationMessage != null)
            ListTile(
              leading: const Icon(CupertinoIcons.location_slash),
              title: Text(_locationMessage!),
              trailing: IconButton(icon: const Icon(CupertinoIcons.refresh), onPressed: _loadNearby),
            )
          else if (_nearby.isEmpty)
            const ListTile(title: Text('Không tìm thấy địa điểm gần đây'))
          else
            ..._nearby.map(_placeTile),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        ]),
      );

  Widget _placeTile(PlaceModel place) => ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0x1A6750A4),
          child: Icon(CupertinoIcons.location_fill, color: AppColors.primary, size: 19),
        ),
        title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: place.address == null ? null : Text(place.address!, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => Navigator.pop(context, place),
      );
}
