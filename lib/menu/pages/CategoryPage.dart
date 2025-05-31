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
  Map<String, dynamic>? selectedPlaylist;
  List<Map<String, dynamic>> selectedPlaylistMusics = [];

  bool isLoadingPlaylists = true;
  bool isLoadingMusics = false;
  bool isExpanded = false;
  String? userId;

  // Animation controllers
  late AnimationController _loadingAnimationController;
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
    _initializeAnimations();
    _initializeUser();
  }

  @override
  void dispose() {
    _loadingAnimationController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    // Loading animation
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

          // Auto-select first playlist if available
          if (playlists.isNotEmpty) {
            await _selectPlaylist(playlists.first);
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

  Future<void> _selectPlaylist(Map<String, dynamic> playlist) async {
    setState(() {
      selectedPlaylist = playlist;
      isLoadingMusics = true;
      selectedPlaylistMusics = [];
      _musicPlayerLoadStatus.clear();
      _preloadedMusicPlayers.clear();
      _loadedPlayerCount = 0;
      _allMusicPlayersLoaded = false;
      isExpanded = true;
    });

    _loadingAnimationController.repeat(reverse: true);

    // Extract musics from selected playlist
    final musics = List<Map<String, dynamic>>.from(playlist['musics'] ?? []);

    setState(() {
      selectedPlaylistMusics = musics;
    });

    if (musics.isNotEmpty) {
      await _preloadMusicPlayers(musics);
    } else {
      setState(() {
        isLoadingMusics = false;
        _allMusicPlayersLoaded = true;
      });
      _loadingAnimationController.stop();
    }
  }

  Future<void> _preloadMusicPlayers(List<Map<String, dynamic>> musics) async {
    print('CategoryPage: Preloading ${musics.length} music players for playlist: ${selectedPlaylist?['name']}');

    // Initialize loading status for all tracks
    for (final track in musics) {
      final trackId = track['_id']?.toString() ?? '';
      _musicPlayerLoadStatus[trackId] = false;
    }

    // Create preloaded music players
    for (int i = 0; i < musics.length; i++) {
      final track = musics[i];
      final trackId = track['_id']?.toString() ?? '';

      final musicPlayer = CommonMusicPlayer(
        key: ValueKey('category_${widget.category}_${selectedPlaylist?['_id']}_${trackId}_$i'),
        track: track,
        userId: userId,
        preloadWebView: true,
        lazyLoad: false,
        webViewKey: trackId,
        onWebViewLoaded: _onMusicPlayerLoaded,
        onLikeChanged: _refreshSelectedPlaylist,
      );

      _preloadedMusicPlayers[trackId] = musicPlayer;
    }

    // Simulate realistic loading time
    await Future.delayed(Duration(seconds: 2));

    if (mounted) {
      setState(() {
        isLoadingMusics = false;
        _allMusicPlayersLoaded = true;
      });
      _loadingAnimationController.stop();
      print('CategoryPage: All music players preloaded for playlist: ${selectedPlaylist?['name']}');
    }
  }

  void _onMusicPlayerLoaded(String trackId) {
    if (mounted && _musicPlayerLoadStatus.containsKey(trackId)) {
      setState(() {
        _musicPlayerLoadStatus[trackId] = true;
        _loadedPlayerCount++;
      });

      // Check if all players are loaded
      if (_loadedPlayerCount >= selectedPlaylistMusics.length && !_allMusicPlayersLoaded) {
        setState(() {
          isLoadingMusics = false;
          _allMusicPlayersLoaded = true;
        });
        _loadingAnimationController.stop();
      }
    }
  }

  void _refreshSelectedPlaylist() {
    if (selectedPlaylist != null) {
      _selectPlaylist(selectedPlaylist!);
    }
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
            isLoadingPlaylists
                ? '${widget.title} Playlist\'leri Yükleniyor...'
                : 'Şarkılar Hazırlanıyor...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 20),
          Text(
            isLoadingPlaylists
                ? 'Admin playlist\'leri getiriliyor'
                : 'Spotify player\'lar hazırlanıyor',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          if (!isLoadingPlaylists && _loadedPlayerCount > 0 && selectedPlaylistMusics.isNotEmpty) ...[
            SizedBox(height: 30),
            LinearProgressIndicator(
              value: _loadedPlayerCount / selectedPlaylistMusics.length,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 12),
            Text(
              '${_loadedPlayerCount}/${selectedPlaylistMusics.length} şarkı hazır',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaylistContainer() {
    if (adminPlaylists.isEmpty) return SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
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
      child: Column(
        children: [
          // Dropdown Header
          InkWell(
            onTap: () {
              _showPlaylistDropdown();
            },
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: isExpanded ? Radius.zero : Radius.circular(16),
              bottomRight: isExpanded ? Radius.zero : Radius.circular(16),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  if (selectedPlaylist != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange, Colors.red],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        selectedPlaylist!['subCategory']?.toString() ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectedPlaylist!['name']?.toString() ?? 'Unnamed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          SizedBox(height: 2),
                          Text(
                            '${selectedPlaylist!['musicCount'] ?? 0} tracks',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: Text(
                        'Playlist Seçin',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
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

          // Music List (with simple show/hide instead of complex animation)
          if (selectedPlaylist != null && isExpanded) ...[
            Divider(color: Colors.grey[700], height: 1),
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  if (isLoadingMusics || !_allMusicPlayersLoaded) ...[
                    Container(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Şarkılar yükleniyor...',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                            if (_loadedPlayerCount > 0 && selectedPlaylistMusics.isNotEmpty) ...[
                              SizedBox(height: 12),
                              Text(
                                '${_loadedPlayerCount}/${selectedPlaylistMusics.length} hazır',
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
                  ] else if (selectedPlaylistMusics.isEmpty) ...[
                    Container(
                      height: 100,
                      child: Center(
                        child: Text(
                          'Bu playlist\'te şarkı bulunamadı',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    ...selectedPlaylistMusics.asMap().entries.map((entry) {
                      final index = entry.key;
                      final track = entry.value;
                      final trackId = track['_id']?.toString() ?? '';

                      Widget musicPlayer;
                      if (_preloadedMusicPlayers.containsKey(trackId)) {
                        musicPlayer = _preloadedMusicPlayers[trackId]!;
                      } else {
                        musicPlayer = CommonMusicPlayer(
                          track: track,
                          userId: userId,
                          onLikeChanged: _refreshSelectedPlaylist,
                        );
                      }

                      return Container(
                        margin: EdgeInsets.only(bottom: index < selectedPlaylistMusics.length - 1 ? 16 : 0),
                        child: musicPlayer,
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showPlaylistDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Playlist Seçin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Container(
              constraints: BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: adminPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = adminPlaylists[index];
                  final subCategory = playlist['subCategory']?.toString() ?? '';
                  final name = playlist['name']?.toString() ?? 'Unnamed';
                  final musicCount = playlist['musicCount'] ?? 0;
                  final isSelected = selectedPlaylist?['_id'] == playlist['_id'];

                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: Colors.blue, width: 1) : null,
                    ),
                    child: ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        _selectPlaylist(playlist);
                      },
                      leading: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange, Colors.red],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          subCategory,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '$musicCount tracks',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: Colors.blue)
                          : Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
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
              onPressed: _fetchAdminPlaylists,
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
          await _fetchAdminPlaylists();
        },
        color: Colors.white,
        backgroundColor: Colors.black,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildPlaylistContainer(),
              SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}