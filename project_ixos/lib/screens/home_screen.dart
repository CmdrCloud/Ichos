import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mood_provider.dart';
import '../providers/player_provider.dart';
import '../services/api_service.dart';
import '../models/mood.dart';
import '../widgets/playlist_tile.dart';
import '../widgets/mini_player.dart';
import '../widgets/bottom_bar.dart';
import 'search_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<Mood> _moods = [];
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMoods();
  }

  Future<void> _loadMoods() async {
    final moods = await _apiService.getMoods();
    setState(() {
      _moods = moods;
    });
    if (moods.isNotEmpty && mounted) {
      context.read<MoodProvider>().setMood(moods.first);
    }
  }

  Widget _buildBody() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const SearchScreen();
      case 2:
        return const Center(child: Text('Library (Coming Soon)', style: TextStyle(color: Colors.white)));
      case 3:
        return const ProfileScreen();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    final moodProvider = context.watch<MoodProvider>();
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 196),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              const _Header(),
              const SizedBox(height: 24),
              if (_moods.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _moods.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, index) {
                    final mood = _moods[index];
                    final isSelected = moodProvider.currentMood?.id == mood.id;

                    return PlaylistTile(
                      mood: mood,
                      isSelected: isSelected,
                      onTap: () {
                        moodProvider.setMood(mood);
                      },
                    );
                  },
                ),
            ]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.paddingOf(context);
    final moodProvider = context.watch<MoodProvider>();
    final playerProvider = context.watch<PlayerProvider>();

    return Scaffold(
      backgroundColor: moodProvider.backgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: moodProvider.backgroundColor,
              border: Border(
                left: BorderSide(color: moodProvider.borderColor),
                right: BorderSide(color: moodProvider.borderColor),
              ),
            ),
            child: Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: _buildBody(),
                ),
                if (playerProvider.currentSong != null)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 84 + safeArea.bottom,
                    child: const MiniPlayer(),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: BottomBar(
                    selectedIndex: _selectedNavIndex,
                    onItemSelected: (index) {
                      setState(() {
                        _selectedNavIndex = index;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good morning',
          style: TextStyle(
            color: Color(0xFFA1A1AA),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Your Playlists',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
