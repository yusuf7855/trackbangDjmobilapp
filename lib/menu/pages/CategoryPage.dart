import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../url_constants.dart';
import '../../common_music_player.dart';

class CategoryPage extends StatefulWidget {
  final String category;
  final String title;

  const CategoryPage({Key? key, required this.category, required this.title}) : super(key: key);

  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> musicList = [];
  bool isLoading = true;
  String? userId;

  // Loading animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  // Preloading management
  final Map<String, bool> _musicPlayerLoadStatus = {};
  final Map<String, Widget> _preloadedMusicPlayers = {};
  bool _allMusicPlayersLoaded = false;
  int _loadedPlayerCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeUser();
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

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });

    // Fetch music data and preload
    await _fetchCategoryMusic();
  }

  Future<void> _fetchCategoryMusic() async {
    try {
      print('CategoryPage: Fetching music for category: ${widget.category}');

      final response = await http.get(Uri.parse('${UrlConstants.apiBaseUrl}/api/music'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        final filteredMusic = data
            .where((item) => item['category'].toLowerCase() == widget.category.toLowerCase())
            .map((item) => ({
          'id': item['spotifyId'],
          'title': item['title'],
          'artist': item['artist'],
          'likes': item['likes'] ?? 0,
          '_id': item['_id'],
          'userLikes': item['userLikes'] ?? [],
          'beatportUrl': item['beatportUrl'] ?? '',
          'spotifyId': item['spotifyId'],
          'category': item['category'],
        }))
            .toList();

        if (mounted) {
          setState(() {
            musicList = filteredMusic;
          });

          // Start preloading music players
          await _preloadMusicPlayers();
        }
      } else {
        throw Exception('Failed to load music');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _animationController.stop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.title} müzikleri yüklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _preloadMusicPlayers() async {
    if (musicList.isEmpty) {
      setState(() {
        isLoading = false;
        _allMusicPlayersLoaded = true;
      });
      _animationController.stop();
      return;
    }

    print('CategoryPage: Preloading ${musicList.length} music players for ${widget.title}');

    // Initialize loading status for all tracks
    for (final track in musicList) {
      final trackId = track['_id']?.toString() ?? '';
      _musicPlayerLoadStatus[trackId] = false;
    }

    // Create preloaded music players
    for (int i = 0; i < musicList.length; i++) {
      final track = musicList[i];
      final trackId = track['_id']?.toString() ?? '';

      final musicPlayer = CommonMusicPlayer(
        key: ValueKey('category_${widget.category}_${trackId}_$i'),
        track: track,
        userId: userId,
        preloadWebView: true, // Enable preloading
        lazyLoad: false, // Disable lazy loading for instant display
        webViewKey: trackId,
        onWebViewLoaded: _onMusicPlayerLoaded,
        onLikeChanged: _refreshData,
      );

      _preloadedMusicPlayers[trackId] = musicPlayer;
    }

    // Simulate realistic loading time - adjust based on your needs
    await Future.delayed(Duration(seconds: 3));

    if (mounted) {
      setState(() {
        isLoading = false;
        _allMusicPlayersLoaded = true;
      });
      _animationController.stop();
      print('CategoryPage: All music players preloaded for ${widget.title}');
    }
  }

  void _onMusicPlayerLoaded(String trackId) {
    if (mounted && _musicPlayerLoadStatus.containsKey(trackId)) {
      setState(() {
        _musicPlayerLoadStatus[trackId] = true;
        _loadedPlayerCount++;
      });

      print('CategoryPage: Music player loaded ($trackId) - ${_loadedPlayerCount}/${musicList.length}');

      // Check if all players are loaded
      if (_loadedPlayerCount >= musicList.length && !_allMusicPlayersLoaded) {
        setState(() {
          isLoading = false;
          _allMusicPlayersLoaded = true;
        });
        _animationController.stop();
        print('CategoryPage: All music players loaded for ${widget.title}!');
      }
    }
  }

  void _refreshData() {
    // Reset loading states
    _musicPlayerLoadStatus.clear();
    _preloadedMusicPlayers.clear();
    _loadedPlayerCount = 0;
    _allMusicPlayersLoaded = false;

    setState(() {
      isLoading = true;
    });

    _animationController.repeat(reverse: true);
    _fetchCategoryMusic();
  }

  Widget _buildLoadingAnimation() {
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
                  widget.title.substring(0, 1).toUpperCase(),
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
            '${widget.title} Yükleniyor...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Spotify player\'lar hazırlanıyor',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 30),
          // Progress indicator
          if (_loadedPlayerCount > 0 && musicList.isNotEmpty)
            Column(
              children: [
                LinearProgressIndicator(
                  value: _loadedPlayerCount / musicList.length,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 12),
                Text(
                  '${_loadedPlayerCount}/${musicList.length} müzik hazır',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[850]!,
            Colors.grey[900]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[700]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
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
            child: Icon(Icons.library_music, color: Colors.white, size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Curated ${widget.category} tracks',
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
              '${musicList.length} TRACKS',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: 28,
        ),
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      backgroundColor: Colors.black,
      body: isLoading || !_allMusicPlayersLoaded
          ? _buildLoadingAnimation()
          : musicList.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.title} kategorisinde şarkı bulunamadı',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Yenile'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          _refreshData();
        },
        color: Colors.white,
        backgroundColor: Colors.black,
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            // Music List
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final track = musicList[index];
                  final trackId = track['_id']?.toString() ?? '';

                  // Return preloaded music player if available
                  if (_preloadedMusicPlayers.containsKey(trackId)) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      child: _preloadedMusicPlayers[trackId],
                    );
                  }

                  // Fallback - shouldn't happen with preloading
                  return Container(
                    margin: EdgeInsets.only(bottom: 16),
                    child: CommonMusicPlayer(
                      track: track,
                      userId: userId,
                      onLikeChanged: _refreshData,
                    ),
                  );
                },
                childCount: musicList.length,
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