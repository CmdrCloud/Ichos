class Song {
  final String id;
  final String fileId;
  final String filePath;
  final String? cdnUrl;
  final String title;
  final String artistId;
  final String? artistName; // For convenience if joined in API
  final String? albumId;
  final String? albumTitle; // For convenience if joined in API
  final String? coverUrl;
  final int? releaseYear;
  final double durationS;
  final bool explicit;
  final int playCount;

  Song({
    required this.id,
    required this.fileId,
    required this.filePath,
    this.cdnUrl,
    required this.title,
    required this.artistId,
    this.artistName,
    this.albumId,
    this.albumTitle,
    this.coverUrl,
    this.releaseYear,
    required this.durationS,
    this.explicit = false,
    this.playCount = 0,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>?;

    return Song(
      id: json['id'] ?? '',
      fileId: json['file_id'] ?? json['id'] ?? '',
      filePath: json['file_path'] ?? json['ruta'] ?? '',
      cdnUrl: json['cdn_url'],
      title: json['title'] ?? metadata?['titulo'] ?? 'Unknown',
      artistId: json['artist_id'] ?? '',
      artistName: json['artist_name'] ?? metadata?['artista'],
      albumId: json['album_id'],
      albumTitle: json['album_title'] ?? metadata?['album'],
      coverUrl: json['cover_url'],
      releaseYear: json['release_year'] ?? int.tryParse(metadata?['anio']?.toString() ?? ''),
      durationS: (json['duration_s'] ?? json['duracion'] ?? 0).toDouble(),
      explicit: json['explicit'] ?? false,
      playCount: json['play_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_id': fileId,
      'file_path': filePath,
      'cdn_url': cdnUrl,
      'title': title,
      'artist_id': artistId,
      'album_id': albumId,
      'cover_url': coverUrl,
      'release_year': releaseYear,
      'duration_s': durationS,
      'explicit': explicit,
      'play_count': playCount,
    };
  }
}
