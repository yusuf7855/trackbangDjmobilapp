import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'user_profile.dart';
import './url_constants.dart';
import './common_music_player.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  // Controllers ve değişkenler
  TextEditingController searchController = TextEditingController();
  Timer? _debounce;
  bool isLoading = false;
  String? authToken;

  // Tab controller
  late TabController _tabController;

  // Arama sonuçları
  Map<String, dynamic> searchResults = {
    'users': [],
    'playlists': [],
    'musics': [],
    'privatePlaylists': []
  };

  // Tab index'leri
  final Map<String, int> tabIndexes = {
    'all': 0,
    'users': 1,
    'playlists': 2,
    'musics': 3,
    'my_playlists': 4
  };

  // WebView controllers for Spotify embeds
  Map<String, WebViewController> _webViewControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    searchController.addListener(_onSearchChanged);
    _loadAuthToken();
  }

  @override
  void dispose() {
    searchController.dispose();
    _debounce?.cancel();
    _tabController.dispose();
    _disposeWebViews();
    super.dispose();
  }

  void _disposeWebViews() {
    _webViewControllers.clear();
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString('auth_token');
    });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = searchController.text.trim();

      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          searchResults = {
            'users': [],
            'playlists': [],
            'musics': [],
            'privatePlaylists': []
          };
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Ana arama (users, playlists, musics)
      final mainSearchFuture = _searchAll(query);

      // Private playlist arama (sadece giriş yapmış kullanıcılar için)
      final privateSearchFuture = authToken != null
          ? _searchPrivatePlaylists(query)
          : Future.value(<dynamic>[]);

      final results = await Future.wait([mainSearchFuture, privateSearchFuture]);

      setState(() {
        final mainResults = results[0] as Map<String, dynamic>;
        searchResults['users'] = mainResults['users'] ?? [];
        searchResults['playlists'] = mainResults['playlists'] ?? [];
        searchResults['musics'] = mainResults['musics'] ?? [];
        searchResults['privatePlaylists'] = results[1];
        isLoading = false;
      });

    } catch (e) {
      print("Arama hatası: $e");
      setState(() {
        isLoading = false;
      });
      _showError('Arama sırasında bir hata oluştu: $e');
    }
  }

  Future<Map<String, dynamic>> _searchAll(String query) async {
    final url = '${UrlConstants.apiBaseUrl}/api/search/all?query=${Uri.encodeComponent(query)}';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'] ?? {};
    } else {
      throw Exception('Ana arama başarısız: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> _searchPrivatePlaylists(String query) async {
    if (authToken == null) return [];

    final url = '${UrlConstants.apiBaseUrl}/api/search/my-playlists?query=${Uri.encodeComponent(query)}';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results']['privatePlaylists'] ?? [];
    } else {
      print('Private playlist arama hatası: ${response.statusCode}');
      return [];
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getProfileImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty || imagePath == 'image.jpg') {
      return '';
    }
    return '${UrlConstants.apiBaseUrl}$imagePath';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Container(
          height: 40,
          child: TextField(
            controller: searchController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Kullanıcı, playlist veya şarkı ara...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey[400]),
                onPressed: () {
                  searchController.clear();
                  setState(() {
                    searchResults = {
                      'users': [],
                      'playlists': [],
                      'musics': [],
                      'privatePlaylists': []
                    };
                  });
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'Tümü'),
            Tab(text: 'Kullanıcılar'),
            Tab(text: 'Playlistler'),
            Tab(text: 'Şarkılar'),
            if (authToken != null) Tab(text: 'Listelerim'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllResultsTab(),
          _buildUsersTab(),
          _buildPlaylistsTab(),
          _buildMusicsTab(),
          if (authToken != null) _buildPrivatePlaylistsTab(),
        ],
      ),
    );
  }

  Widget _buildAllResultsTab() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (searchController.text.isEmpty) {
      return _buildEmptyState('Aramaya başlamak için yukarıya yazın');
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kullanıcılar bölümü
          if (searchResults['users'].isNotEmpty) ...[
            _buildSectionHeader('Kullanıcılar', () {
              _tabController.animateTo(1);
            }),
            SizedBox(height: 8),
            ...searchResults['users'].take(3).map((user) => _buildUserTile(user)),
            SizedBox(height: 20),
          ],

          // Playlistler bölümü
          if (searchResults['playlists'].isNotEmpty) ...[
            _buildSectionHeader('Playlistler', () {
              _tabController.animateTo(2);
            }),
            SizedBox(height: 8),
            ...searchResults['playlists'].take(3).map((playlist) => _buildPlaylistTile(playlist)),
            SizedBox(height: 20),
          ],

          // Şarkılar bölümü
          if (searchResults['musics'].isNotEmpty) ...[
            _buildSectionHeader('Şarkılar', () {
              _tabController.animateTo(3);
            }),
            SizedBox(height: 8),
            ...searchResults['musics'].take(3).map((music) => _buildMusicTile(music)),
          ],

          // Sonuç bulunamadı
          if (searchResults['users'].isEmpty &&
              searchResults['playlists'].isEmpty &&
              searchResults['musics'].isEmpty)
            _buildEmptyState('Arama sonucu bulunamadı'),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (searchResults['users'].isEmpty) {
      return _buildEmptyState(searchController.text.isEmpty
          ? 'Kullanıcı aramak için yukarıya yazın'
          : 'Kullanıcı bulunamadı');
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: searchResults['users'].length,
      itemBuilder: (context, index) {
        return _buildUserTile(searchResults['users'][index]);
      },
    );
  }

  Widget _buildPlaylistsTab() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (searchResults['playlists'].isEmpty) {
      return _buildEmptyState(searchController.text.isEmpty
          ? 'Playlist aramak için yukarıya yazın'
          : 'Playlist bulunamadı');
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: searchResults['playlists'].length,
      itemBuilder: (context, index) {
        return _buildPlaylistTile(searchResults['playlists'][index]);
      },
    );
  }

  Widget _buildMusicsTab() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (searchResults['musics'].isEmpty) {
      return _buildEmptyState(searchController.text.isEmpty
          ? 'Şarkı aramak için yukarıya yazın'
          : 'Şarkı bulunamadı');
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: searchResults['musics'].length,
      itemBuilder: (context, index) {
        return _buildMusicTile(searchResults['musics'][index]);
      },
    );
  }

  Widget _buildPrivatePlaylistsTab() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (searchResults['privatePlaylists'].isEmpty) {
      return _buildEmptyState(searchController.text.isEmpty
          ? 'Kendi listelerinizde arama yapmak için yukarıya yazın'
          : 'Listelerinizde sonuç bulunamadı');
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: searchResults['privatePlaylists'].length,
      itemBuilder: (context, index) {
        return _buildPlaylistTile(searchResults['privatePlaylists'][index]);
      },
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          child: Text(
            'Tümünü Gör',
            style: TextStyle(color: Colors.orange),
          ),
        ),
      ],
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    return Card(
      color: Colors.grey[900],
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user['profileImage'] != null
              ? NetworkImage(_getProfileImageUrl(user['profileImage']))
              : AssetImage('assets/default_profile.png') as ImageProvider,
          radius: 25,
          backgroundColor: Colors.grey[700],
        ),
        title: Text(
          user['username'] ?? '',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user['firstName'] != null || user['lastName'] != null)
              Text(
                '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
                style: TextStyle(color: Colors.grey[400]),
              ),
            if (user['bio'] != null && user['bio'].isNotEmpty)
              Text(
                user['bio'],
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${user['followerCount'] ?? 0}',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              'takipçi',
              style: TextStyle(color: Colors.grey[400], fontSize: 10),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(userId: user['_id']),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistTile(Map<String, dynamic> playlist) {
    final isPrivate = playlist['type'] == 'private_playlist';

    return Card(
      color: Colors.grey[900],
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isPrivate ? Icons.lock : Icons.library_music,
            color: Colors.orange,
            size: 24,
          ),
        ),
        title: Text(
          playlist['name'] ?? '',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (playlist['description'] != null && playlist['description'].isNotEmpty)
              Text(
                playlist['description'],
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                Text(
                  '${playlist['musicCount'] ?? 0} şarkı',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                if (playlist['genre'] != null) ...[
                  Text(' • ', style: TextStyle(color: Colors.grey[500])),
                  Text(
                    playlist['genre'],
                    style: TextStyle(color: Colors.orange, fontSize: 11),
                  ),
                ],
                if (!isPrivate && playlist['owner'] != null) ...[
                  Text(' • ', style: TextStyle(color: Colors.grey[500])),
                  Text(
                    playlist['owner']['username'] ?? '',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: isPrivate
            ? Icon(Icons.lock, color: Colors.grey[600], size: 16)
            : Icon(Icons.play_arrow, color: Colors.white),
        onTap: () {
          _showPlaylistDetail(playlist);
        },
      ),
    );
  }

  Widget _buildMusicTile(Map<String, dynamic> music) {
    // Sanatçı adlarını göster - yeni sistem varsa onu kullan
    String displayArtists = '';
    if (music['displayArtists'] != null) {
      displayArtists = music['displayArtists'];
    } else if (music['artists'] != null && music['artists'] is List && music['artists'].isNotEmpty) {
      displayArtists = (music['artists'] as List).join(', ');
    } else if (music['artist'] != null && music['artist'].isNotEmpty) {
      displayArtists = music['artist'];
    } else {
      displayArtists = 'Unknown Artist';
    }

    return Card(
      color: Colors.grey[900],
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.music_note,
            color: Colors.orange,
            size: 24,
          ),
        ),
        title: Text(
          music['title'] ?? '',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayArtists,
              style: TextStyle(color: Colors.grey[400]),
              maxLines: 2, // Çoklu sanatçı için 2 satır
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                if (music['category'] != null) ...[
                  Text(
                    music['category'],
                    style: TextStyle(color: Colors.orange, fontSize: 11),
                  ),
                  Text(' • ', style: TextStyle(color: Colors.grey[500])),
                ],
                Icon(Icons.favorite, color: Colors.red, size: 12),
                SizedBox(width: 4),
                Text(
                  '${music['likeCount'] ?? music['likes'] ?? 0}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spotify embed için play butonu
            IconButton(
              icon: Icon(Icons.play_arrow, color: Colors.white),
              onPressed: () {
                _showSpotifyPlayer(music['spotifyId'], music['title'], displayArtists);
              },
            ),
            if (music['beatportUrl'] != null && music['beatportUrl'].isNotEmpty)
              IconButton(
                icon: Icon(Icons.shopping_cart, color: Colors.orange, size: 20),
                onPressed: () {
                  _launchURL(music['beatportUrl']);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSpotifyPlayer(String? spotifyId, String? title, String? artists) {
    if (spotifyId == null || spotifyId.isEmpty) {
      _showError('Spotify ID bulunamadı');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          child: Container(
            height: 450,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title ?? 'Spotify Player',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (artists != null && artists.isNotEmpty)
                            Text(
                              artists,
                              style: TextStyle(color: Colors.grey[400], fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildSpotifyEmbed(spotifyId),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _launchURL('https://open.spotify.com/track/$spotifyId'),
                      icon: Icon(Icons.open_in_new, color: Colors.white),
                      label: Text('Spotify\'da Aç', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpotifyEmbed(String spotifyId) {
    final webViewKey = 'spotify_$spotifyId';

    if (!_webViewControllers.containsKey(webViewKey)) {
      _webViewControllers[webViewKey] = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadRequest(Uri.parse('https://open.spotify.com/embed/track/$spotifyId?utm_source=generator&theme=0'));
    }

    return WebViewWidget(controller: _webViewControllers[webViewKey]!);
  }

  void _showPlaylistDetail(Map<String, dynamic> playlist) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          child: Container(
            height: 400,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        playlist['name'] ?? 'Playlist',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                if (playlist['description'] != null && playlist['description'].isNotEmpty)
                  Text(
                    playlist['description'],
                    style: TextStyle(color: Colors.grey[400]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.music_note, color: Colors.orange, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '${playlist['musicCount'] ?? 0} şarkı',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    if (playlist['genre'] != null) ...[
                      SizedBox(width: 16),
                      Icon(Icons.category, color: Colors.orange, size: 16),
                      SizedBox(width: 4),
                      Text(
                        playlist['genre'],
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: Text(
                      'Playlist detayları burada gösterilecek',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchURL(String url) async {
    try {
      String formattedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        formattedUrl = 'https://$url';
      }

      final Uri uri = Uri.parse(formattedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError("Link açılamadı");
      }
    } catch (e) {
      _showError("Geçersiz link: $e");
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[600],
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          if (searchController.text.isEmpty) ...[
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.orange, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Arama İpuçları:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Sanatçı adı: "David Guetta"\n• Şarkı adı: "Titanium"\n• Kullanıcı adı: "@username"\n• Playlist adı: "Chill House"',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}