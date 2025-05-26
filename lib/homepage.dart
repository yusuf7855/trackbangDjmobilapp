import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import './url_constants.dart';

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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final tracks = top10Data[category['key']] ?? [];

        return _buildCategorySection(category['title']!, tracks);
      },
    );
  }

  Widget _buildCategorySection(String title, List<dynamic> tracks) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...tracks.asMap().entries.map((entry) {
            final index = entry.key;
            final track = entry.value;
            return _buildTrackItem(track, index + 1);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTrackItem(Map<String, dynamic> track, int rank) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                rank.toString(),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              track['title'] ?? 'Unknown',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              track['artist'] ?? 'Unknown Artist',
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Text(
                  track['likes'].toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          if (track['spotifyId'] != null)
            Container(
              height: 80,
              margin: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildSpotifyEmbed(track['spotifyId']),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorldTab() {
    if (isLoadingWorld) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: worldPlaylists.length,
      itemBuilder: (context, index) {
        final playlist = worldPlaylists[index];
        return _buildPlaylistCard(playlist);
      },
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: housePlaylists.length,
      itemBuilder: (context, index) {
        final playlist = housePlaylists[index];
        return _buildPlaylistCard(playlist);
      },
    );
  }

  Widget _buildHotTab() {
    if (isLoadingHot) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hotPlaylists.length,
      itemBuilder: (context, index) {
        final hotPlaylist = hotPlaylists[index];
        return _buildHotPlaylistCard(hotPlaylist);
      },
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

  Widget _buildSpotifyEmbed(String? spotifyId) {
    if (spotifyId == null) return Container();

    // Check if we have cached WebView
    if (_webViewCache.containsKey(spotifyId)) {
      return WebViewWidget(controller: _webViewCache[spotifyId]!);
    }

    // Create new WebView controller
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadRequest(Uri.parse(
        'https://open.spotify.com/embed/track/$spotifyId?utm_source=generator&theme=0',
      ));

    _webViewCache[spotifyId] = controller;
    return WebViewWidget(controller: controller);
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
                    height: 40, // Adjusted logo height
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