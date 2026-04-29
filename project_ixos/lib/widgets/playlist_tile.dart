import 'package:flutter/material.dart';
import '../models/mood.dart';
import '../screens/playlist_view.dart';

class PlaylistTile extends StatelessWidget {
  const PlaylistTile({
    super.key,
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  final Mood mood;
  final bool isSelected;
  final VoidCallback onTap;

  IconData _parseIconName(String iconName) {
    switch (iconName) {
      case 'sentiment_satisfied':
        return Icons.sentiment_satisfied;
      case 'cloud':
        return Icons.cloud;
      case 'headphones':
        return Icons.headphones;
      case 'bolt':
        return Icons.bolt;
      case 'spa':
        return Icons.spa;
      case 'local_bar':
        return Icons.local_bar;
      case 'nightlight':
        return Icons.nightlight;
      case 'favorite':
        return Icons.favorite;
      default:
        return Icons.music_note;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlaylistView(mood: mood),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: mood.gradient,
          ),
          border: isSelected
              ? Border.all(color: Colors.white.withOpacity(0.5), width: 2)
              : null,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: mood.gradient.last.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Icon(
                  _parseIconName(mood.iconName),
                  color: Colors.white.withOpacity(0.7),
                  size: 30,
                ),
              ),
              const Spacer(),
              Text(
                mood.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mixed for you',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
