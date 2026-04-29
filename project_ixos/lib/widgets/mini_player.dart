import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/mood_provider.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final moodProvider = context.watch<MoodProvider>();
    final song = playerProvider.currentSong;

    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PlayerScreen(),
            fullscreenDialog: true,
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: moodProvider.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: moodProvider.borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                  image: song.coverUrl != null
                      ? DecorationImage(
                          image: NetworkImage(song.coverUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: song.coverUrl == null
                    ? const Icon(Icons.music_note, color: Colors.white54)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artistName ?? 'Unknown Artist',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(
                  playerProvider.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: () => playerProvider.togglePlay(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
