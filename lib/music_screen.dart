import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'create_playlist.dart';
import 'login_page.dart';
import 'url_constants.dart';
import 'common_music_player.dart';

class MusicScreen extends StatefulWidget {
  @override
  _MusicScreenState createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen>
    with SingleTickerProviderStateMixin {
  // State variables
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> musicList = [];
  bool isLoading = true;
  String? userId;
  bool _isDisposed = false;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

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
          _animationController.stop();
        }
      } else {
        throw Exception('Failed to load music');
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() => isLoading = false);
        _animationController.stop();
        _showSnackBar('Error loading music: $e');
      }
    }
  }

  Map<String, dynamic> _mapMusicItem(dynamic item) {
    return {
      'id': item['spotifyId'],
      'title': item['title'],
      'artist': item['artist'],
      'category': item['category'],
      'likes': item['likes'] ?? 0,
      '_id': item['_id'],
      'userLikes': item['userLikes'] ?? [],
      'beatportUrl': item['beatportUrl'] ?? '',
      'spotifyId': item['spotifyId'],
    };
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildCategorySelector(),
          Expanded(
            child: isLoading
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
    final filteredMusic = _getFilteredMusic();

    if (filteredMusic.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedCategory == 'All'
                  ? 'No music found'
                  : 'No music found in $_selectedCategory',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMusic,
      color: Colors.white,
      backgroundColor: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        itemCount: filteredMusic.length,
        itemBuilder: (context, index) {
          final track = filteredMusic[index];
          return Container(
            margin: EdgeInsets.only(bottom: 16),
            child: CommonMusicPlayer(
              track: track,
              userId: userId,
              onLikeChanged: _fetchMusic,
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredMusic() {
    if (_selectedCategory == 'All') {
      return musicList;
    }

    // Map category names to match API data
    String categoryFilter = _selectedCategory;
    switch (_selectedCategory) {
      case 'Afra House':
        categoryFilter = 'afrahouse';
        break;
      case 'Indie Dance':
        categoryFilter = 'indiedance';
        break;
      case 'Organic House':
        categoryFilter = 'organichouse';
        break;
      case 'Down tempo':
        categoryFilter = 'downtempo';
        break;
      case 'Melodic House':
        categoryFilter = 'melodichouse';
        break;
    }

    return musicList.where((m) =>
    m['category']?.toLowerCase() == categoryFilter.toLowerCase()).toList();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _animationController.stop();
    _animationController.dispose();
    super.dispose();
  }
}