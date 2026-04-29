class Album {
  final String id;
  final String title;
  final String artistId;
  final String? coverUrl;
  final int? releaseYear;

  Album({
    required this.id,
    required this.title,
    required this.artistId,
    this.coverUrl,
    this.releaseYear,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'],
      title: json['title'],
      artistId: json['artist_id'],
      coverUrl: json['cover_url'],
      releaseYear: json['release_year'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist_id': artistId,
      'cover_url': coverUrl,
      'release_year': releaseYear,
    };
  }
}
