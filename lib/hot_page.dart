import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './url_constants.dart';
import './common_music_player.dart';

class HotPage extends StatefulWidget {
  final String? userId;

  const HotPage({Key? key, this.userId}) : super(key: key);

  @override
  State<HotPage> createState() => _HotPageState();
}

class _HotPageState extends State<HotPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {

  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> hotCategories = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Preloading management
  final Map<String, List<Widget>> _preloadedMusicPlayers = {};
  final Map<String, bool> _categoryPreloadStatus = {};
  final Map<String, bool> _expandedStates = {};
  bool _allCategoriesPreloaded = false;

  // Loading animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  // Genre display names
  final Map<String, String> genreDisplayNames = {
    'afrohouse': 'Afro House',
    'indiedance': 'Indie Dance',
    'organichouse': 'Organic House',
    'downtempo': 'Down Tempo',
    'melodichouse': 'Melodic House',
  };

  // Genre icons
  final Map<String, IconData> genreIcons = {
    'afrohouse': Icons.music_note,
    'indiedance': Icons.queue_music,
    'organichouse': Icons.nature,
    'downtempo': Icons.slow_motion_video,
    'melodichouse': Icons.piano,
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadHotCategories();
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

  Future<void> _loadHotCategories() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/hot'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted && data['success'] == true) {
          final categories = data['hotPlaylists'] as List<dynamic>;

          // Pre-process and preload categories
          await _preprocessAndPreloadCategories(categories);

          setState(() {
            hotCategories = List<Map<String, dynamic>>.from(categories);
          });

          // Wait for all preloading to complete
          await _waitForPreloadingComplete();
        }
      } else {
        throw Exception('Failed to load hot categories: ${response.statusCode}');
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

  Future<void> _preprocessAndPreloadCategories(List<dynamic> categories) async {
    print('Hot Page: Preprocessing ${categories.length} categories');

    for (final category in categories) {
      final genre = category['genre']?.toString();
      if (genre == null) continue;

      // Initialize states
      _expandedStates[genre] = false;
      _categoryPreloadStatus[genre] = false;

      // Skip empty categories
      if (category['isEmpty'] == true || category['name'] == null) {
        _preloadedMusicPlayers[genre] = [];
        _categoryPreloadStatus[genre] = true;
        continue;
      }

      final musics = category['musics'] as List<dynamic>? ?? [];
      if (musics.isEmpty) {
        _preloadedMusicPlayers[genre] = [];
        _categoryPreloadStatus[genre] = true;
        continue;
      }

      // Create CommonMusicPlayer widgets for all tracks with preloading enabled
      final List<Widget> musicPlayers = [];

      for (final music in musics) {
        final musicPlayer = CommonMusicPlayer(
          key: ValueKey('hot_${genre}_${music['_id'] ?? music['spotifyId']}'),
          track: music,
          userId: widget.userId,
          preloadWebView: true,
          lazyLoad: false,
          onLikeChanged: () {
            _loadHotCategories();
          },
        );
        musicPlayers.add(musicPlayer);
      }

      _preloadedMusicPlayers[genre] = musicPlayers;
      _categoryPreloadStatus[genre] = true;

      print('Hot Page: Preloaded ${musics.length} tracks for category: ${category['genreDisplayName']}');
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _waitForPreloadingComplete() async {
    print('Hot Page: Waiting for preloading to complete...');

    // Simulate preloading time
    await Future.delayed(Duration(seconds: 3));

    if (mounted) {
      setState(() {
        isLoading = false;
        _allCategoriesPreloaded = true;
      });
      _animationController.stop();
      print('Hot Page: All categories preloaded!');
    }
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Text(
                  'H',
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
            'Hot Tracks Yükleniyor...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(Map<String, dynamic> category) {
    final genre = category['genre']?.toString() ?? '';
    final genreDisplayName = category['genreDisplayName'] ?? genreDisplayNames[genre] ?? genre;
    final isPreloaded = _categoryPreloadStatus[genre] ?? false;
    final preloadedPlayers = _preloadedMusicPlayers[genre] ?? [];
    final isExpanded = _expandedStates[genre] ?? false;
    final isEmpty = category['isEmpty'] == true || category['name'] == null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: ExpansionTile(
        key: ValueKey(genre),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _expandedStates[genre] = expanded;
          });
        },
        tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: EdgeInsets.only(bottom: 8),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white70,
        leading: Container(
          width: 8,
          height: 40,
          decoration: BoxDecoration(
            color: isEmpty ? Colors.grey[600] : Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(
          genreDisplayName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: isEmpty
            ? Text(
          'Henüz playlist eklenmedi',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 13,
          ),
        )
            : Text(
          category['name'] ?? 'Unnamed Playlist',
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 14,
          ),
        ),
        children: [
          if (!isEmpty && isExpanded) ...[
            if (isPreloaded && preloadedPlayers.isNotEmpty)
              ...preloadedPlayers.map((player) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: player,
              )).toList()
            else if (!isPreloaded)
              Container(
                height: 80,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 60,
                child: Center(
                  child: Text(
                    'Empty playlist',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
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

    if (isLoading || !_allCategoriesPreloaded) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildLoadingScreen(),
      );
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
                'Yükleme hatası',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadHotCategories,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (hotCategories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_off,
                color: Colors.grey[600],
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Henüz hot playlist bulunamadı',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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
        onRefresh: _loadHotCategories,
        color: Colors.orange,
        backgroundColor: Colors.black,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.withOpacity(0.1), Colors.red.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.orange, Colors.red]),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.whatshot, color: Colors.white, size: 28),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hot Playlsits',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Categories List
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final category = hotCategories[index];
                  return _buildCategorySection(category);
                },
                childCount: hotCategories.length,
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