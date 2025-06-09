import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import './url_constants.dart';
import './user_profile.dart';
import './common_music_player.dart';

class SearchScreen extends StatefulWidget {
  final String? userId;

  const SearchScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _musicResults = [];
  List<Map<String, dynamic>> _playlistResults = [];
  List<Map<String, dynamic>> _userResults = [];

  bool _isLoading = false;
  bool _hasSearched = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Çoklu sanatçı desteği için helper method
  String _getDisplayArtists(Map<String, dynamic> music) {
    // 1. displayArtists varsa onu kullan (backend'den gelen hazır format)
    if (music['displayArtists'] != null &&
        music['displayArtists'].toString().isNotEmpty) {
      return music['displayArtists'].toString();
    }

    // 2. artists array varsa onu birleştir
    if (music['artists'] != null &&
        music['artists'] is List &&
        (music['artists'] as List).isNotEmpty) {
      final artistsList = music['artists'] as List;
      return artistsList
          .where((artist) => artist != null && artist.toString().trim().isNotEmpty)
          .map((artist) => artist.toString().trim())
          .join(', ');
    }

    // 3. Eski tek sanatçı field'i varsa onu kullan (backward compatibility)
    if (music['artist'] != null &&
        music['artist'].toString().trim().isNotEmpty) {
      return music['artist'].toString().trim();
    }

    // 4. Hiçbiri yoksa default
    return 'Unknown Artist';
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _musicResults.clear();
        _playlistResults.clear();
        _userResults.clear();
        _hasSearched = false;
        _currentQuery = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _currentQuery = query;
    });

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/search?query=${Uri.encodeComponent(query)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && mounted) {
          final results = data['results'] as List<dynamic>? ?? [];

          setState(() {
            _searchResults = List<Map<String, dynamic>>.from(results);

            // Sonuçları türlerine göre ayır
            _musicResults = _searchResults
                .where((item) => item['type'] == 'music')
                .toList();
            _playlistResults = _searchResults
                .where((item) => item['type'] == 'playlist')
                .toList();
            _userResults = _searchResults
                .where((item) => item['type'] == 'user')
                .toList();

            _isLoading = false;
          });
        } else {
          _handleSearchError('Arama sonucu bulunamadı');
        }
      } else {
        _handleSearchError('Arama sırasında hata oluştu');
      }
    } catch (e) {
      _handleSearchError('Bağlantı hatası: $e');
    }
  }

  void _handleSearchError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _searchResults.clear();
        _musicResults.clear();
        _playlistResults.clear();
        _userResults.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError('URL açılamıyor: $url');
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

  Widget _buildAllResults() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      );
    }

    if (!_hasSearched) {
      return _buildEmptyState();
    }

    if (_searchResults.isEmpty) {
      return _buildNoResultsState();
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        if (_musicResults.isNotEmpty) ...[
          _buildSectionHeader('Şarkılar', _musicResults.length),
          SizedBox(height: 8),
          ..._musicResults.take(3).map((music) => _buildMusicTile(music)),
          if (_musicResults.length > 3) ...[
            SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: Text(
                  '${_musicResults.length - 3} şarkı daha göster',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ),
          ],
          SizedBox(height: 24),
        ],

        if (_playlistResults.isNotEmpty) ...[
          _buildSectionHeader('Playlistler', _playlistResults.length),
          SizedBox(height: 8),
          ..._playlistResults.take(3).map((playlist) => _buildPlaylistTile(playlist)),
          if (_playlistResults.length > 3) ...[
            SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _tabController.animateTo(2),
                child: Text(
                  '${_playlistResults.length - 3} playlist daha göster',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ),
          ],
          SizedBox(height: 24),
        ],

        if (_userResults.isNotEmpty) ...[
          _buildSectionHeader('Kullanıcılar', _userResults.length),
          SizedBox(height: 8),
          ..._userResults.take(3).map((user) => _buildUserTile(user)),
          if (_userResults.length > 3) ...[
            SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _tabController.animateTo(3),
                child: Text(
                  '${_userResults.length - 3} kullanıcı daha göster',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMusicResults() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      );
    }

    if (_musicResults.isEmpty) {
      return _buildNoResultsState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _musicResults.length,
      itemBuilder: (context, index) {
        return CommonMusicPlayer(
          track: _musicResults[index],
          userId: widget.userId,
          lazyLoad: true,
        );
      },
    );
  }

  Widget _buildPlaylistResults() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      );
    }

    if (_playlistResults.isEmpty) {
      return _buildNoResultsState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _playlistResults.length,
      itemBuilder: (context, index) {
        return _buildPlaylistTile(_playlistResults[index]);
      },
    );
  }

  Widget _buildUserResults() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      );
    }

    if (_userResults.isEmpty) {
      return _buildNoResultsState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        return _buildUserTile(_userResults[index]);
      },
    );
  }

  Widget _buildPlaylistTile(Map<String, dynamic> playlist) {
    final isPrivate = playlist['isPublic'] != true;
    final musicCount = playlist['musicCount'] ?? 0;

    return Card(
      color: Colors.grey[900],
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isPrivate ? Icons.lock : Icons.queue_music,
            color: isPrivate ? Colors.grey[600] : Colors.blue,
            size: 24,
          ),
        ),
        title: Text(
          playlist['name'] ?? 'Unnamed Playlist',
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
                style: TextStyle(color: Colors.grey[400]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                Text(
                  '$musicCount şarkı',
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
    final displayArtists = _getDisplayArtists(music);

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

  Widget _buildUserTile(Map<String, dynamic> user) {
    return Card(
      color: Colors.grey[900],
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[700],
          backgroundImage: user['profileImage'] != null && user['profileImage'] != 'image.jpg'
              ? NetworkImage('${UrlConstants.apiBaseUrl}/uploads/profile/${user['profileImage']}')
              : null,
          child: user['profileImage'] == null || user['profileImage'] == 'image.jpg'
              ? Icon(Icons.person, color: Colors.white, size: 24)
              : null,
        ),
        title: Text(
          user['username'] ?? 'Unknown User',
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
            Row(
              children: [
                Icon(Icons.people, color: Colors.grey[500], size: 12),
                SizedBox(width: 4),
                Text(
                  '${user['followerCount'] ?? 0} takipçi',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/user_profile',
            arguments: {
              'userId': user['_id'],
              'currentUserId': widget.userId,
            },
          );
        },
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
                            title ?? 'Unknown Title',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            artists ?? 'Unknown Artist',
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                            maxLines: 2, // Çoklu sanatçı için 2 satır
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
                  child: WebViewWidget(
                    controller: WebViewController()
                      ..setJavaScriptMode(JavaScriptMode.unrestricted)
                      ..loadRequest(Uri.parse('https://open.spotify.com/embed/track/$spotifyId?utm_source=generator&theme=0')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPlaylistDetail(Map<String, dynamic> playlist) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          child: Container(
            height: 600,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        playlist['name'] ?? 'Unnamed Playlist',
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
                if (playlist['description'] != null && playlist['description'].isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    playlist['description'],
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '${playlist['musicCount'] ?? 0} şarkı',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    if (playlist['genre'] != null) ...[
                      Text(' • ', style: TextStyle(color: Colors.grey[400])),
                      Text(
                        playlist['genre'],
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: (playlist['previewMusics'] as List?)?.length ?? 0,
                    itemBuilder: (context, index) {
                      final music = playlist['previewMusics'][index];
                      final displayArtists = _getDisplayArtists(music);

                      return ListTile(
                        leading: Icon(Icons.music_note, color: Colors.orange),
                        title: Text(
                          music['title'] ?? 'Unknown Title',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          displayArtists,
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            color: Colors.grey[600],
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Şarkı, playlist veya kullanıcı arayın',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Arama yapmak için yukarıdaki kutuya yazın',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            color: Colors.grey[600],
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Sonuç bulunamadı',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '"$_currentQuery" için hiçbir sonuç bulunamadı',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Şarkı, playlist veya kullanıcı ara...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[500]),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange, width: 2),
                ),
              ),
              onChanged: (value) {
                if (value.trim().isEmpty) {
                  _performSearch('');
                }
              },
              onSubmitted: _performSearch,
            ),
          ),

          // Tab Bar
          if (_hasSearched) ...[
            Container(
              color: Colors.grey[900],
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Tümü (${_searchResults.length})'),
                  Tab(text: 'Şarkılar (${_musicResults.length})'),
                  Tab(text: 'Playlistler (${_playlistResults.length})'),
                  Tab(text: 'Kullanıcılar (${_userResults.length})'),
                ],
                labelColor: Colors.orange,
                unselectedLabelColor: Colors.grey[400],
                indicatorColor: Colors.orange,
                labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                unselectedLabelStyle: TextStyle(fontSize: 12),
              ),
            ),
          ],

          // Content
          Expanded(
            child: _hasSearched
                ? TabBarView(
              controller: _tabController,
              children: [
                _buildAllResults(),
                _buildMusicResults(),
                _buildPlaylistResults(),
                _buildUserResults(),
              ],
            )
                : _buildEmptyState(),
          ),
        ],
      ),
    );
  }
}