import 'package:flutter/material.dart';

void main() {
  runApp(const IxosApp());
}

class IxosApp extends StatelessWidget {
  const IxosApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF09090B);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ixos',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.dark,
        ),
      ),
      home: const PlaylistHomePage(),
    );
  }
}

class PlaylistHomePage extends StatefulWidget {
  const PlaylistHomePage({super.key});

  @override
  State<PlaylistHomePage> createState() => _PlaylistHomePageState();
}

class _PlaylistHomePageState extends State<PlaylistHomePage> {
  static const _background = Color(0xFF09090B);
  static const _navBackground = Color(0xFF18181B);
  static const _cardBackground = Color(0xFF27272A);
  static const _borderColor = Color(0xFF3F3F46);

  int _selectedPlaylistIndex = 2;
  int _selectedNavIndex = 0;
  bool _isPlaying = false;

  MoodPlaylist get _selectedPlaylist => _playlists[_selectedPlaylistIndex];

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: _background,
      body: ColoredBox(
        color: _background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: _background,
                border: Border(
                  left: BorderSide(color: Color(0xFF27272A)),
                  right: BorderSide(color: Color(0xFF27272A)),
                ),
              ),
              child: Stack(
                children: [
                  SafeArea(
                    bottom: false,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            22,
                            20,
                            196 + safeArea.bottom,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate.fixed([
                              const _Header(),
                              const SizedBox(height: 24),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _playlists.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 18,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: 0.8,
                                    ),
                                itemBuilder: (context, index) {
                                  final playlist = _playlists[index];
                                  final isSelected =
                                      index == _selectedPlaylistIndex;

                                  return _PlaylistTile(
                                    playlist: playlist,
                                    isSelected: isSelected,
                                    onTap: () {
                                      setState(() {
                                        _selectedPlaylistIndex = index;
                                      });
                                    },
                                  );
                                },
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 84 + safeArea.bottom,
                    child: _MiniPlayer(
                      backgroundColor: _cardBackground,
                      borderColor: _borderColor,
                      playlist: _selectedPlaylist,
                      isPlaying: _isPlaying,
                      onPlayPressed: () {
                        setState(() {
                          _isPlaying = !_isPlaying;
                        });
                      },
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomBar(
                      backgroundColor: _navBackground,
                      borderColor: const Color(0xFF27272A),
                      safeBottom: safeArea.bottom,
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Playlists',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.isSelected,
    required this.onTap,
  });

  final MoodPlaylist playlist;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shadowColor = playlist.gradient.last.withValues(alpha: 0.28);
    final borderColor = playlist.showBorder
        ? const Color(0xFF27272A)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: playlist.gradient,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.28)
                        : borderColor,
                    width: isSelected ? 1.2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: isSelected ? 26 : 18,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    playlist.icon,
                    size: 50,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              playlist.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.backgroundColor,
    required this.borderColor,
    required this.playlist,
    required this.isPlaying,
    required this.onPlayPressed,
  });

  final Color backgroundColor;
  final Color borderColor;
  final MoodPlaylist playlist;
  final bool isPlaying;
  final VoidCallback onPlayPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: playlist.gradient,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.music_note_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playlist.playerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    playlist.playerSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFA1A1AA),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onPlayPressed,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: const Color(0xFFD4D4D8),
                size: 28,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.skip_next_rounded,
                color: Color(0xFFD4D4D8),
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.backgroundColor,
    required this.borderColor,
    required this.safeBottom,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final Color backgroundColor;
  final Color borderColor;
  final double safeBottom;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = safeBottom > 0 ? safeBottom : 12.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 12, 8, bottomPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _NavItem(
              icon: Icons.auto_stories_rounded,
              label: 'Libreria',
              isSelected: selectedIndex == 0,
              onTap: () => onItemSelected(0),
            ),
            _NavItem(
              icon: Icons.search_rounded,
              label: 'Buscar',
              isSelected: selectedIndex == 1,
              onTap: () => onItemSelected(1),
            ),
            Transform.translate(
              offset: const Offset(0, -16),
              child: InkWell(
                onTap: () => onItemSelected(2),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x52000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
              ),
            ),
            _NavItem(
              icon: Icons.album_rounded,
              label: 'DJ',
              isSelected: selectedIndex == 3,
              onTap: () => onItemSelected(3),
            ),
            _NavItem(
              icon: Icons.account_circle_rounded,
              label: 'Perfil',
              isSelected: selectedIndex == 4,
              onTap: () => onItemSelected(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.white : const Color(0xFF71717A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MoodPlaylist {
  const MoodPlaylist({
    required this.label,
    required this.playerTitle,
    required this.playerSubtitle,
    required this.icon,
    required this.gradient,
    this.showBorder = false,
  });

  final String label;
  final String playerTitle;
  final String playerSubtitle;
  final IconData icon;
  final List<Color> gradient;
  final bool showBorder;
}

const _playlists = <MoodPlaylist>[
  MoodPlaylist(
    label: 'Feliz',
    playerTitle: 'Brillo de Manana',
    playerSubtitle: 'Sunny Mix',
    icon: Icons.sentiment_satisfied_alt_rounded,
    gradient: [Color(0xFFFACC15), Color(0xFFF97316)],
  ),
  MoodPlaylist(
    label: 'Triste',
    playerTitle: 'Lluvia en Repeat',
    playerSubtitle: 'Melancholy Session',
    icon: Icons.cloud_rounded,
    gradient: [Color(0xFF475569), Color(0xFF1D4ED8)],
  ),
  MoodPlaylist(
    label: 'Focus',
    playerTitle: 'Beats para Codear',
    playerSubtitle: 'Focus Mode',
    icon: Icons.headphones_rounded,
    gradient: [Color(0xFF6366F1), Color(0xFF7E22CE)],
  ),
  MoodPlaylist(
    label: 'Energia',
    playerTitle: 'Carga Total',
    playerSubtitle: 'Power Drive',
    icon: Icons.flash_on_rounded,
    gradient: [Color(0xFFDC2626), Color(0xFF18181B)],
  ),
  MoodPlaylist(
    label: 'Relax',
    playerTitle: 'Bosque Lento',
    playerSubtitle: 'Calm Flow',
    icon: Icons.spa_rounded,
    gradient: [Color(0xFF2DD4BF), Color(0xFF047857)],
  ),
  MoodPlaylist(
    label: 'Fiesta',
    playerTitle: 'Luces de Medianoche',
    playerSubtitle: 'Party Pulse',
    icon: Icons.local_bar_rounded,
    gradient: [Color(0xFFEC4899), Color(0xFFE11D48)],
  ),
  MoodPlaylist(
    label: 'Dormir',
    playerTitle: 'Sueno Profundo',
    playerSubtitle: 'Night Reset',
    icon: Icons.dark_mode_rounded,
    gradient: [Color(0xFF27272A), Color(0xFF000000)],
    showBorder: true,
  ),
  MoodPlaylist(
    label: 'Romance',
    playerTitle: 'Late Night Heartbeat',
    playerSubtitle: 'Romantic Mood',
    icon: Icons.favorite_rounded,
    gradient: [Color(0xFFFB7185), Color(0xFFEF4444)],
  ),
];
