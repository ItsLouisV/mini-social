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

  factory MusicTrackModel.fromJson(Map<String, dynamic> json) {
    return MusicTrackModel(
      id: (json['id'] ?? json['trackId'] ?? '').toString(),
      title: json['title'] ?? json['trackName'] ?? '',
      artist: json['artist'] ?? json['artistName'] ?? '',
      previewUrl: json['preview_url'] ?? json['previewUrl'] ?? '',
      artworkUrl: json['artwork_url'] ?? json['artworkUrl100'] ?? json['artworkUrl'] ?? '',
      album: json['album'] ?? json['collectionName'],
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

  /// Scale artwork URL from iTunes (e.g. 100x100 -> 300x300)
  String getHighResArtworkUrl([int size = 300]) {
    if (artworkUrl.isEmpty) return '';
    return artworkUrl.replaceAll('100x100bb', '${size}x${size}bb');
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
