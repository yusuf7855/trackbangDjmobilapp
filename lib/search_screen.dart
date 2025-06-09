import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../url_constants.dart';
import '../common_music_player.dart';
import '../menu/pages/CategoryPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = false;
  bool hasSearched = false;
  String? userId;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });
  }

  Future<void> _searchMusicByArtist(String artist) async {
    if (artist.trim().isEmpty) {
      setState(() {
        searchResults = [];
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
        Uri.parse('${UrlConstants.apiBaseUrl}/api/music/search-by-artist?artist=${Uri.encodeComponent(artist)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            searchResults = List<Map<String, dynamic>>.from(data['musics'] ?? []);
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

          // CategoryPage'e yönlendir ve belirli playlist'i aç
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryPage(
                category: category,
                title: categoryTitle,
                autoExpandPlaylistId: playlistId, // Otomatik açılacak playlist ID'si
                highlightMusicId: musicId, // Vurgulanacak müzik ID'si
              ),
            ),
          );
        } else {
          _showError(data['message'] ?? 'Playlist bilgisi bulunamadı');
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
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Sanatçı adı girin...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey[400]),
            onPressed: () {
              _searchController.clear();
              setState(() {
                searchResults = [];
                hasSearched = false;
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {}); // UI güncelleme için
          if (value.trim().length >= 2) {
            // Debounce için 500ms bekle
            Future.delayed(Duration(milliseconds: 500), () {
              if (_searchController.text == value && value.trim().length >= 2) {
                _searchMusicByArtist(value);
              }
            });
          } else if (value.trim().isEmpty) {
            setState(() {
              searchResults = [];
              hasSearched = false;
            });
          }
        },
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            _searchMusicByArtist(value);
          }
        },
      ),
    );
  }

  Widget _buildResultItem(Map<String, dynamic> music) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Spotify Embed Bölümü
          Container(
            height: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: CommonMusicPlayer(
                track: music,
                userId: userId,
                preloadWebView: false,
                lazyLoad: true,
                webViewKey: 'search_${music['_id']}',
              ),
            ),
          ),
          // Bilgi ve Aksiyon Bölümü
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Müzik Bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        music['title'] ?? 'Unknown Track',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        music['displayArtists'] ?? music['artist'] ?? 'Unknown Artist',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          if (music['category'] != null) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.orange, width: 0.5),
                              ),
                              child: Text(
                                music['category'],
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
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
                ),
                // Playlist'te Göster Butonu
                Container(
                  margin: EdgeInsets.only(left: 12),
                  child: ElevatedButton.icon(
                    onPressed: () => _showInPlaylist(music['_id']),
                    icon: Icon(Icons.playlist_play, size: 16),
                    label: Text(
                      'Playlist\'te Göster',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (!hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 80,
              color: Colors.grey[600],
            ),
            SizedBox(height: 20),
            Text(
              'Sanatçı Arama',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Aradığınız sanatçının adını girin',
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
            Icons.search_off,
            size: 80,
            color: Colors.grey[600],
          ),
          SizedBox(height: 20),
          Text(
            'Sonuç Bulunamadı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Bu sanatçıya ait şarkı bulunamadı',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Farklı bir arama terimi deneyin',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
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
        title: Text(
          'Sanatçı Arama',
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
      ),
      body: Column(
        children: [
          // Arama Çubuğu
          _buildSearchBar(),

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
                : searchResults.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: EdgeInsets.only(bottom: 20),
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                return _buildResultItem(searchResults[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}