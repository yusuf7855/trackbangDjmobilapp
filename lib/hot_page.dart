import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './url_constants.dart';
import './common_music_player.dart';

class HotPage extends StatefulWidget {
  final String? userId;

  const HotPage({Key? key, this.userId}) : super(key: key);

  @override
  _HotPageState createState() => _HotPageState();
}

class _HotPageState extends State<HotPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> hotCategories = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Preloading management
  final Map<String, List<Widget>> _preloadedMusicPlayers = {};
  final Map<String, bool> _categoryPreloadStatus = {};
  final Map<String, bool> _expandedStates = {};
  bool _allCategoriesPreloaded = false;

  // Cache için preloaded widgets
  final Map<String, Widget> _preloadedWidgets = {};

  // Loading animation
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Tüm kategorileri başlangıçta açık yap
    _expandedStates['afrohouse'] = true;
    _expandedStates['indiedance'] = true;
    _expandedStates['organichouse'] = true;
    _expandedStates['downtempo'] = true;
    _expandedStates['melodichouse'] = true;

    _loadHotCategories();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadHotCategories() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    _animationController.repeat();

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/hot/'),
        headers: {
          'Content-Type': 'application/json',
          'Connection': 'keep-alive',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final categories = responseData['hotPlaylists'] as List<dynamic>? ?? [];

          await _preprocessAndPreloadCategories(categories);

          setState(() {
            hotCategories = categories;
          });

          await _waitForPreloadingComplete();
        }
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading hot categories: $e');
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

    // Tüm şarkıları topla
    List<Map<String, dynamic>> allTracks = [];
    for (final category in categories) {
      final genre = category['genre']?.toString();
      if (genre == null) continue;

      _expandedStates[genre] = true; // Başlangıçta açık
      _categoryPreloadStatus[genre] = false;

      final musics = category['musics'] as List<dynamic>? ?? [];
      if (musics.isEmpty) {
        _preloadedMusicPlayers[genre] = [];
        _categoryPreloadStatus[genre] = true;
        continue;
      }

      // Tüm şarkıları listeye ekle
      for (final music in musics) {
        allTracks.add({
          'music': music,
          'genre': genre,
        });
      }
    }

    print('Hot Page: Total tracks to preload: ${allTracks.length}');

    // Önce widget'ları oluştur (hızlı)
    for (final category in categories) {
      final genre = category['genre']?.toString();
      if (genre == null) continue;

      final musics = category['musics'] as List<dynamic>? ?? [];
      final List<Widget> musicPlayers = [];

      for (final music in musics) {
        final key = 'hot_${genre}_${music['_id'] ?? music['spotifyId']}';

        // Cache'de varsa kullan
        if (_preloadedWidgets.containsKey(key)) {
          musicPlayers.add(_preloadedWidgets[key]!);
        } else {
          final musicPlayer = CommonMusicPlayer(
            key: ValueKey(key),
            track: music,
            userId: widget.userId,
            preloadWebView: true, // Preload aktif
            lazyLoad: false, // Lazy load kapalı
            onLikeChanged: () {
              _loadHotCategories();
            },
          );
          _preloadedWidgets[key] = musicPlayer; // Cache'e ekle
          musicPlayers.add(musicPlayer);
        }
      }

      _preloadedMusicPlayers[genre] = musicPlayers;
      _categoryPreloadStatus[genre] = true;
    }

    // Arka planda gerçek preload'ı yap (yavaş)
    _preloadAllTracks(allTracks);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _preloadAllTracks(List<Map<String, dynamic>> allTracks) async {
    print('Hot Page: Starting preload of ${allTracks.length} tracks...');

    // Daha küçük batch'ler halinde yükle (performans için)
    const int batchSize = 2;
    int loadedCount = 0;

    for (int i = 0; i < allTracks.length; i += batchSize) {
      final batch = allTracks.skip(i).take(batchSize);

      final batchFutures = batch.map((trackData) =>
          _preloadSingleTrack(trackData['music'], trackData['genre'])
              .then((_) {
            loadedCount++;
            print('✓ Preloaded $loadedCount/${allTracks.length}: ${trackData['music']['title']}');
          }).catchError((e) {
            loadedCount++;
            print('✗ Failed $loadedCount/${allTracks.length}: ${trackData['music']['title']} - $e');
          })
      ).toList();

      // Bu batch'in tamamlanmasını bekle
      await Future.wait(batchFutures);

      // Batch'ler arası bekleme
      if (i + batchSize < allTracks.length) {
        await Future.delayed(Duration(milliseconds: 300));
      }
    }

    print('🎉 All Hot Page tracks preloaded successfully! Total: $loadedCount');
  }

  Future<void> _preloadSingleTrack(Map<String, dynamic> music, String genre) async {
    try {
      // Gerçek WebView preloading - CommonMusicPlayer widget oluştur ve initialize et
      final musicPlayer = CommonMusicPlayer(
        key: ValueKey('preload_hot_${genre}_${music['_id'] ?? music['spotifyId']}'),
        track: music,
        userId: widget.userId,
        preloadWebView: true, // Gerçek preload
        lazyLoad: false, // Hemen yükle
        onLikeChanged: () {},
      );

      // Widget'ı memory'de oluştur ama ekranda gösterme
      await Future.delayed(Duration(milliseconds: 200)); // WebView init süresi

      return;
    } catch (e) {
      print('Error preloading track: ${music['title']} - $e');
      return;
    }
  }

  Future<void> _waitForPreloadingComplete() async {
    print('Hot Page: Waiting for initial setup to complete...');
    // Sadece widget'ların hazırlanmasını bekle, preload arka planda devam edecek
    await Future.delayed(Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        isLoading = false;
        _allCategoriesPreloaded = true;
      });
      _animationController.stop();
      print('Hot Page: Interface ready, preloading continues in background!');
    }
  }

  String _formatGenreDisplay(String genre) {
    switch (genre.toLowerCase()) {
      case 'afrohouse':
        return 'Afro House Hot Playlist';
      case 'indiedance':
        return 'Indie Dance Hot Playlist';
      case 'organichouse':
        return 'Organic House Hot Playlist';
      case 'downtempo':
        return 'Down Tempo Hot Playlist';
      case 'melodichouse':
        return 'Melodic House Hot Playlist';
      default:
        return genre;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Column(
        children: [
          // Content
          Expanded(
            child: isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: RotationTransition(
                      turns: _animationController,
                      child: Icon(
                        Icons.refresh,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading Hot Tracks...',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Preparing all songs for instant playback',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
                : hasError
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Color(0xFF2A1A1A),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 30,
                      color: Colors.red[300],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadHotCategories,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Try Again'),
                  ),
                ],
              ),
            )
                : hotCategories.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(
                      Icons.playlist_remove,
                      size: 30,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'No hot playlists',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Check back later for trending content',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadHotCategories,
              backgroundColor: Color(0xFF1A1A1A),
              color: Colors.white,
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: hotCategories.length,
                itemBuilder: (context, index) {
                  final category = hotCategories[index];
                  final genre = category['genre']?.toString() ?? '';
                  final musicPlayers = _preloadedMusicPlayers[genre] ?? [];

                  return Container(
                    margin: EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sadece başlık
                        Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 12),
                          child: Text(
                            '# ${_formatGenreDisplay(genre)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        // Sadece şarkılar
                        if (musicPlayers.isNotEmpty)
                          ...musicPlayers,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}