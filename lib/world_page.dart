import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../url_constants.dart';
import '../common_music_player.dart';

class WorldPage extends StatefulWidget {
  final String? userId;

  const WorldPage({Key? key, this.userId}) : super(key: key);

  @override
  State<WorldPage> createState() => _WorldPageState();
}

class _WorldPageState extends State<WorldPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> worldPlaylists = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Preloading management
  final Map<String, List<Widget>> _preloadedMusicPlayers = {};
  final Map<String, bool> _playlistPreloadStatus = {};
  final Map<String, bool> _expandedStates = {}; // Track expansion states
  bool _allPlaylistsPreloaded = false;

  // Loading animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadWorldPlaylists();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _colorAnimation = ColorTween(
      begin: Colors.white.withOpacity(0.8),
      end: Colors.white,
    ).animate(_animationController);
  }

  Future<void> _loadWorldPlaylists() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/public-world'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          final playlists = data['playlists'] ?? [];

          // Pre-process and preload playlists
          await _preprocessAndPreloadPlaylists(playlists);

          setState(() {
            worldPlaylists = playlists;
          });

          // Wait for all preloading to complete
          await _waitForPreloadingComplete();
        }
      } else {
        throw Exception('Failed to load playlists: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = e.toString();
        });
        _animationController.stop();
      }
    }
  }

  Future<void> _preprocessAndPreloadPlaylists(List<dynamic> playlists) async {
    print('World Page: Preprocessing ${playlists.length} playlists');

    for (final playlist in playlists) {
      final playlistId = playlist['_id']?.toString();
      if (playlistId == null) continue;

      // Initialize states
      _expandedStates[playlistId] = false;
      _playlistPreloadStatus[playlistId] = false;

      final musics = playlist['musics'] as List<dynamic>? ?? [];
      if (musics.isEmpty) {
        _preloadedMusicPlayers[playlistId] = [];
        _playlistPreloadStatus[playlistId] = true;
        continue;
      }

      // Create CommonMusicPlayer widgets for all tracks with preloading enabled
      final List<Widget> musicPlayers = [];

      for (final music in musics) {
        final musicPlayer = CommonMusicPlayer(
          key: ValueKey('world_${playlistId}_${music['_id'] ?? music['spotifyId']}'), // Stable key
          track: music,
          userId: widget.userId,
          preloadWebView: true, // Enable preloading
          lazyLoad: false, // Disable lazy loading for preloading
          onLikeChanged: () {
            _loadWorldPlaylists();
          },
        );
        musicPlayers.add(musicPlayer);
      }

      _preloadedMusicPlayers[playlistId] = musicPlayers;
      _playlistPreloadStatus[playlistId] = true;

      print('World Page: Preloaded ${musics.length} tracks for playlist: ${playlist['name']}');
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _waitForPreloadingComplete() async {
    print('World Page: Waiting for preloading to complete...');

    // Simulate preloading time - in real app this would be based on actual WebView loading
    await Future.delayed(Duration(seconds: 3));

    if (mounted) {
      setState(() {
        isLoading = false;
        _allPlaylistsPreloaded = true;
      });
      _animationController.stop();
      print('World Page: All playlists preloaded!');
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Text(
                    'W',
                    style: TextStyle(
                      color: _colorAnimation.value,
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      shadows: [
                        Shadow(
                          color: Colors.white.withOpacity(0.7),
                          blurRadius: 15,
                          offset: Offset(0, 0),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 30),
            Text(
              'World Playlists Yükleniyor...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 18,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Dünya çapında paylaşılan müzikler hazırlanıyor',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // World playlist card section - Dropdown style with performance optimization
  Widget _buildWorldPlaylistSection(Map<String, dynamic> playlist) {
    final playlistId = playlist['_id']?.toString() ?? '';
    final musics = playlist['musics'] as List<dynamic>? ?? [];
    final owner = playlist['owner'] as Map<String, dynamic>?;
    final isPreloaded = _playlistPreloadStatus[playlistId] ?? false;
    final preloadedPlayers = _preloadedMusicPlayers[playlistId] ?? [];
    final isExpanded = _expandedStates[playlistId] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Minimal spacing
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        key: ValueKey(playlistId), // Stable key for ExpansionTile
        initiallyExpanded: isExpanded, // Keep previous state
        onExpansionChanged: (expanded) {
          setState(() {
            _expandedStates[playlistId] = expanded;
          });
        },
        tilePadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Reduced padding
        childrenPadding: EdgeInsets.only(bottom: 4), // Reduced bottom padding
        iconColor: Colors.white,
        collapsedIconColor: Colors.white70,
        leading: Container(
          padding: EdgeInsets.all(6), // Smaller icon container
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.public,
            color: Colors.white,
            size: 16, // Smaller icon
          ),
        ),
        title: Text(
          playlist['name'] ?? 'Unnamed World Playlist',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16, // Slightly smaller font
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (owner != null) ...[
              const SizedBox(height: 1),
              Text(
                'by ${owner['displayName'] ?? owner['username'] ?? 'Unknown'}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11, // Smaller subtitle
                ),
              ),
            ],
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.music_note, color: Colors.grey[400], size: 14),
                const SizedBox(width: 3),
                Text(
                  '${musics.length} songs',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                if (isPreloaded)
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        'Ready',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
        children: [
          // Only show children when expanded AND preloaded
          if (isExpanded) ...[
            if (isPreloaded && preloadedPlayers.isNotEmpty)
            // Cached preloaded players - NO re-rendering
              ...preloadedPlayers.map((player) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: player,
              )).toList()
            else if (!isPreloaded)
              Container(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Loading ${musics.length} tracks...',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            else if (musics.isEmpty)
                Container(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'This playlist is empty',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (isLoading || !_allPlaylistsPreloaded) {
      return _buildLoadingScreen();
    }

    if (hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Failed to load world playlists',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                errorMessage,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadWorldPlaylists,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (worldPlaylists.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.playlist_remove,
                color: Colors.grey[600],
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'No world playlists found',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Check back later for new content',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // MAIN BUILD - Dropdown style with minimal spacing
    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _loadWorldPlaylists,
        color: Colors.white,
        backgroundColor: Colors.black,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: 8), // Reduced top spacing
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final playlist = worldPlaylists[index];
                  return _buildWorldPlaylistSection(playlist);
                },
                childCount: worldPlaylists.length,
              ),
            ),
            // Bottom padding
            SliverToBoxAdapter(
              child: SizedBox(height: 80), // Reduced bottom spacing
            ),
          ],
        ),
      ),
    );
  }
}