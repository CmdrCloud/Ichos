import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/mood_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final moodProvider = context.watch<MoodProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: moodProvider.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: moodProvider.cardBackground,
                backgroundImage: user?.avatarUrl != null 
                  ? NetworkImage(user!.avatarUrl!) 
                  : null,
                child: user?.avatarUrl == null 
                  ? const Icon(Icons.person, size: 50, color: Colors.white54) 
                  : null,
              ),
              const SizedBox(height: 16),
              // User Info
              Text(
                user?.displayName ?? 'User',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '@${user?.username ?? 'username'}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 32),
              
              // Action List
              _ProfileTile(
                icon: Icons.favorite,
                label: 'Liked Songs',
                onTap: () {
                  // TODO: Navigate to Liked Songs
                },
              ),
              _ProfileTile(
                icon: Icons.playlist_play,
                label: 'My Playlists',
                onTap: () {
                  // TODO: Navigate to Playlists
                },
              ),
              _ProfileTile(
                icon: Icons.download_for_offline,
                label: 'Downloads',
                onTap: () {
                  // TODO: Navigate to Downloads
                },
              ),
              _ProfileTile(
                icon: Icons.settings,
                label: 'Settings',
                onTap: () {
                  // TODO: Navigate to Settings
                },
              ),
              
              const SizedBox(height: 32),
              
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _showLogoutDialog(context, authProvider);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              authProvider.logout();
              Navigator.pop(context);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final moodProvider = context.watch<MoodProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        tileColor: moodProvider.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: Colors.white70),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      ),
    );
  }
}
