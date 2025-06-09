import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../url_constants.dart';
import '../../common_music_player.dart';

class CategoryPage extends StatefulWidget {
  final String category;
  final String title;
  final String? autoExpandPlaylistId; // Otomatik açılacak playlist ID'si
  final String? highlightMusicId; // Vurgulanacak müzik ID'si

  const CategoryPage({
    Key? key,
    required this.category,
    required this.title,
    this.autoExpandPlaylistId,
    this.highlightMusicId,
  }) : super(key: key);

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

  // Scroll controller for auto-scrolling
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _playlistKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeUser();
  }

  @override
  void dispose() {
    _loadingAnimationController.dispose();
    _scrollController.dispose();
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

            // GlobalKey oluştur
            _playlistKeys[playlistId] = GlobalKey();

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

          // Otomatik playlist açma ve scroll
          if (widget.autoExpandPlaylistId != null) {
            await _autoExpandAndScroll();
          }
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

  Future<void> _autoExpandAndScroll() async {
    if (widget.autoExpandPlaylistId == null) return;

    // Biraz bekle ki widget'lar tam oluşsun
    await Future.delayed(Duration(milliseconds: 500));

    // Playlist'i aç
    await _togglePlaylist(widget.autoExpandPlaylistId!);

    // Scroll işlemi için biraz daha bekle
    await Future.delayed(Duration(milliseconds: 1000));

    // Playlist'in konumuna scroll et
    if (_playlistKeys.containsKey(widget.autoExpandPlaylistId)) {
      final context = _playlistKeys[widget.autoExpandPlaylistId]!.currentContext;
      if (context != null) {
        await Scrollable.ensureVisible(
          context,
          duration: Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          alignment: 0.1, // Üstten %10'luk kısımda konumlandır
        );

        // Eğer vurgulanacak müzik varsa, onu da vurgula
        if (widget.highlightMusicId != null) {
          _highlightMusic(widget.highlightMusicId!);
        }
      }
    }
  }

  void _highlightMusic(String musicId) {
    // Müziği vurgulamak için basit bir SnackBar göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aradığınız şarkı bu playlist\'te bulunuyor!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Tamam',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
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
      _playlistKeys.clear();
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
    final playlistName = playlist['name'] ?? 'Bilinmeyen Playlist';
    final musicCount = (playlist['musics'] as List?)?.length ?? 0;
    final isExpanded = expandedPlaylistId == playlistId;
    final isLoading = isLoadingMusics[playlistId] ?? false;
    final musics = playlistMusics[playlistId] ?? [];

    return Container(
      key: _playlistKeys[playlistId],
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Playlist Header
          InkWell(
            onTap: () => _togglePlaylist(playlistId),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(16),
              bottom: isExpanded ? Radius.zero : Radius.circular(16),
            ),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isExpanded ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16),
                  bottom: isExpanded ? Radius.zero : Radius.circular(16),
                ),
                border: isExpanded ? Border.all(color: Colors.blue.withOpacity(0.3), width: 1) : null,
              ),
              child: Row(
                children: [
                  // Playlist Icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Icon(
                      Icons.queue_music,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),

                  // Playlist Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlistName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$musicCount şarkı',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        if (playlist['subCategory'] != null) ...[
                          SizedBox(height: 2),
                          Text(
                            'Katalog: ${playlist['subCategory']}',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Expand Icon
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: isExpanded ? null : 0,
            child: isExpanded ? Container(
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  if (isLoading) ...[
                    Container(
                      height: 120,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Müzik player\'ları yükleniyor...',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                            if (_loadedPlayerCount.containsKey(playlistId) && musics.isNotEmpty) ...[
                              SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: (_loadedPlayerCount[playlistId] ?? 0) / musics.length,
                                backgroundColor: Colors.grey[800],
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${_loadedPlayerCount[playlistId] ?? 0}/${musics.length} player hazır',
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
                          // Fallback player
                          musicPlayer = CommonMusicPlayer(
                            key: ValueKey('fallback_${playlistId}_${trackId}_$trackIndex'),
                            track: track,
                            userId: userId,
                            preloadWebView: false,
                            lazyLoad: true,
                            webViewKey: 'fallback_${playlistId}_${trackId}',
                            onLikeChanged: () => _refreshPlaylist(playlistId),
                          );
                        }

                        // Highlighted music styling
                        final isHighlighted = widget.highlightMusicId == trackId;

                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isHighlighted ? Colors.green.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isHighlighted ? Border.all(color: Colors.green, width: 2) : null,
                          ),
                          child: musicPlayer,
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 12),
                  ],
                ],
              ),
            ) : null,
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
        title: Text(
          widget.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: 28,
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshPage,
          ),
        ],
      ),
      body: isLoadingPlaylists
          ? _buildLoadingAnimation()
          : adminPlaylists.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_remove,
              size: 80,
              color: Colors.grey[600],
            ),
            SizedBox(height: 20),
            Text(
              'Playlist Bulunamadı',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '${widget.title} kategorisinde playlist yok',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshPage,
              icon: Icon(Icons.refresh),
              label: Text('Yenile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshPage,
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(top: 16, bottom: 32),
          itemCount: adminPlaylists.length,
          itemBuilder: (context, index) {
            return _buildPlaylistCard(adminPlaylists[index], index);
          },
        ),
      ),
    );
  }
}