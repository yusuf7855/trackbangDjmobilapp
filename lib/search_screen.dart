import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../url_constants.dart';
import '../common_music_player.dart';
import '../menu/pages/CategoryPage.dart';
import '../user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  // Search results için ayrı listeler
  List<Map<String, dynamic>> musicResults = [];
  List<Map<String, dynamic>> userResults = [];
  List<Map<String, dynamic>> playlistResults = [];

  bool isLoading = false;
  bool hasSearched = false;
  String? userId;

  // Tab controller için
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    _initializeUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });
  }

  Future<void> _performUnifiedSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        musicResults = [];
        userResults = [];
        playlistResults = [];
        hasSearched = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      hasSearched = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/search/all?query=${Uri.encodeComponent(query)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final results = data['results'];
          setState(() {
            musicResults = List<Map<String, dynamic>>.from(results['musics'] ?? []);
            userResults = List<Map<String, dynamic>>.from(results['users'] ?? []);
            playlistResults = List<Map<String, dynamic>>.from(results['playlists'] ?? []);
            isLoading = false;
          });
        } else {
          _showError(data['message'] ?? 'Arama başarısız');
        }
      } else {
        _showError('Sunucu hatası');
      }
    } catch (e) {
      _showError('Bağlantı hatası: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _showInPlaylist(String musicId) async {
    if (musicId.isEmpty) {
      _showError('Geçersiz müzik ID');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/music/$musicId/playlist-info'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final playlist = data['playlist'];
          final category = playlist['category'];
          final categoryTitle = playlist['categoryTitle'] ?? category;
          final playlistId = playlist['_id'];

          print('Navigating to CategoryPage with:');
          print('Category: $category');
          print('Title: $categoryTitle');
          print('AutoExpandPlaylistId: $playlistId');
          print('HighlightMusicId: $musicId');

          // CategoryPage'e yönlendir ve belirli playlist'i aç
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryPage(
                category: category,
                title: categoryTitle,
                autoExpandPlaylistId: playlistId,
                highlightMusicId: musicId,
              ),
            ),
          );
        } else {
          _showError(data['message'] ?? 'Admin playlist bilgisi bulunamadı. Bu şarkı henüz hiçbir admin playlist\'e eklenmemiş olabilir.');
        }
      } else {
        _showError('Playlist bilgisi alınamadı');
      }
    } catch (e) {
      _showError('Bağlantı hatası: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[700]!, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Şarkı, sanatçı veya kullanıcı ara...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.search, color: Colors.grey[400], size: 22),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? Container(
            padding: EdgeInsets.all(4),
            child: IconButton(
              icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  musicResults = [];
                  userResults = [];
                  playlistResults = [];
                  hasSearched = false;
                });
              },
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onChanged: (value) {
          setState(() {}); // UI güncelleme için
          if (value.trim().length >= 2) {
            // Debounce için 500ms bekle
            Future.delayed(Duration(milliseconds: 500), () {
              if (_searchController.text == value && value.trim().length >= 2) {
                _performUnifiedSearch(value);
              }
            });
          } else if (value.trim().isEmpty) {
            setState(() {
              musicResults = [];
              userResults = [];
              playlistResults = [];
              hasSearched = false;
            });
          }
        },
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            _performUnifiedSearch(value);
          }
        },
      ),
    );
  }

  Widget _buildResultTabs() {
    if (!hasSearched || isLoading) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!, width: 0.5),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[400],
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400, fontSize: 11),
        labelPadding: EdgeInsets.symmetric(horizontal: 4),
        tabs: [
          Tab(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 12),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Şarkılar (${musicResults.length})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Tab(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 12),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Kullanıcılar (${userResults.length})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Tab(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.playlist_play, size: 12),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Playlistler (${playlistResults.length})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicResults() {
    if (musicResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.music_off,
        title: 'Şarkı Bulunamadı',
        subtitle: 'Farklı bir arama terimi deneyin',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: 32),
      itemCount: musicResults.length,
      itemBuilder: (context, index) {
        return _buildMusicItem(musicResults[index]);
      },
    );
  }

  Widget _buildUserResults() {
    if (userResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_off,
        title: 'Kullanıcı Bulunamadı',
        subtitle: 'Farklı bir kullanıcı adı deneyin',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: 32),
      itemCount: userResults.length,
      itemBuilder: (context, index) {
        return _buildUserItem(userResults[index]);
      },
    );
  }

  Widget _buildPlaylistResults() {
    if (playlistResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.playlist_remove,
        title: 'Playlist Bulunamadı',
        subtitle: 'Farklı bir playlist adı deneyin',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: 32),
      itemCount: playlistResults.length,
      itemBuilder: (context, index) {
        return _buildPlaylistItem(playlistResults[index]);
      },
    );
  }

  Widget _buildMusicItem(Map<String, dynamic> music) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 0.5),
      ),
      child: Container(
        height: 120, // Daha kompakt yükseklik
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CommonMusicPlayer(
            track: music,
            userId: userId,
            preloadWebView: true,
            lazyLoad: false,
            webViewKey: 'search_${music['_id']}',
            // Arama sayfasına özel playlist butonu
            showPlaylistButton: true,
            playlistButtonText: 'Playliste Git',
            onPlaylistButtonPressed: () => _showInPlaylist(music['_id']),
          ),
        ),
      ),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 0.5),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey[700],
          backgroundImage: user['profileImage'] != null
              ? NetworkImage('${UrlConstants.apiBaseUrl}/${user['profileImage']}')
              : null,
          child: user['profileImage'] == null
              ? Icon(Icons.person, color: Colors.white, size: 28)
              : null,
        ),
        title: Text(
          '@${user['username'] ?? 'kullanici'}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim().isEmpty
                  ? 'İsim belirtilmemiş'
                  : '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            if (user['bio'] != null && user['bio'].toString().isNotEmpty) ...[
              SizedBox(height: 6),
              Text(
                user['bio'],
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.people, color: Colors.grey[500], size: 14),
                SizedBox(width: 4),
                Text(
                  '${user['followerCount'] ?? 0} takipçi',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                SizedBox(width: 16),
                Icon(Icons.person_add, color: Colors.grey[500], size: 14),
                SizedBox(width: 4),
                Text(
                  '${user['followingCount'] ?? 0} takip',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 18),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(
                    userId: user['_id'],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistItem(Map<String, dynamic> playlist) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 0.5),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
          ),
          child: Icon(
            playlist['isAdminPlaylist'] == true
                ? Icons.admin_panel_settings
                : Icons.playlist_play,
            color: Colors.blue,
            size: 28,
          ),
        ),
        title: Text(
          playlist['name'] ?? 'İsimsiz Playlist',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            if (playlist['description'] != null && playlist['description'].toString().isNotEmpty) ...[
              Text(
                playlist['description'],
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6),
            ],
            Row(
              children: [
                Icon(Icons.music_note, color: Colors.grey[500], size: 14),
                SizedBox(width: 4),
                Text(
                  '${playlist['musicCount'] ?? 0} şarkı',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                if (playlist['owner'] != null) ...[
                  SizedBox(width: 16),
                  Icon(Icons.person, color: Colors.grey[500], size: 14),
                  SizedBox(width: 4),
                  Text(
                    playlist['owner']['username'] ?? 'Anonim',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 18),
            onPressed: () {
              // Playlist'e tıklanınca kategoriye göre yönlendir
              if (playlist['category'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryPage(
                      category: playlist['category'],
                      title: playlist['categoryTitle'] ?? playlist['category'],
                      autoExpandPlaylistId: playlist['_id'],
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    if (!hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: Colors.grey[600],
            ),
            SizedBox(height: 20),
            Text(
              'Arama Yap',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Şarkı, sanatçı veya kullanıcı arayın',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'En az 2 karakter girmeniz yeterli',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[600],
          ),
          SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
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
      body: Column(
        children: [
          // Üst boşluk (status bar için) - azaltıldı
          SizedBox(height: MediaQuery.of(context).padding.top + 5),

          // Arama Çubuğu
          _buildSearchBar(),

          // Tab Bar (sadece arama yapıldıktan sonra göster)
          if (hasSearched && !isLoading) ...[
            SizedBox(height: 5),
            _buildResultTabs(),
            SizedBox(height: 5),
          ],

          // Sonuçlar veya Loading
          Expanded(
            child: isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Aranıyor...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : hasSearched
                ? TabBarView(
              controller: _tabController,
              children: [
                _buildMusicResults(),
                _buildUserResults(),
                _buildPlaylistResults(),
              ],
            )
                : _buildEmptyState(
              icon: Icons.search,
              title: 'Arama Yap',
              subtitle: 'Şarkı, sanatçı veya kullanıcı arayın',
            ),
          ),
        ],
      ),
    );
  }
}