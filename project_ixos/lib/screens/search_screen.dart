import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/mood_provider.dart';
import '../services/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isSearching = false;

  void _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    // Mocking search for now
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _searchResults = [
        Song(
          id: 's3',
          fileId: 's3',
          filePath: 'music/s3.mp3',
          title: 'Search Result 1',
          artistId: 'a2',
          artistName: 'Search Artist',
          albumTitle: 'Search Album',
          durationS: 200,
          cdnUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        ),
      ];
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final moodProvider = context.watch<MoodProvider>();

    return Scaffold(
      backgroundColor: moodProvider.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: moodProvider.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_isSearching)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final song = _searchResults[index];
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
                      onTap: () {
                        context.read<PlayerProvider>().playSong(song);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
