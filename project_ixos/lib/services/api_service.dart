import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/song.dart';
import '../models/mood.dart';
import '../models/playlist.dart';
import '../models/artist.dart';
import '../models/album.dart';

class ApiService {
  final String baseUrl;
  final _storage = const FlutterSecureStorage();

  ApiService({this.baseUrl = 'https://musicapi.gamobo.shop'});

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'accessToken');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Helper to get current user ID for endpoints that require ?user_id=
  Future<String?> _getUserId() async {
    // This assumes the user ID might be stored or we can extract it.
    // For now, let's assume it's part of the login response saved elsewhere or we need to add it to storage.
    return await _storage.read(key: 'userId');
  }

  Future<List<Mood>> getMoods() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/moods'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Mood.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching moods: $e');
    }
    
    // Fallback/Mock if API fails
    return [
      Mood(id: '1', name: 'feliz', displayName: 'Feliz', iconName: 'sentiment_satisfied', gradientStart: '#FACC15', gradientEnd: '#F97316', sortOrder: 1),
      Mood(id: '2', name: 'triste', displayName: 'Triste', iconName: 'cloud', gradientStart: '#475569', gradientEnd: '#1E3A5F', sortOrder: 2),
      Mood(id: '3', name: 'focus', displayName: 'Focus', iconName: 'headphones', gradientStart: '#6366F1', gradientEnd: '#7C3AED', sortOrder: 3),
      Mood(id: '4', name: 'energia', displayName: 'Energía', iconName: 'bolt', gradientStart: '#DC2626', gradientEnd: '#18181B', sortOrder: 4),
      Mood(id: '5', name: 'relax', displayName: 'Relax', iconName: 'spa', gradientStart: '#2DD4BF', gradientEnd: '#059669', sortOrder: 5),
      Mood(id: '6', name: 'fiesta', displayName: 'Fiesta', iconName: 'local_bar', gradientStart: '#EC4899', gradientEnd: '#E11D48', sortOrder: 6),
      Mood(id: '7', name: 'dormir', displayName: 'Dormir', iconName: 'nightlight', gradientStart: '#1C1917', gradientEnd: '#000000', sortOrder: 7),
      Mood(id: '8', name: 'romance', displayName: 'Romance', iconName: 'favorite', gradientStart: '#FB7185', gradientEnd: '#EF4444', sortOrder: 8),
    ];
  }

  Future<List<Song>> getSongsByMood(String moodId) async {
    try {
      // Updated to use the new general songs endpoint with mood filter if supported, 
      // or check if there's a specific mood songs endpoint. 
      // Docs say: GET /api/v1/songs
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/songs?mood_id=$moodId'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Song.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching songs by mood: $e');
    }
    return [];
  }

  Future<List<Song>> searchSongs(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/search?q=$query'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        // The new docs don't specify search response structure, 
        // but let's assume it returns a list of items or the previous entity structure.
        if (data is List) {
           return data.map((json) => Song.fromJson(json)).toList();
        } else if (data is Map && data.containsKey('data')) {
           final List<dynamic> results = data['data'];
           return results.map((json) => Song.fromJson(json)).toList();
        }
      }
    } catch (e) {
      print('Error searching songs: $e');
    }
    return [];
  }

  Future<List<Playlist>> getUserPlaylists() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/playlists'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Playlist.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching playlists: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getCatalog() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/catalog'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching catalog: $e');
    }
    return {};
  }

  Future<List<Song>> getLikedSongs() async {
    final userId = await _getUserId();
    if (userId == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/liked-songs?user_id=$userId'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Song.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching liked songs: $e');
    }
    return [];
  }
}
