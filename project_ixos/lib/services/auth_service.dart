import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class AuthService {
  final String baseUrl;
  final _storage = const FlutterSecureStorage();

  AuthService({required this.baseUrl});

  Future<Map<String, dynamic>?> login(String identifier, String password) async {
    try {
      print('Attempting login at: $baseUrl/api/v1/auth/login');
      // The server error "Email and password are required" suggests it wants 'email' instead of 'identifier'
      final body = jsonEncode({'email': identifier, 'password': password});
      print('Login body: $body');

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Handle both 'accessToken' and 'token' keys depending on the API version
        final token = data['accessToken'] ?? data['token'];
        final refreshToken = data['refreshToken'];

        if (token != null) {
          await _storage.write(key: 'accessToken', value: token);
        }
        if (refreshToken != null) {
          await _storage.write(key: 'refreshToken', value: refreshToken);
        }

        if (data['user'] != null && data['user']['id'] != null) {
          await _storage.write(key: 'userId', value: data['user']['id']);
        }
        return data;
      }
    } catch (e) {
      print('Login error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      print('Attempting register at: $baseUrl/api/v1/auth/register');
      final body = jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'displayName': displayName,
      });
      print('Register body: $body');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      print('Register response status: ${response.statusCode}');
      print('Register response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      }
    } catch (e) {
      print('Register error: $e');
    }
    return null;
  }

  Future<void> logout() async {
    final refresh = await _storage.read(key: 'refreshToken');
    if (refresh != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/api/v1/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refresh}),
        );
      } catch (e) {
        print('Logout error: $e');
      }
    }
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
    await _storage.delete(key: 'userId');
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'accessToken');
  }

  Future<String?> refreshToken() async {
    final refresh = await _storage.read(key: 'refreshToken');
    if (refresh == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.write(key: 'accessToken', value: data['accessToken']);
        await _storage.write(key: 'refreshToken', value: data['refreshToken']);
        return data['accessToken'];
      }
    } catch (e) {
      print('Refresh token error: $e');
    }
    return null;
  }
}
