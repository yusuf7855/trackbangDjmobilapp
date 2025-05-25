import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../url_constants.dart';

class CategoryPage extends StatefulWidget {
  final String category;
  final String title;

  const CategoryPage({Key? key, required this.category, required this.title}) : super(key: key);

  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<Map<String, dynamic>> musicList = [];
  List<Map<String, dynamic>> userPlaylists = [];
  bool isLoading = true;
  String? userId;
  final Map<String, WebViewController> _webViewCache = {};
  final TextEditingController _newPlaylistController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _fetchCategoryMusic();
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });
    if (userId != null) {
      _fetchUserPlaylists();
    }
  }

  Future<void> _fetchCategoryMusic() async {
    try {
      final response = await http.get(Uri.parse('${UrlConstants.apiBaseUrl}/api/music'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          musicList = data
              .where((item) => item['category'].toLowerCase() == widget.category.toLowerCase())
              .map((item) => ({
            'id': item['spotifyId'],
            'title': item['title'],
            'likes': item['likes'] ?? 0,
            '_id': item['_id'],
            'userLikes': item['userLikes'] ?? [],
            'beatportUrl': item['beatportUrl'] ?? '',
          }))
              .toList();
          isLoading = false;
          _preloadWebViews();
        });
      } else {
        throw Exception('Failed to load music');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.title} müzikleri yüklenirken hata: $e')),
      );
    }
  }

  Future<void> _fetchUserPlaylists() async {
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['playlists'];
          setState(() {
            userPlaylists = data.map((item) => {
              '_id': item['_id'],
              'name': item['name'],
              'description': item['description'] ?? '',
              'musicCount': item['musicCount'] ?? 0,
            }).toList();
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Çalma listeleri yüklenirken hata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _preloadWebViews() {
    for (final track in musicList) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadRequest(Uri.parse(
          'https://open.spotify.com/embed/track/${track['id']}?utm_source=generator&theme=0',
        ));

      _webViewCache[track['id']] = controller;
    }
  }

  Future<void> _toggleLike(String musicId) async {
    if (userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/music/$musicId/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        _fetchCategoryMusic();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beğeni işlemi sırasında hata: $e')),
      );
    }
  }

  Future<void> _addToExistingPlaylist(String musicId, String playlistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/music/$musicId/add-to-playlist'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'playlistId': playlistId,
          'userId': userId,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Çalma listesine başarıyla eklendi'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Çalma listesine eklenirken hata'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createNewPlaylist(String musicId) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çalma listesi oluşturmak için giriş yapın')),
      );
      return;
    }

    if (_newPlaylistController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çalma listesi adı girin')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    try {
      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': _newPlaylistController.text,
          'musicId': musicId,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Çalma listesi oluşturuldu')),
        );
        _newPlaylistController.clear();
        await _fetchUserPlaylists();
        Navigator.of(context).pop();
      } else {
        final error = json.decode(response.body)['message'] ?? 'Çalma listesi oluşturulamadı';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString()}')),
      );
    }
  }

  void _showAddToPlaylistDialog(String musicId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Çalma Listesine Ekle",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    if (userPlaylists.isNotEmpty) ...[
                      Text(
                        "Çalma Listeleriniz",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        constraints: BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: userPlaylists.length,
                          itemBuilder: (context, index) {
                            final playlist = userPlaylists[index];
                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              leading: Icon(Icons.playlist_play, color: Colors.white),
                              title: Text(
                                playlist['name'],
                                style: TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                "${playlist['musicCount']} şarkı",
                                style: TextStyle(color: Colors.white70),
                              ),
                              trailing: Icon(Icons.add, color: Colors.green),
                              onTap: () {
                                _addToExistingPlaylist(musicId, playlist['_id']);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      Divider(color: Colors.grey[700]),
                      SizedBox(height: 8),
                    ],
                    Text(
                      "Yeni Çalma Listesi Oluştur",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _newPlaylistController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[800],
                        hintText: 'Çalma listesi adı girin',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'İptal',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => _createNewPlaylist(musicId),
                          child: Text('Oluştur ve Ekle'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isLikedByUser(Map<String, dynamic> track) {
    return track['userLikes']?.contains(userId) ?? false;
  }

  Future<void> _launchBeatportUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      } else {
        throw 'Bağlantı açılamadı: $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
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
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : musicList.isEmpty
          ? Center(
        child: Text(
          '${widget.title} kategorisinde şarkı bulunamadı',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      )
          : ListView.separated(
        padding: EdgeInsets.all(16),
        physics: BouncingScrollPhysics(),
        itemCount: musicList.length,
        separatorBuilder: (_, __) => SizedBox(height: 16),
        itemBuilder: (context, index) {
          final track = musicList[index];
          return _buildMusicCard(track);
        },
      ),
    );
  }

  Widget _buildMusicCard(Map<String, dynamic> track) {
    final controller = _webViewCache[track['id']];

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: WebViewWidget(controller: controller!),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isLikedByUser(track) ? Icons.favorite : Icons.favorite_border,
                        color: _isLikedByUser(track) ? Colors.red : Colors.white,
                        size: 24,
                      ),
                      onPressed: () => _toggleLike(track['_id']),
                    ),
                    Text(
                      '${track['likes']}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.playlist_add, color: Colors.white, size: 24),
                      onPressed: () => _showAddToPlaylistDialog(track['_id']),
                    ),
                    if (track['beatportUrl']?.isNotEmpty == true)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        icon: Image.asset(
                          'assets/beatport_logo.png',
                          width: 24,
                          height: 24,
                        ),
                        label: Text('Buy on Beatport'),
                        onPressed: () => _launchBeatportUrl(track['beatportUrl']),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _webViewCache.clear();
    _newPlaylistController.dispose();
    super.dispose();
  }
}