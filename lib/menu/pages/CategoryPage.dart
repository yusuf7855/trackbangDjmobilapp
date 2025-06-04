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
  // Admin playlists data
  List<Map<String, dynamic>> adminPlaylists = [];
  String? expandedPlaylistId; // Hangi playlist açık
  Map<String, List<Map<String, dynamic>>> playlistMusics = <String, List<Map<String, dynamic>>>{}; // Her playlist'in müzikleri

  bool isLoadingPlaylists = true;
  Map<String, bool> isLoadingMusics = <String, bool>{}; // Her playlist için loading durumu
  String? userId;

  // Animation controllers
  late AnimationController _loadingAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  // Preloading management - Her playlist için ayrı
  Map<String, Map<String, bool>> _musicPlayerLoadStatus = <String, Map<String, bool>>{};
  Map<String, Map<String, Widget>> _preloadedMusicPlayers = <String, Map<String, Widget>>{};
  Map<String, bool> _allMusicPlayersLoaded = <String, bool>{};
  Map<String, int> _loadedPlayerCount = <String, int>{};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeUser();
  }

  @override
  void dispose() {
    _loadingAnimationController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
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

    await _fetchAdminPlaylists();
  }

  Future<void> _fetchAdminPlaylists() async {
    try {
      final apiUrl = '${UrlConstants.apiBaseUrl}/api/playlists/category/${widget.category}';
      print('CategoryPage: Fetching admin playlists for category: ${widget.category}');
      print('CategoryPage: API URL: $apiUrl');

      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (mounted && data['success'] == true) {
          final playlists = List<Map<String, dynamic>>.from(data['playlists'] ?? []);

          setState(() {
            adminPlaylists = playlists;
            isLoadingPlaylists = false;
          });

          // Her playlist için müzik verilerini hazırla
          for (final playlist in playlists) {
            final playlistId = playlist['_id']?.toString() ?? '';
            if (playlistId.isEmpty) continue;

            final musics = List<Map<String, dynamic>>.from(playlist['musics'] ?? []);
            playlistMusics[playlistId] = musics;

            // Loading state'leri initialize et - TİP GÜVENLİ
            isLoadingMusics[playlistId] = false;
            _allMusicPlayersLoaded[playlistId] = false;
            _loadedPlayerCount[playlistId] = 0;
            _musicPlayerLoadStatus[playlistId] = <String, bool>{};
            _preloadedMusicPlayers[playlistId] = <String, Widget>{};
          }

          _loadingAnimationController.stop();
        }
      } else {
        throw Exception('Failed to load admin playlists');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingPlaylists = false;
        });
        _loadingAnimationController.stop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.title} playlist\'leri yüklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePlaylist(String playlistId) async {
    if (playlistId.isEmpty) return;

    // Eğer tıklanan playlist zaten açıksa kapat
    if (expandedPlaylistId == playlistId) {
      setState(() {
        expandedPlaylistId = null;
      });
      return;
    }

    // Başka bir playlist'i aç
    setState(() {
      expandedPlaylistId = playlistId;

      // Güvenli initialization - Map'lerde key yoksa oluştur
      if (!isLoadingMusics.containsKey(playlistId)) {
        isLoadingMusics[playlistId] = false;
      }
      if (!_allMusicPlayersLoaded.containsKey(playlistId)) {
        _allMusicPlayersLoaded[playlistId] = false;
      }
      if (!_loadedPlayerCount.containsKey(playlistId)) {
        _loadedPlayerCount[playlistId] = 0;
      }
      if (!_musicPlayerLoadStatus.containsKey(playlistId)) {
        _musicPlayerLoadStatus[playlistId] = <String, bool>{};
      }
      if (!_preloadedMusicPlayers.containsKey(playlistId)) {
        _preloadedMusicPlayers[playlistId] = <String, Widget>{};
      }

      isLoadingMusics[playlistId] = true;
    });

    // Eğer bu playlist'in müzikleri daha önce preload edilmemişse preload et
    if (!(_allMusicPlayersLoaded[playlistId] ?? false)) {
      await _preloadMusicPlayers(playlistId);
    } else {
      // Zaten preload edilmişse sadece loading'i kapat
      setState(() {
        isLoadingMusics[playlistId] = false;
      });
    }
  }

  Future<void> _preloadMusicPlayers(String playlistId) async {
    if (playlistId.isEmpty) return;

    final musics = playlistMusics[playlistId] ?? [];

    if (musics.isEmpty) {
      setState(() {
        isLoadingMusics[playlistId] = false;
        _allMusicPlayersLoaded[playlistId] = true;
      });
      return;
    }

    print('CategoryPage: Preloading ${musics.length} music players for playlist: $playlistId');

    // Initialize loading status for all tracks in this playlist
    if (!_musicPlayerLoadStatus.containsKey(playlistId)) {
      _musicPlayerLoadStatus[playlistId] = <String, bool>{};
    }
    if (!_preloadedMusicPlayers.containsKey(playlistId)) {
      _preloadedMusicPlayers[playlistId] = <String, Widget>{};
    }

    for (final track in musics) {
      final trackId = track['_id']?.toString() ?? '';
      if (trackId.isNotEmpty) {
        _musicPlayerLoadStatus[playlistId]![trackId] = false;
      }
    }

    // Create preloaded music players
    for (int i = 0; i < musics.length; i++) {
      final track = musics[i];
      final trackId = track['_id']?.toString() ?? '';

      if (trackId.isEmpty) continue;

      final musicPlayer = CommonMusicPlayer(
        key: ValueKey('category_${widget.category}_${playlistId}_${trackId}_$i'),
        track: track,
        userId: userId,
        preloadWebView: true,
        lazyLoad: false,
        webViewKey: '${playlistId}_${trackId}',
        onWebViewLoaded: (webViewKey) => _onMusicPlayerLoaded(playlistId, trackId),
        onLikeChanged: () => _refreshPlaylist(playlistId),
      );

      _preloadedMusicPlayers[playlistId]![trackId] = musicPlayer;
    }

    // Simulate realistic loading time
    await Future.delayed(Duration(seconds: 2));

    if (mounted) {
      setState(() {
        isLoadingMusics[playlistId] = false;
        _allMusicPlayersLoaded[playlistId] = true;
      });
      print('CategoryPage: All music players preloaded for playlist: $playlistId');
    }
  }

  void _onMusicPlayerLoaded(String playlistId, String trackId) {
    if (mounted &&
        _musicPlayerLoadStatus.containsKey(playlistId) &&
        _musicPlayerLoadStatus[playlistId]!.containsKey(trackId)) {

      setState(() {
        _musicPlayerLoadStatus[playlistId]![trackId] = true;
        _loadedPlayerCount[playlistId] = (_loadedPlayerCount[playlistId] ?? 0) + 1;
      });

      // Check if all players in this playlist are loaded
      final totalMusics = playlistMusics[playlistId]?.length ?? 0;
      if ((_loadedPlayerCount[playlistId] ?? 0) >= totalMusics &&
          !(_allMusicPlayersLoaded[playlistId] ?? false)) {
        setState(() {
          isLoadingMusics[playlistId] = false;
          _allMusicPlayersLoaded[playlistId] = true;
        });
      }
    }
  }

  Future<void> _refreshPlaylist(String playlistId) async {
    print('CategoryPage: Refreshing playlist: $playlistId');

    // Tüm playlist'leri yeniden fetch et ama açık olan playlist'i koru
    final wasExpanded = expandedPlaylistId == playlistId;

    await _fetchAdminPlaylists();

    // Eğer refresh edilen playlist açıktı, yeniden aç
    if (wasExpanded) {
      setState(() {
        expandedPlaylistId = playlistId;
      });
    }
  }

  Future<void> _refreshPage() async {
    print('CategoryPage: Full page refresh triggered');
    setState(() {
      expandedPlaylistId = null;
      adminPlaylists = [];
      playlistMusics.clear();
      isLoadingPlaylists = true;
      isLoadingMusics.clear();
      _musicPlayerLoadStatus.clear();
      _preloadedMusicPlayers.clear();
      _allMusicPlayersLoaded.clear();
      _loadedPlayerCount.clear();
    });

    _loadingAnimationController.repeat(reverse: true);
    await _fetchAdminPlaylists();
  }

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
            '${widget.title} Playlist\'leri Yükleniyor...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Admin playlist\'leri getiriliyor',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard(Map<String, dynamic> playlist, int index) {
    final playlistId = playlist['_id']?.toString() ?? '';
    if (playlistId.isEmpty) return SizedBox.shrink();

    final isExpanded = expandedPlaylistId == playlistId;
    final musics = playlistMusics[playlistId] ?? [];

    // Güvenli Map erişimi
    final isLoadingThisPlaylist = isLoadingMusics[playlistId] ?? false;
    final allLoaded = _allMusicPlayersLoaded[playlistId] ?? false;
    final loadedCount = _loadedPlayerCount[playlistId] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? Colors.blue.withOpacity(0.5) : Colors.grey[700]!,
          width: isExpanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded
                ? Colors.blue.withOpacity(0.2)
                : Colors.black.withOpacity(0.3),
            blurRadius: isExpanded ? 12 : 6,
            offset: Offset(0, isExpanded ? 6 : 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Playlist Header - Tıklanabilir
          InkWell(
            onTap: () => _togglePlaylist(playlistId),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // SubCategory Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange, Colors.red],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      playlist['subCategory']?.toString() ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                  SizedBox(width: 16),

                  // Playlist Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist['name']?.toString() ?? 'Unnamed Playlist',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.music_note,
                              color: Colors.grey[400],
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${playlist['musicCount'] ?? 0} tracks',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),

                          ],
                        ),
                      ],
                    ),
                  ),

                  // Expand/Collapse Icon
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: isExpanded ? Colors.blue : Colors.white70,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Music List - Sadece expanded olduğunda göster
          if (isExpanded) ...[
            Divider(color: Colors.grey[700], height: 1),
            AnimatedContainer(
              duration: Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    if (isLoadingThisPlaylist || !allLoaded) ...[
                      Container(
                        height: 120,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Spotify player\'lar hazırlanıyor...',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                              if (loadedCount > 0 && musics.isNotEmpty) ...[
                                SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: loadedCount / musics.length,
                                  backgroundColor: Colors.grey[800],
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '${loadedCount}/${musics.length} player hazır',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ] else if (musics.isEmpty) ...[
                      Container(
                        height: 80,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.music_off,
                                color: Colors.grey[600],
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Bu playlist\'te şarkı bulunamadı',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Music Players List
                      Column(
                        children: musics.asMap().entries.map((entry) {
                          final trackIndex = entry.key;
                          final track = entry.value;
                          final trackId = track['_id']?.toString() ?? '';

                          Widget musicPlayer;

                          // Güvenli preloaded player erişimi
                          if (_preloadedMusicPlayers.containsKey(playlistId) &&
                              _preloadedMusicPlayers[playlistId]!.containsKey(trackId)) {
                            musicPlayer = _preloadedMusicPlayers[playlistId]![trackId]!;
                          } else {
                            musicPlayer = CommonMusicPlayer(
                              track: track,
                              userId: userId,
                              onLikeChanged: () => _refreshPlaylist(playlistId),
                            );
                          }

                          return musicPlayer;
                        }).toList(),
                      ),
                    ],
                  ],
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshPage,
            tooltip: 'Sayfayı Yenile',
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: isLoadingPlaylists
          ? _buildLoadingAnimation()
          : adminPlaylists.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_remove,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.title} kategorisinde admin playlist bulunamadı',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshPage,
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
        onRefresh: _refreshPage,
        color: Colors.white,
        backgroundColor: Colors.black,
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          physics: AlwaysScrollableScrollPhysics(),
          itemCount: adminPlaylists.length + 1, // +1 for bottom padding
          itemBuilder: (context, index) {
            if (index == adminPlaylists.length) {
              return SizedBox(height: 100); // Bottom padding
            }

            return _buildPlaylistCard(adminPlaylists[index], index);
          },
        ),
      ),
    );
  }
}