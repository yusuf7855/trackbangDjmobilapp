import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'create_playlist.dart';
import 'login_page.dart';
import 'url_constants.dart';

class MusicScreen extends StatefulWidget {
  @override
  _MusicScreenState createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen>
    with SingleTickerProviderStateMixin {
  // State variables
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> musicList = [];
  List<Map<String, dynamic>> userPlaylists = [];
  bool isLoading = true;
  bool _allTracksLoaded = false;
  String? userId;
  bool _isDisposed = false;
  final TextEditingController _newPlaylistController = TextEditingController();

  // Animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  // WebView management
  final Map<String, WebViewController> _webViewCache = {};
  final Map<String, bool> _webViewLoadingStates = {};

  // Constants
  final List<String> categories = [
    'All', 'Afra House', 'Indie Dance',
    'Organic House', 'Down tempo', 'Melodic House'
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeUser();
    _fetchMusic();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _colorAnimation = ColorTween(
      begin: Colors.white.withOpacity(0.8),
      end: Colors.white,
    ).animate(_animationController);
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final fetchedUserId = prefs.getString('userId');

    if (!mounted || _isDisposed) return;

    setState(() => userId = fetchedUserId);

    if (userId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
      });
    } else {
      _fetchUserPlaylists();
    }
  }

  Future<void> _fetchMusic() async {
    try {
      final response = await http.get(
          Uri.parse('${UrlConstants.apiBaseUrl}/api/music'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted && !_isDisposed) {
          setState(() {
            musicList = data.map((item) => _mapMusicItem(item)).toList();
            isLoading = false;
          });
          _preloadWebViews();
        }
      } else {
        throw Exception('Failed to load music');
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() => isLoading = false);
        _showSnackBar('Error loading music: $e');
      }
    }
  }

  Map<String, dynamic> _mapMusicItem(dynamic item) {
    return {
      'id': item['spotifyId'],
      'title': item['title'],
      'category': item['category'],
      'likes': item['likes'] ?? 0,
      '_id': item['_id'],
      'userLikes': item['userLikes'] ?? [],
      'beatportUrl': item['beatportUrl'] ?? '',
    };
  }

  void _preloadWebViews() {
    for (final track in musicList) {
      _webViewLoadingStates[track['id']] = false;

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              if (mounted && !_isDisposed) {
                setState(() {
                  _webViewLoadingStates[track['id']] = true;
                  _checkAllTracksLoaded();
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(
          'https://open.spotify.com/embed/track/${track['id']}?utm_source=generator&theme=0',
        ));

      _webViewCache[track['id']] = controller;
    }
  }

  void _checkAllTracksLoaded() {
    if (_webViewLoadingStates.values.every((isLoaded) => isLoaded)) {
      if (mounted && !_isDisposed) {
        setState(() => _allTracksLoaded = true);
        _animationController.stop();
      }
    }
  }

  Future<void> _fetchUserPlaylists() async {
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && mounted) {
          setState(() {
            userPlaylists = (responseData['playlists'] as List).map((item) =>
                _mapPlaylistItem(item)).toList();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading playlists: ${e.toString()}');
      }
    }
  }

  Map<String, dynamic> _mapPlaylistItem(dynamic item) {
    return {
      '_id': item['_id'],
      'name': item['name'],
      'description': item['description'] ?? '',
      'musicCount': item['musicCount'] ?? 0,
      'genre': item['genre'] ?? 'other',
      'isPublic': item['isPublic'] ?? false,
    };
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
        _fetchMusic();
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error liking track: $e');
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
      _showSnackBar(
        responseData['message'] ??
            (response.statusCode == 200
                ? 'Added to playlist successfully'
                : 'Error adding to playlist'),
        isError: response.statusCode != 200,
      );

      if (response.statusCode == 200) {
        await _fetchUserPlaylists();
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  void _showAddToPlaylistDialog(String musicId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (userPlaylists.isNotEmpty) ...[
              _buildPlaylistOption(
                icon: Icons.playlist_add,
                label: 'Add to existing playlist',
                onTap: () {
                  Navigator.pop(context);
                  _showExistingPlaylists(musicId);
                },
              ),
              const Divider(),
            ],
            _buildPlaylistOption(
              icon: Icons.add,
              label: 'Create new playlist',
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

  Widget _buildPlaylistOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }

  void _showExistingPlaylists(String musicId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Playlists',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: userPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = userPlaylists[index];
                  return ListTile(
                    title: Text(playlist['name']),
                    subtitle: Text(
                        '${playlist['musicCount']} tracks • ${playlist['genre']}'),
                    onTap: () {
                      _addToExistingPlaylist(musicId, playlist['_id']);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
      await _fetchUserPlaylists(); // Refresh your playlists if needed
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  bool _isLikedByUser(Map<String, dynamic> track) {
    return track['userLikes']?.contains(userId) ?? false;
  }

  Future<void> _launchBeatportUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        throw 'Could not launch URL: $url';
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildCategorySelector(),
          Expanded(
            child: isLoading || !_allTracksLoaded
                ? _buildLoadingAnimation()
                : _buildMusicContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _buildCategoryChip(index),
      ),
    );
  }

  Widget _buildCategoryChip(int index) {
    return ChoiceChip(
      label: Text(
        categories[index],
        style: TextStyle(
          color: _selectedCategory == categories[index]
              ? Colors.black
              : Colors.white,
        ),
      ),
      selected: _selectedCategory == categories[index],
      selectedColor: Colors.white,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      onSelected: (selected) => setState(
              () => _selectedCategory = categories[index]),
    );
  }

  Widget _buildLoadingAnimation() {
    return Center(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Text(
              'B',
              style: TextStyle(
                color: _colorAnimation.value,
                fontSize: 96,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity(0.7),
                    blurRadius: 15,
                    offset: Offset.zero,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMusicContent() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: _getFilteredMusic().length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) =>
          _buildMusicCard(_getFilteredMusic()[index]),
    );
  }

  Widget _buildMusicCard(Map<String, dynamic> track) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
      BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 6,
      offset: const Offset(0, 3),
      )
      ],
    ),
    child: Column(
    children: [
    _buildSpotifyEmbed(track),
    _buildMusicActions(track),
    ],
    ),
    );
  }

  Widget _buildSpotifyEmbed(Map<String, dynamic> track) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        child: WebViewWidget(
          controller: _webViewCache[track['id']]!,
        ),
      ),
    );
  }

  Widget _buildMusicActions(Map<String, dynamic> track) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildLikeButton(track),
          _buildAddToPlaylistButton(track),
          if (track['beatportUrl']?.isNotEmpty == true)
            _buildBeatportButton(track),
        ],
      ),
    );
  }

  Widget _buildLikeButton(Map<String, dynamic> track) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            _isLikedByUser(track) ? Icons.favorite : Icons.favorite_border,
            color: _isLikedByUser(track) ? Colors.red : Colors.white,
            size: 24,
          ),
          onPressed: () => _toggleLike(track['_id']),
        ),
        Text('${track['likes']}', style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _buildAddToPlaylistButton(Map<String, dynamic> track) {
    return IconButton(
      icon: const Icon(Icons.playlist_add, color: Colors.white, size: 24),
      onPressed: () => _showAddToPlaylistDialog(track['_id']),
    );
  }

  Widget _buildBeatportButton(Map<String, dynamic> track) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    icon: Image.asset(
    'assets/beatport_logo.png',
    width: 24,
    height: 24,
    ),
    label: const Text('Buy on Beatport'),
    onPressed: () => _launchBeatportUrl(track['beatportUrl']),
    );
  }

  List<Map<String, dynamic>> _getFilteredMusic() {
    return _selectedCategory == 'All'
        ? musicList
        : musicList.where((m) => m['category'] == _selectedCategory).toList();
  }

  @override
  void dispose() {
    _newPlaylistController.dispose();
    _isDisposed = true;
    _animationController.stop();
    _animationController.dispose();
    _webViewCache.clear();
    super.dispose();
  }
}