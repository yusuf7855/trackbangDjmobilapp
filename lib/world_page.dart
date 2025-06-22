import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './url_constants.dart';
import './common_music_player.dart';

class WorldPage extends StatefulWidget {
  final String? userId;

  const WorldPage({Key? key, this.userId}) : super(key: key);

  @override
  _WorldPageState createState() => _WorldPageState();
}

class _WorldPageState extends State<WorldPage> with TickerProviderStateMixin {
  List<dynamic> worldPlaylists = [];
  List<dynamic> filteredPlaylists = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Filtreleme ve sıralama değişkenleri - Tamamen güncellenmiş
  String selectedGenre = 'Genre Filter';
  String sortOrder = 'Newest First';

  // Sadece belirtilen genre'lar ve düzgün görünen isimler
  final List<Map<String, String>> genres = [
    {'display': 'Genre Filter', 'value': 'all'},
    {'display': 'Afro House', 'value': 'afrohouse'},
    {'display': 'Indie Dance', 'value': 'indiedance'},
    {'display': 'Organic House', 'value': 'organichouse'},
    {'display': 'Down Tempo', 'value': 'downtempo'},
    {'display': 'Melodic House', 'value': 'melodichouse'},
  ];

  // Preloading için değişkenler
  late AnimationController _animationController;
  Map<String, bool> _expandedStates = {};
  Map<String, List<Widget>> _preloadedMusicPlayers = {};
  Map<String, bool> _playlistPreloadStatus = {};
  bool _allPlaylistsPreloaded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _loadWorldPlaylists();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWorldPlaylists() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    _animationController.repeat();

    try {
      // Query parametrelerini oluştur
      String queryParams = 'page=1&limit=50';

      // Genre filtresi varsa ekle
      if (selectedGenre != 'Genre Filter') {
        String apiGenre = genres.firstWhere((g) => g['display'] == selectedGenre)['value'] ?? 'all';
        if (apiGenre != 'all') {
          queryParams += '&genre=$apiGenre';
        }
      }

      // Sıralama parametrelerini ekle
      queryParams += '&sortBy=createdAt';
      queryParams += '&sortOrder=${sortOrder == 'Newest First' ? 'desc' : 'asc'}';

      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/public-world?$queryParams'),
        headers: {'Content-Type': 'application/json'},
      );

      print('API Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('API Response Body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      } else {
        print('API Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Parsed response data: ${responseData['success']}');
        if (responseData['playlists'] != null && responseData['playlists'].isNotEmpty) {
          print('First playlist owner: ${responseData['playlists'][0]['owner']}');
        }
        if (responseData['success'] == true) {
          final playlists = responseData['playlists'] as List<dynamic>? ?? [];

          await _preprocessAndPreloadPlaylists(playlists);

          setState(() {
            worldPlaylists = playlists;
            filteredPlaylists = playlists;
          });

          await _waitForPreloadingComplete();
        }
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading playlists: $e');
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

  Future<void> _preprocessAndPreloadPlaylists(List<dynamic> playlists) async {
    print('World Page: Preprocessing ${playlists.length} playlists');

    for (final playlist in playlists) {
      final playlistId = playlist['_id']?.toString();
      if (playlistId == null) continue;

      _expandedStates[playlistId] = false;
      _playlistPreloadStatus[playlistId] = false;

      final musics = playlist['musics'] as List<dynamic>? ?? [];
      if (musics.isEmpty) {
        _preloadedMusicPlayers[playlistId] = [];
        _playlistPreloadStatus[playlistId] = true;
        continue;
      }

      final List<Widget> musicPlayers = [];

      for (final music in musics) {
        final musicPlayer = CommonMusicPlayer(
          key: ValueKey('world_${playlistId}_${music['_id'] ?? music['spotifyId']}'),
          track: music,
          userId: widget.userId,
          preloadWebView: true,
          lazyLoad: false,
          onLikeChanged: () {
            _loadWorldPlaylists();
          },
        );
        musicPlayers.add(musicPlayer);
      }

      _preloadedMusicPlayers[playlistId] = musicPlayers;
      _playlistPreloadStatus[playlistId] = true;

      print('World Page: Preloaded ${musics.length} tracks for playlist: ${playlist['name']}');
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _waitForPreloadingComplete() async {
    print('World Page: Waiting for preloading to complete...');
    await Future.delayed(Duration(seconds: 2));

    if (mounted) {
      setState(() {
        isLoading = false;
        _allPlaylistsPreloaded = true;
      });
      _animationController.stop();
      print('World Page: All playlists preloaded!');
    }
  }

  void _togglePlaylistExpansion(String playlistId) {
    setState(() {
      _expandedStates[playlistId] = !(_expandedStates[playlistId] ?? false);
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return '';
    }
  }

  String _formatGenreDisplay(String genre) {
    switch (genre.toLowerCase()) {
      case 'afrohouse':
        return 'AFRO HOUSE';
      case 'indiedance':
        return 'INDIE DANCE';
      case 'organichouse':
        return 'ORGANIC HOUSE';
      case 'downtempo':
        return 'DOWN TEMPO';
      case 'melodichouse':
        return 'MELODIC HOUSE';
      default:
        return genre.toUpperCase();
    }
  }

  Widget _buildProfileImage(Map<String, dynamic>? owner) {
    if (owner == null) {
      return Container(
        color: Color(0xFF2A2A2A),
        child: Icon(
          Icons.person,
          color: Colors.grey[600],
          size: 24,
        ),
      );
    }

    String? profileImagePath = owner['profileImage'];

    // Profil resmi URL'ini oluştur
    String? imageUrl;
    if (profileImagePath != null && profileImagePath.isNotEmpty && profileImagePath != 'image.jpg') {
      // Eğer URL zaten tam ise olduğu gibi kullan
      if (profileImagePath.startsWith('http')) {
        imageUrl = profileImagePath;
      }
      // Eğer /uploads/ ile başlıyorsa base URL ekle
      else if (profileImagePath.startsWith('/uploads/')) {
        imageUrl = '${UrlConstants.apiBaseUrl}$profileImagePath';
      }
      // Eğer sadece dosya adı ise /uploads/ ekle
      else {
        imageUrl = '${UrlConstants.apiBaseUrl}/uploads/$profileImagePath';
      }
    }

    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Profile image load error: $error');
          print('Attempted URL: $imageUrl');
          return Container(
            color: Color(0xFF2A2A2A),
            child: Icon(
              Icons.person,
              color: Colors.grey[600],
              size: 24,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Color(0xFF2A2A2A),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                ),
              ),
            ),
          );
        },
      );
    }

