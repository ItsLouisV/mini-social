class MusicTrackModel {
  final String id;
  final String title;
  final String artist;
  final String previewUrl;
  final String artworkUrl;
  final String? album;

  const MusicTrackModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.previewUrl,
    required this.artworkUrl,
    this.album,
  });

  /// Factory constructor supporting both iTunes API JSON and Deezer API JSON formats
  factory MusicTrackModel.fromJson(Map<String, dynamic> json) {
    // Deezer vs iTunes Artist parsing
    String artistName = '';
    if (json['artist'] is Map) {
      artistName = (json['artist'] as Map)['name']?.toString() ?? '';
    } else {
      artistName = (json['artist'] ?? json['artistName'] ?? '').toString();
    }

    // Deezer vs iTunes Album & Artwork parsing
    String? albumName;
    String artwork = '';
    if (json['album'] is Map) {
      final albumMap = json['album'] as Map;
      albumName = albumMap['title']?.toString();
      artwork = (albumMap['cover_medium'] ?? albumMap['cover'] ?? '').toString();
    } else {
      albumName = json['album']?.toString() ?? json['collectionName']?.toString();
      artwork = (json['artwork_url'] ?? json['artworkUrl100'] ?? json['artworkUrl'] ?? '').toString();
    }

    // Preview URL (iTunes uses previewUrl/preview_url; Deezer uses preview)
    final preview = (json['preview'] ?? json['preview_url'] ?? json['previewUrl'] ?? '').toString();

    return MusicTrackModel(
      id: (json['id'] ?? json['trackId'] ?? '').toString(),
      title: (json['title'] ?? json['trackName'] ?? '').toString(),
      artist: artistName,
      previewUrl: preview,
      artworkUrl: artwork,
      album: albumName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'preview_url': previewUrl,
      'artwork_url': artworkUrl,
      if (album != null) 'album': album,
    };
  }

  /// Scale artwork URL from iTunes / Deezer (e.g. 100x100 -> 300x300)
  String getHighResArtworkUrl([int size = 300]) {
    if (artworkUrl.isEmpty) return '';
    if (artworkUrl.contains('100x100bb')) {
      return artworkUrl.replaceAll('100x100bb', '${size}x${size}bb');
    }
    if (artworkUrl.contains('250x250-000000-80-0-0.jpg')) {
      return artworkUrl.replaceAll('250x250-000000-80-0-0.jpg', '${size}x$size-000000-80-0-0.jpg');
    }
    return artworkUrl;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicTrackModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
