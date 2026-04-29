class Playlist {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? coverUrl;
  final String visibility;
  final String? moodId;
  final int totalSongs;
  final double totalDurationS;

  Playlist({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.coverUrl,
    required this.visibility,
    this.moodId,
    this.totalSongs = 0,
    this.totalDurationS = 0,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      ownerId: json['owner_id'],
      name: json['name'],
      description: json['description'],
      coverUrl: json['cover_url'],
      visibility: json['visibility'],
      moodId: json['mood_id'],
      totalSongs: json['total_songs'] ?? 0,
      totalDurationS: (json['total_duration_s'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'cover_url': coverUrl,
      'visibility': visibility,
      'mood_id': moodId,
      'total_songs': totalSongs,
      'total_duration_s': totalDurationS,
    };
  }
}
