import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import './url_constants.dart';
import './create_playlist.dart';
import './menu/listeler_screen.dart';
import './menu/sample_bank_screen.dart';
import './menu/mostening_screen.dart';
import './menu/magaza_screen.dart';
import './menu/biz_kimiz_screen.dart';
import './world_page.dart';
import './hot_page.dart';
import './login_page.dart';
import './common_music_player.dart';
import './top10_music_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed; // Menu butonuna basılınca çağrılacak fonksiyon

  const HomeScreen({Key? key, this.onMenuPressed}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String? userId;

  // Data for different tabs
  Map<String, List<dynamic>> top10Data = {};
  List<dynamic> housePlaylists = [];
  List<dynamic> userPlaylists = [];

  // Loading states
  bool isLoadingTop10 = true;
  bool isLoadingHouse = true;

  // Preloading management for Top10
  final Map<String, bool> _top10WebViewLoadedStatus = {};
  final Set<String> _allTop10TrackIds = {};
  bool _allTop10WebViewsLoaded = false;

  // Animation controller for loading
  late AnimationController _loadingAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeLoadingAnimation();
    _initializeUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  void _initializeLoadingAnimation() {
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _colorAnimation = ColorTween(
      begin: Colors.white.withOpacity(0.8),
      end: Colors.white,
    ).animate(_loadingAnimationController);
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });

    // Load all data
    await Future.wait([
      _loadTop10Data(),
      _loadHousePlaylists(),
    ]);

    if (userId != null) {
      _loadUserPlaylists();
    }
  }

  Future<void> _loadUserPlaylists() async {
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted && data['success'] == true) {
          setState(() {
            userPlaylists = data['playlists'] ?? [];
          });
        }
      }
    } catch (e) {
      print('Error loading user playlists: $e');
    }
  }

  Future<void> _loadTop10Data() async {
    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/music/top10'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          final top10Map = Map<String, List<dynamic>>.from(data['top10']);

          // Collect all track IDs for preloading
          final allTrackIds = <String>{};
          top10Map.values.forEach((tracks) {
            tracks.forEach((track) {
              final trackId = track['_id']?.toString();
              if (trackId != null) {
                allTrackIds.add(trackId);
              }
            });
          });

          setState(() {
            top10Data = top10Map;
            _allTop10TrackIds.addAll(allTrackIds);
          });

          // Start preloading WebViews
          await _preloadTop10WebViews();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingTop10 = false;
        });
      }
    }
  }

  Future<void> _preloadTop10WebViews() async {
    print('Starting to preload ${_allTop10TrackIds.length} Top10 WebViews');

    // Initialize loading status for all tracks
    for (final trackId in _allTop10TrackIds) {
      _top10WebViewLoadedStatus[trackId] = false;
    }

    // Hızlandırılmış yükleme süresi - 2 saniye
    await Future.delayed(Duration(seconds: 2));

    if (mounted) {
      setState(() {
        isLoadingTop10 = false;
        _allTop10WebViewsLoaded = true;
      });
    }

    _loadingAnimationController.stop();
  }

  void _onTop10WebViewLoaded(String trackId) {
    print('Top10 WebView loaded for track: $trackId');

    if (mounted) {
      setState(() {
        _top10WebViewLoadedStatus[trackId] = true;
      });

      // Check if all WebViews are loaded
      final loadedCount = _top10WebViewLoadedStatus.values.where((loaded) => loaded).length;
      final totalCount = _allTop10TrackIds.length;

      print('Top10 WebViews loaded: $loadedCount/$totalCount');

      if (loadedCount >= totalCount && !_allTop10WebViewsLoaded) {
        setState(() {
          isLoadingTop10 = false;
          _allTop10WebViewsLoaded = true;
        });
        _loadingAnimationController.stop();
        print('All Top10 WebViews loaded!');
      }
    }
  }

  Future<void> _loadHousePlaylists() async {
    if (userId == null) {
      setState(() {
        isLoadingHouse = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/following/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            housePlaylists = data['playlists'] ?? [];
            isLoadingHouse = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingHouse = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  // Loading animation widget
  Widget _buildLoadingAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _loadingAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Text(
                  'B',
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
            'İçerikler Yükleniyor...',
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
        ],
      ),
    );
  }

  Widget _buildTop10Tab() {
    // Show loading animation if still loading
    if (isLoadingTop10 || !_allTop10WebViewsLoaded) {
      return _buildLoadingAnimation();
    }

    final categories = [
      {'key': 'all', 'title': 'Trackbang Top 10'},
      {'key': 'afrohouse', 'title': 'Afro House'},
      {'key': 'indiedance', 'title': 'Indie Dance'},
      {'key': 'organichouse', 'title': 'Organic House'},
      {'key': 'downtempo', 'title': 'Down Tempo'},
      {'key': 'melodichouse', 'title': 'Melodic House'},
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final category = categories[index];
              final tracks = top10Data[category['key']] ?? [];
              return _buildCategorySection(category['title']!, tracks);
            },
            childCount: categories.length,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(String title, List<dynamic> tracks) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basit başlık - sola dayalı
          Container(
            margin: const EdgeInsets.only(left: 8), // Sol margin azaltıldı
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Padding azaltıldı
            child: Text(
              '# $title',  // Başına # ekle
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Top10MusicCard widget'ı - sağ sol margin ile, tüm frameler preload
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8), // Sağ sol boşluk
            child: Column(
              children: tracks.map<Widget>((music) {
                return CommonMusicPlayer(
                  key: ValueKey('top10_${music['_id']}_${title}'),
                  track: music,
                  userId: userId,
                  preloadWebView: true, // Hızlı preload
                  lazyLoad: false, // Lazy loading kapalı
                  onLikeChanged: () {
                    _loadTop10Data();
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // World tab uses the separate WorldPage
  Widget _buildWorldTab() {
    return WorldPage(userId: userId);
  }

  Widget _buildHouseTab() {
    if (isLoadingHouse) {
      return _buildLoadingAnimation();
    }

    if (housePlaylists.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No playlists from following users',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Follow users to see their playlists here',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final playlist = housePlaylists[index];
              return _buildPlaylistCard(playlist);
            },
            childCount: housePlaylists.length,
          ),
        ),
      ],
    );
  }

  // Hot tab uses the separate HotPage
  Widget _buildHotTab() {
    return HotPage(userId: userId);
  }

  Widget _buildPlaylistCard(Map<String, dynamic> playlist) {
    final musics = playlist['musics'] as List<dynamic>? ?? [];
    final owner = playlist['owner'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern playlist header - minimalist design like Top10
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist['name'] ?? 'Unnamed Playlist',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (owner != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'by ${owner['displayName'] ?? owner['username']}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${musics.length}',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Music cards - minimalist style like Top10
          if (musics.isNotEmpty)
            ...musics.map((music) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: CommonMusicPlayer(
                track: music,
                userId: userId,
                preloadWebView: true,
                lazyLoad: false,
                onLikeChanged: () {
                  _loadHousePlaylists();
                },
              ),
            )).toList()
          else
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!, width: 1),
              ),
              child: Text(
                'This playlist is empty',
                style: TextStyle(color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false, // Default leading'i kapat
        title: Row(
          children: [
            // Menu button - MainHomePage'deki drawer'ı açacak
            IconButton(
              icon: Icon(Icons.menu, color: Colors.white, size: 28),
              onPressed: widget.onMenuPressed, // Parent'tan gelen fonksiyonu çağır
              padding: EdgeInsets.zero, // Padding'i kaldır
            ),

            // Logo - direkt yanında
            Container(
              margin: EdgeInsets.only(left: 4), // Minimal margin
              child: Image.asset(
                'assets/your_logo.png',
                height: 40,
                fit: BoxFit.contain,
              ),
            ),

            Spacer(), // Sağ taraftaki iconları itmek için

            // Actions manually added
            IconButton(
              icon: Icon(Icons.notifications_none, color: Colors.white),
              onPressed: () {
                // Notification action
              },
            ),
            IconButton(
              icon: Icon(Icons.message_outlined, color: Colors.white),
              onPressed: () {
                // DM action
              },
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Top 10'),
            Tab(text: 'World'),
            Tab(text: 'House'),
            Tab(text: 'Hot'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTop10Tab(),
          _buildWorldTab(),
          _buildHouseTab(),
          _buildHotTab(),
        ],
      ),
    );
  }
}