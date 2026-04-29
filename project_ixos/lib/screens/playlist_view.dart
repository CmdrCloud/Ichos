import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mood.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/api_service.dart';

class PlaylistView extends StatefulWidget {
  final Mood mood;

  const PlaylistView({super.key, required this.mood});

  @override
  State<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  final ApiService _apiService = ApiService();
  List<Song> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    // For now, let's mock some songs if the API is empty
    final songs = await _apiService.getSongsByMood(widget.mood.id);
    if (songs.isEmpty) {
      _songs = [
        Song(
          id: '1',
          fileId: 's1',
          filePath: 'music/s1.mp3',
          title: 'Mood Song 1',
          artistId: 'a1',
          artistName: 'Ixos Artist',
          albumTitle: 'Mood Album',
          durationS: 210,
          cdnUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        ),
        Song(
          id: '2',
          fileId: 's2',
          filePath: 'music/s2.mp3',
          title: 'Mood Song 2',
          artistId: 'a1',
          artistName: 'Ixos Artist',
          albumTitle: 'Mood Album',
          durationS: 180,
          cdnUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        ),
      ];
    } else {
      _songs = songs;
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.mood.displayName),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.mood.gradient.first,
                      const Color(0xFF09090B),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _parseIconName(widget.mood.iconName),
                    size: 80,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_songs.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No songs found for this mood.')),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = _songs[index];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white54),
                    ),
                    title: Text(song.title, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(song.artistName ?? 'Unknown Artist',
                        style: TextStyle(color: Colors.white.withOpacity(0.6))),
                    trailing: const Icon(Icons.more_vert, color: Colors.white54),
                    onTap: () {
                      context.read<PlayerProvider>().playSong(song);
                    },
                  );
                },
                childCount: _songs.length,
              ),
            ),
        ],
      ),
    );
  }

  IconData _parseIconName(String iconName) {
    switch (iconName) {
      case 'sentiment_satisfied': return Icons.sentiment_satisfied;
      case 'cloud': return Icons.cloud;
      case 'headphones': return Icons.headphones;
      case 'bolt': return Icons.bolt;
      case 'spa': return Icons.spa;
      case 'local_bar': return Icons.local_bar;
      case 'nightlight': return Icons.nightlight;
      case 'favorite': return Icons.favorite;
      default: return Icons.music_note;
    }
  }
}
