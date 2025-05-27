import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import './url_constants.dart';
import './create_playlist.dart';
import './menu/listeler_screen.dart';
import './menu/sample_bank_screen.dart';
import './menu/mostening_screen.dart';
import './menu/magaza_screen.dart';
import './menu/biz_kimiz_screen.dart';
import './login_page.dart';

// Import the new common music player
import './common_music_player.dart';
import './top10_music_card.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  // Drawer builder
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.black,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.grey[900],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/your_logo.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  'DJ Mobile App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            icon: Icons.list,
            title: 'Listeler',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ListelerScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.library_music,
            title: 'Samplebank',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SampleBankScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.headset,
            title: 'Mostening',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MosteningScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.store,
            title: 'Mağaza',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MagazaScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.info,
            title: 'Biz Kimiz',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BizKimizScreen()),
              );
            },
          ),
          Divider(color: Colors.grey[700]),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Çıkış Yap',
            onTap: () async {
              Navigator.pop(context);
              await _logout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: TextStyle(color: Colors.white),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
          (Route<dynamic> route) => false,
    );
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
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[850]!,
                  Colors.grey[900]!,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[700]!, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber, Colors.orange],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.trending_up, color: Colors.white, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Most Liked Tracks',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(
                    'TOP ${tracks.length}',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Top 10 Music Cards
          ...tracks.asMap().entries.map((entry) {
            final index = entry.key;
            final track = entry.value;
            return Top10MusicCard(
              track: track,
              rank: index + 1,
              userId: userId,
              onLikeChanged: () {
                _loadTop10Data(); // Refresh data when like changes
              },
            );
          }).toList(),
        ],
      ),
    );
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: EdgeInsets.only(bottom: 16),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white70,
        title: Text(
          playlist['name'] ?? 'Unnamed Playlist',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (owner != null)
              Text(
                'by ${owner['displayName'] ?? owner['username']}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.music_note, color: Colors.grey[400], size: 16),
                const SizedBox(width: 4),
                Text(
                  '${playlist['musicCount'] ?? 0} songs',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Icon(Icons.category, color: Colors.grey[400], size: 16),
                const SizedBox(width: 4),
                Text(
                  playlist['genre'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        children: [
          if (musics.isNotEmpty)
            ...musics.map((music) => CommonMusicPlayer(
              track: music,
              userId: userId,
              onLikeChanged: () {
                _loadWorldPlaylists();
                _loadHousePlaylists();
              },
            )).toList()
          else
            Container(
              padding: EdgeInsets.all(20),
              child: Text(
                'This playlist is empty',
                style: TextStyle(color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHotPlaylistCard(Map<String, dynamic> hotPlaylist) {
    final musics = hotPlaylist['musics'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: EdgeInsets.only(bottom: 16),
        iconColor: Colors.orange,
        collapsedIconColor: Colors.orange.withOpacity(0.7),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.whatshot, color: Colors.orange, size: 20),
        ),
        title: Text(
          hotPlaylist['name'] ?? 'Unnamed HOT Playlist',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.music_note, color: Colors.grey[400], size: 16),
                const SizedBox(width: 4),
                Text(
                  '${hotPlaylist['musicCount'] ?? 0} songs',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Icon(Icons.category, color: Colors.grey[400], size: 16),
                const SizedBox(width: 4),
                Text(
                  hotPlaylist['category'] ?? 'All Categories',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        children: [
          if (musics.isNotEmpty)
            ...musics.map((music) => CommonMusicPlayer(
              track: music,
              userId: userId,
              onLikeChanged: () {
                _loadHotPlaylists();
              },
            )).toList()
          else
            Container(
              padding: EdgeInsets.all(20),
              child: Text(
                'This HOT playlist is empty',
                style: TextStyle(color: Colors.grey[400]),
                textAlign: TextAlign.center,
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
        backgroundColor: Colors.black,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/your_logo.png',
              height: 40,
              fit: BoxFit.contain,
            ),
          ],
        ),
        actions: [
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Top 10'),
            Tab(text: 'World'),
            Tab(text: 'House'),
            Tab(text: 'Hot'),
          ],
        ),
      ),
      drawer: _buildDrawer(),
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