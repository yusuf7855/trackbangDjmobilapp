import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import './url_constants.dart';
import 'create_playlist.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? userId;

  // Data for different tabs
  Map<String, List<dynamic>> top10Data = {};
  List<dynamic> worldPlaylists = [];
  List<dynamic> housePlaylists = [];
  List<dynamic> hotPlaylists = [];
  List<dynamic> userPlaylists = [];

  // Loading states
  bool isLoadingTop10 = true;
  bool isLoadingWorld = true;
  bool isLoadingHouse = true;
  bool isLoadingHot = true;

  // WebView cache
  final Map<String, WebViewController> _webViewCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _webViewCache.clear();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });

    // Load all data
    _loadTop10Data();
    _loadWorldPlaylists();
    _loadHousePlaylists();
    _loadHotPlaylists();
    if (userId != null) {
      _loadUserPlaylists();
    }
  }

  Future<void> _loadUserPlaylists() async {
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted && data['success'] == true) {
          setState(() {
            userPlaylists = data['playlists'] ?? [];
          });
        }
      }
    } catch (e) {
      print('Error loading user playlists: $e');
    }
  }

  Future<void> _loadTop10Data() async {
    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/music/top10'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            top10Data = Map<String, List<dynamic>>.from(data['top10']);
            isLoadingTop10 = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingTop10 = false;
        });
      }
    }
  }

  Future<void> _loadWorldPlaylists() async {
    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/public-world'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            worldPlaylists = data['playlists'] ?? [];
            isLoadingWorld = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingWorld = false;
        });
      }
    }
  }

  Future<void> _loadHousePlaylists() async {
    if (userId == null) {
      setState(() {
        isLoadingHouse = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/following/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            housePlaylists = data['playlists'] ?? [];
            isLoadingHouse = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingHouse = false;
        });
      }
    }
  }

  Future<void> _loadHotPlaylists() async {
    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/hot?isActive=true'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            hotPlaylists = data['hots'] ?? [];
            isLoadingHot = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingHot = false;
        });
      }
    }
  }

  // Rank icon widget with medal colors
  Widget _buildRankIcon(int rank) {
    Color color;
    IconData icon;

    switch (rank) {
      case 1:
        color = Colors.amber; // Gold
        icon = Icons.emoji_events;
        break;
      case 2:
        color = Colors.grey.shade400; // Silver
        icon = Icons.emoji_events;
        break;
      case 3:
        color = Colors.brown.shade400; // Bronze
        icon = Icons.emoji_events;
        break;
      default:
        color = Colors.white;
        icon = Icons.music_note;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: rank <= 3 ? color : Colors.grey[800],
        shape: BoxShape.circle,
        border: Border.all(
          color: rank <= 3 ? Colors.white : Colors.grey[600]!,
          width: 2,
        ),
        boxShadow: rank <= 3
            ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: rank <= 3
          ? Icon(icon, color: Colors.white, size: 20)
          : Center(
        child: Text(
          rank.toString(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTop10Tab() {
    if (isLoadingTop10) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = [
      {'key': 'all', 'title': 'Overall Top 10'},
      {'key': 'afrohouse', 'title': 'Afro House'},
      {'key': 'indiedance', 'title': 'Indie Dance'},
      {'key': 'organichouse', 'title': 'Organic House'},
      {'key': 'downtempo', 'title': 'Down Tempo'},
      {'key': 'melodichouse', 'title': 'Melodic House'},
    ];

    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final category = categories[index];
              final tracks = top10Data[category['key']] ?? [];
              return _buildCategorySection(category['title']!, tracks);
            },
            childCount: categories.length,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(String title, List<dynamic> tracks) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...tracks.asMap().entries.map((entry) {
            final index = entry.key;
            final track = entry.value;
            return MusicCard(
              track: track,
              rank: index + 1,
              onLike: _toggleLike,
              onAddToPlaylist: _showAddToPlaylistDialog,
              key: ValueKey(track['_id']),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSpotifyEmbed(String? spotifyId) {
    if (spotifyId == null) return Container();

    if (!_webViewCache.containsKey(spotifyId)) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadRequest(Uri.parse(
          'https://open.spotify.com/embed/track/$spotifyId?utm_source=generator&theme=0',
        ));

      _webViewCache[spotifyId] = controller;
    }

    return SizedBox(
      height: 80,
      child: WebViewWidget(
        controller: _webViewCache[spotifyId]!,
        gestureRecognizers: Set()
          ..add(Factory<VerticalDragGestureRecognizer>(
                () => VerticalDragGestureRecognizer(),
          )),
      ),
    );
  }

  // Helper methods for music interactions
  Future<void> _toggleLike(String musicId) async {
    if (userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/music/$musicId/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        _loadTop10Data(); // Refresh data
      }
    } catch (e) {
      print('Error liking track: $e');
    }
  }

  bool _isLikedByUser(Map<String, dynamic> track) {
    return track['userLikes']?.contains(userId) ?? false;
  }

  Future<void> _launchBeatportUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  void _showAddToPlaylistDialog(String musicId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add to Playlist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (userPlaylists.isNotEmpty) ...[
              Container(
                constraints: BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: userPlaylists.length,
                  itemBuilder: (context, index) {
                    final playlist = userPlaylists[index];
                    return ListTile(
                      leading: Icon(Icons.playlist_play, color: Colors.white),
                      title: Text(
                        playlist['name'],
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "${playlist['musicCount']} songs",
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      onTap: () {
                        _addToExistingPlaylist(musicId, playlist['_id']);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              Divider(color: Colors.grey[700]),
            ],
            ListTile(
              leading: Icon(Icons.add, color: Colors.white),
              title: Text(
                'Create New Playlist',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _navigateToCreatePlaylist(musicId);
              },
            ),
          ],
        ),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(responseData['message'] ?? 'Added to playlist'),
          backgroundColor: response.statusCode == 200 ? Colors.green : Colors.red,
        ),
      );

      if (response.statusCode == 200) {
        _loadUserPlaylists(); // Refresh playlists
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _navigateToCreatePlaylist(String musicId) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePlaylistPage(initialMusicId: musicId),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playlist created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadUserPlaylists(); // Refresh playlists
    }
  }

  Widget _buildWorldTab() {
    if (isLoadingWorld) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final playlist = worldPlaylists[index];
              return _buildPlaylistCard(playlist);
            },
            childCount: worldPlaylists.length,
          ),
        ),
      ],
    );
  }

  Widget _buildHouseTab() {
    if (isLoadingHouse) {
      return const Center(child: CircularProgressIndicator());
    }

    if (housePlaylists.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No playlists from following users',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Follow users to see their playlists here',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final playlist = housePlaylists[index];
              return _buildPlaylistCard(playlist);
            },
            childCount: housePlaylists.length,
          ),
        ),
      ],
    );
  }

  Widget _buildHotTab() {
    if (isLoadingHot) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final hotPlaylist = hotPlaylists[index];
              return _buildHotPlaylistCard(hotPlaylist);
            },
            childCount: hotPlaylists.length,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistCard(Map<String, dynamic> playlist) {
    final musics = playlist['musics'] as List<dynamic>? ?? [];
    final owner = playlist['owner'] as Map<String, dynamic>?;

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          playlist['name'] ?? 'Unnamed Playlist',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (owner != null)
              Text(
                'by ${owner['displayName'] ?? owner['username']}',
                style: const TextStyle(color: Colors.grey),
              ),
            Text(
              '${playlist['musicCount'] ?? 0} songs • ${playlist['genre'] ?? 'Unknown'}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        children: [
          if (musics.isNotEmpty)
            Container(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: musics.length > 4 ? 4 : musics.length,
                itemBuilder: (context, index) {
                  final music = musics[index];
                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: 8),
                    child: _buildSpotifyEmbed(music['spotifyId']),
                  );
                },
              ),
            ),
          if (musics.length > 4)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '+${musics.length - 4} more songs',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHotPlaylistCard(Map<String, dynamic> hotPlaylist) {
    final musics = hotPlaylist['musics'] as List<dynamic>? ?? [];

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.whatshot, color: Colors.orange),
        title: Text(
          hotPlaylist['name'] ?? 'Unnamed HOT Playlist',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${hotPlaylist['musicCount'] ?? 0} songs • ${hotPlaylist['category'] ?? 'All Categories'}',
          style: const TextStyle(color: Colors.grey),
        ),
        children: [
          if (musics.isNotEmpty)
            Container(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: musics.length > 4 ? 4 : musics.length,
                itemBuilder: (context, index) {
                  final music = musics[index];
                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: 8),
                    child: _buildSpotifyEmbed(music['spotifyId']),
                  );
                },
              ),
            ),
          if (musics.length > 4)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '+${musics.length - 4} more songs',
                style: const TextStyle(color: Colors.grey),
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
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  Image.asset(
                    'assets/your_logo.png',
                    height: 40,
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_none, color: Colors.white),
                    onPressed: () {
                      // Notification action
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.message_outlined, color: Colors.white),
                    onPressed: () {
                      // DM action
                    },
                  ),
                ],
              ),
            ]),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Top 10'),
            Tab(text: 'World'),
            Tab(text: 'House'),
            Tab(text: 'Hot'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTop10Tab(),
          _buildWorldTab(),
          _buildHouseTab(),
          _buildHotTab(),
        ],
      ),
    );
  }
}

