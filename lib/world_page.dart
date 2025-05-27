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
  final Map<String, bool> _expandedStates = {};
  final Map<String, List<Widget>> _preloadedMusicPlayers = {};
  final Map<String, bool> _playlistPreloadStatus = {};
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

      // Initialize expanded state
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
          key: ValueKey('world_${playlistId}_${music['_id'] ?? music['spotifyId']}'),
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

  void _onExpansionChanged(String playlistId, bool expanded) {
    if (!mounted) return;

    setState(() {
      _expandedStates[playlistId] = expanded;
    });
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

  Widget _buildPlaylistCard(Map<String, dynamic> playlist) {
    final playlistId = playlist['_id']?.toString() ?? '';
    final musics = playlist['musics'] as List<dynamic>? ?? [];
    final owner = playlist['owner'] as Map<String, dynamic>?;
    final isExpanded = _expandedStates[playlistId] ?? false;
    final isPreloaded = _playlistPreloadStatus[playlistId] ?? false;
    final preloadedPlayers = _preloadedMusicPlayers[playlistId] ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        key: ValueKey(playlistId),
        tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        childrenPadding: EdgeInsets.only(bottom: 16),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white70,
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) => _onExpansionChanged(playlistId, expanded),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.public, color: Colors.white, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                playlist['name'] ?? 'Unnamed Playlist',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            // Preload status indicator
            Container(
              margin: EdgeInsets.only(left: 8),
              child: Icon(
                isPreloaded ? Icons.check_circle : Icons.hourglass_empty,
                color: isPreloaded ? Colors.green : Colors.orange,
                size: 16,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            if (owner != null)
              Text(
                'by ${owner['displayName'] ?? owner['username'] ?? 'Unknown'}',
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.music_note, color: Colors.grey[400], size: 16),
                const SizedBox(width: 4),
                Text(
                  '${playlist['musicCount'] ?? musics.length} songs',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Icon(Icons.category, color: Colors.grey[400], size: 16),
                const SizedBox(width: 4),
                Text(
                  playlist['genre'] ?? 'Mixed',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Text(
                  isPreloaded ? 'Ready' : 'Loading...',
                  style: TextStyle(
                    color: isPreloaded ? Colors.green : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          if (isExpanded) ...[
            if (isPreloaded && preloadedPlayers.isNotEmpty)
            // Show preloaded music players instantly
              ...preloadedPlayers
            else if (!isPreloaded)
            // Show loading state
              Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Loading ${musics.length} world tracks...',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              )
            else if (musics.isEmpty)
                Container(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'This playlist is empty',
                    style: TextStyle(color: Colors.grey[400]),
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _loadWorldPlaylists,
        color: Colors.white,
        backgroundColor: Colors.black,
        child: CustomScrollView(
          slivers: [
            // Header section
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.withOpacity(0.2),
                      Colors.purple.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue, Colors.purple],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.public, color: Colors.white, size: 28),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'World Playlists',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Discover music from around the globe',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${worldPlaylists.length} LISTS',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Playlist list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final playlist = worldPlaylists[index];
                  return _buildPlaylistCard(playlist);
                },
                childCount: worldPlaylists.length,
              ),
            ),

            // Bottom padding
            SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }
}