    // Varsayılan profil resmi
    return Container(
      color: Color(0xFF2A2A2A),
      child: Icon(
        Icons.person,
        color: Colors.grey[600],
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Column(
        children: [
          // Compact Header with Small Dropdowns
          Container(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFF0A0A0A),
            ),
            child: Row(
              children: [
                // Genre Filter Dropdown - Small
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF111111),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Color(0xFF222222), width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGenre,
                        isExpanded: true,
                        dropdownColor: Color(0xFF111111),
                        isDense: true,
                        style: TextStyle(
                          color: selectedGenre == 'Genre Filter' ? Colors.grey[400] : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        icon: Icon(
                          Icons.expand_more,
                          color: Colors.grey[400],
                          size: 17,
                        ),
                        items: genres.map((genre) {
                          return DropdownMenuItem<String>(
                            value: genre['display']!,
                            child: Text(
                              genre['display']!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: genre['display'] == 'Genre Filter'
                                    ? Colors.grey[400]
                                    : Colors.white,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedGenre = newValue;
                              _loadWorldPlaylists();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 10),

                // Sort Dropdown - Small
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF111111),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Color(0xFF222222), width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: sortOrder,
                        isExpanded: true,
                        dropdownColor: Color(0xFF111111),
                        isDense: true,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        icon: Icon(
                          Icons.expand_more,
                          color: Colors.grey[400],
                          size: 17,
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: 'Newest First',
                            child: Text(
                              'Newest First',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Oldest First',
                            child: Text(
                              'Oldest First',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              sortOrder = newValue;
                              _loadWorldPlaylists();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                    'Loading...',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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
                    onPressed: _loadWorldPlaylists,
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
                : filteredPlaylists.isEmpty
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
                    'No playlists found',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    selectedGenre != 'Genre Filter'
                        ? 'No playlists in $selectedGenre category'
                        : 'No shared playlists yet',
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
              onRefresh: _loadWorldPlaylists,
              backgroundColor: Color(0xFF1A1A1A),
              color: Colors.white,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: filteredPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = filteredPlaylists[index];
                  final playlistId = playlist['_id']?.toString() ?? '';
                  final isExpanded = _expandedStates[playlistId] ?? false;
                  final musicPlayers = _preloadedMusicPlayers[playlistId] ?? [];

                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Color(0xFF151515),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color(0xFF2A2A2A), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Playlist Header
                        InkWell(
                          onTap: () => _togglePlaylistExpansion(playlistId),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Color(0xFF333333), width: 1),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: _buildProfileImage(playlist['owner']),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            playlist['name'] ?? 'Untitled Playlist',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                playlist['owner']?['displayName'] ?? 'Unknown',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[400],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                ' • ${_formatDate(playlist['createdAt'])}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF2A2A2A),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: Colors.grey[400],
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF2A2A2A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Color(0xFF404040), width: 1),
                                      ),
                                      child: Text(
                                        _formatGenreDisplay(playlist['genre']?.toString() ?? 'GENRE'),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[300],
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '${playlist['musicCount'] ?? 0} tracks',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (playlist['description']?.isNotEmpty == true) ...[
                                  SizedBox(height: 10),
                                  Text(
                                    playlist['description'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[300],
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Expanded Music List
                        if (isExpanded && musicPlayers.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              color: Color(0xFF0F0F0F),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              border: Border(
                                top: BorderSide(color: Color(0xFF2A2A2A), width: 1),
                              ),
                            ),
                            child: Column(
                              children: musicPlayers,
                            ),
                          ),
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