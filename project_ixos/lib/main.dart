import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/mood_provider.dart';
import 'providers/player_provider.dart';
import 'providers/auth_provider.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  const String baseUrl = 'https://musicapi.gamobo.shop'; // Reverted to standard HTTPS
  final authService = AuthService(baseUrl: baseUrl);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MoodProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = AuthProvider(authService);
            provider.checkAuth();
            return provider;
          },
        ),
      ],
      child: const IxosApp(),
    ),
  );
}

class IxosApp extends StatelessWidget {
  const IxosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ixos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF09090B),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
