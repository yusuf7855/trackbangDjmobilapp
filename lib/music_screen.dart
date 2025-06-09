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
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  // Categories
  final List<String> categories = [
    'All',
    'afrohouse',
    'indiedance',
    'organichouse',
    'downtempo',
    'melodichouse'
  ];

  final Map<String, String> categoryDisplayNames = {
    'All': 'Tüm Kategoriler',
    'afrohouse': 'Afro House',
    'indiedance': 'Indie Dance',
    'organichouse': 'Organic House',
    'downtempo': 'Down Tempo',
    'melodichouse': 'Melodic House',
  };

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _initializeAnimation();
    fetchMusics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_animationController);
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId') ?? prefs.getString('user_id');
    });
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

  Future<void> fetchMusics() async {
    setState(() {
      isLoading = true;
    });

    try {
      String endpoint = _selectedCategory == 'All'
          ? '${UrlConstants.apiBaseUrl}/api/music'
          : '${UrlConstants.apiBaseUrl}/api/music/category/$_selectedCategory';

      final response = await http.get(Uri.parse(endpoint));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && mounted) {
          setState(() {
            musicList = List<Map<String, dynamic>>.from(data['music'] ?? []);
            isLoading = false;
          });
        } else {
          _handleError('Müzikler yüklenemedi');
        }
      } else {
        _handleError('Sunucu hatası: ${response.statusCode}');
      }
    } catch (e) {
      _handleError('Bağlantı hatası: $e');
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        isLoading = false;
        musicList = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    fetchMusics();
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;

          return Container(
            margin: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                categoryDisplayNames[category] ?? category,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _onCategorySelected(category);
                }
              },
              backgroundColor: Colors.grey[800],
              selectedColor: Colors.orange,
              checkmarkColor: Colors.black,
              side: BorderSide(
                color: isSelected ? Colors.orange : Colors.grey[600]!,
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _rotationAnimation,
            child: Icon(
              Icons.music_note,
              color: Colors.orange,
              size: 64,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Müzikler yükleniyor...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            color: Colors.grey[600],
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Bu kategoride müzik bulunamadı',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Başka bir kategori deneyin',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _onCategorySelected('All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.black,
            ),
            child: Text('Tüm Müzikleri Göster'),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicList() {
    if (isLoading) {
      return _buildLoadingIndicator();
    }

    if (musicList.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: musicList.length,
      itemBuilder: (context, index) {
        return CommonMusicPlayer(
          track: musicList[index],
          userId: userId,
          lazyLoad: true,
          onLikeChanged: () {
            // Beğeni değiştiğinde listeyi yenile
            fetchMusics();
          },
        );
      },
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            'Toplam Müzik',
            '${musicList.length}',
            Icons.library_music,
            Colors.blue,
          ),
          _buildStatCard(
            'Kategori',
            categoryDisplayNames[_selectedCategory] ?? _selectedCategory,
            Icons.category,
            Colors.green,
          ),
          _buildStatCard(
            'Beğeniler',
            '${_getTotalLikes()}',
            Icons.favorite,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  int _getTotalLikes() {
    return musicList.fold(0, (sum, music) => sum + (music['likes'] ?? 0) as int);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Category chips
          _buildCategoryChips(),

          // Stats header
          if (!isLoading && musicList.isNotEmpty)
            _buildStatsHeader(),

          // Music list
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchMusics,
              backgroundColor: Colors.grey[900],
              color: Colors.orange,
              child: _buildMusicList(),
            ),
          ),
        ],
      ),
      floatingActionButton: userId != null
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePlaylistPage(),
            ),
          ).then((_) {
            // Playlist oluşturulduktan sonra sayfayı yenile
            fetchMusics();
          });
        },
        backgroundColor: Colors.orange,
        child: Icon(Icons.playlist_add, color: Colors.black),
        tooltip: 'Yeni Playlist Oluştur',
      )
          : null,
    );
  }
}