class MusicCard extends StatefulWidget {
  final Map<String, dynamic> track;
  final int rank;
  final Function(String) onLike;
  final Function(String) onAddToPlaylist;

  const MusicCard({
    required this.track,
    required this.rank,
    required this.onLike,
    required this.onAddToPlaylist,
    Key? key
  }) : super(key: key);

  @override
  _MusicCardState createState() => _MusicCardState();
}

class _MusicCardState extends State<MusicCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Column(
        children: [
          // Spotify Embed
          SizedBox(
            height: 80,
            child: _buildSpotifyEmbed(widget.track['spotifyId']),
          ),
          // Controls and Info
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Rank Icon
                _buildRankIcon(widget.rank),
                const SizedBox(width: 12),

                // Track Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.track['title'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.track['artist'] ?? 'Unknown Artist',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Like Button
                    GestureDetector(
                      onTap: () => widget.onLike(widget.track['_id']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isLikedByUser(widget.track) ? Icons.favorite : Icons.favorite_border,
                              color: _isLikedByUser(widget.track) ? Colors.red : Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.track['likes'] ?? 0}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Add to Playlist Button
                    GestureDetector(
                      onTap: () => widget.onAddToPlaylist(widget.track['_id']),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.playlist_add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Beatport Button
                    if (widget.track['beatportUrl']?.isNotEmpty == true)
                      GestureDetector(
                        onTap: () => _launchBeatportUrl(widget.track['beatportUrl']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/beatport_logo.png',
                                width: 16,
                                height: 16,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Buy',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildRankIcon(int rank) {
    Color color;
    IconData icon;

    switch (rank) {
      case 1:
        color = Colors.amber;
        icon = Icons.emoji_events;
        break;
      case 2:
        color = Colors.grey.shade400;
        icon = Icons.emoji_events;
        break;
      case 3:
        color = Colors.brown.shade400;
        icon = Icons.emoji_events;
        break;
      default:
        color = Colors.white;
        icon = Icons.music_note;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: rank <= 3 ? color : Colors.grey[800],
        shape: BoxShape.circle,
        border: Border.all(
          color: rank <= 3 ? Colors.white : Colors.grey[600]!,
          width: 2,
        ),
        boxShadow: rank <= 3
            ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: rank <= 3
          ? Icon(icon, color: Colors.white, size: 20)
          : Center(
        child: Text(
          rank.toString(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSpotifyEmbed(String? spotifyId) {
    if (spotifyId == null) return Container();

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadRequest(Uri.parse(
        'https://open.spotify.com/embed/track/$spotifyId?utm_source=generator&theme=0',
      ));

    return SizedBox(
      height: 80,
      child: WebViewWidget(
        controller: controller,
        gestureRecognizers: Set()
          ..add(Factory<VerticalDragGestureRecognizer>(
                () => VerticalDragGestureRecognizer(),
          )),
      ),
    );
  }

  bool _isLikedByUser(Map<String, dynamic> track) {
    final userId = (context.findAncestorStateOfType<_HomeScreenState>())?.userId;
    return track['userLikes']?.contains(userId) ?? false;
  }

  Future<void> _launchBeatportUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }
}