import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/mood.dart';
import '../models/playlist.dart';
import '../models/artist.dart';
import '../models/album.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'https://restful-ixos.onrender.com'}); // Placeholder based on github link pattern

  Future<List<Mood>> getMoods() async {
    // Mocking for now as the actual endpoints are not fully confirmed
    return [
      Mood(
        id: '1',
        name: 'feliz',
        displayName: 'Feliz',
        iconName: 'sentiment_satisfied',
        gradientStart: '#FACC15',
        gradientEnd: '#F97316',
        sortOrder: 1,
      ),
      Mood(
        id: '2',
        name: 'triste',
        displayName: 'Triste',
        iconName: 'cloud',
        gradientStart: '#475569',
        gradientEnd: '#1E3A5F',
        sortOrder: 2,
      ),
      Mood(
        id: '3',
        name: 'focus',
        displayName: 'Focus',
        iconName: 'headphones',
        gradientStart: '#6366F1',
        gradientEnd: '#7C3AED',
        sortOrder: 3,
      ),
      Mood(
        id: '4',
        name: 'energia',
        displayName: 'Energía',
        iconName: 'bolt',
        gradientStart: '#DC2626',
        gradientEnd: '#18181B',
        sortOrder: 4,
      ),
      Mood(
        id: '5',
        name: 'relax',
        displayName: 'Relax',
        iconName: 'spa',
        gradientStart: '#2DD4BF',
        gradientEnd: '#059669',
        sortOrder: 5,
      ),
      Mood(
        id: '6',
        name: 'fiesta',
        displayName: 'Fiesta',
        iconName: 'local_bar',
        gradientStart: '#EC4899',
        gradientEnd: '#E11D48',
        sortOrder: 6,
      ),
      Mood(
        id: '7',
        name: 'dormir',
        displayName: 'Dormir',
        iconName: 'nightlight',
        gradientStart: '#1C1917',
        gradientEnd: '#000000',
        sortOrder: 7,
      ),
      Mood(
        id: '8',
        name: 'romance',
        displayName: 'Romance',
        iconName: 'favorite',
        gradientStart: '#FB7185',
        gradientEnd: '#EF4444',
        sortOrder: 8,
      ),
    ];
  }

  Future<List<Song>> getSongsByMood(String moodId) async {
    // TODO: Implement actual API call
    // GET /songs?mood_id=$moodId
    return [];
  }

  Future<List<Song>> searchSongs(String query) async {
    // TODO: Implement actual API call
    // GET /search?q=$query
    return [];
  }

  Future<List<Playlist>> getUserPlaylists(String userId) async {
    // TODO: Implement actual API call
    // GET /users/$userId/playlists
    return [];
  }
}
