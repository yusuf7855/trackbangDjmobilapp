import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './url_constants.dart';
import './common_music_player.dart';

class HotPage extends StatefulWidget {
  final String? userId;

  const HotPage({Key? key, this.userId}) : super(key: key);

  @override
  State<HotPage> createState() => _HotPageState();
}

class _HotPageState extends State<HotPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {

  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> hotCategories = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Preloading management
  final Map<String, List<Widget>> _preloadedMusicPlayers = {};
  final Map<String, bool> _categoryPreloadStatus = {};
  final Map<String, bool> _expandedStates = {};
  bool _allCategoriesPreloaded = false;

  // Loading animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  // Genre display names
  final Map<String, String> genreDisplayNames = {
    'afrohouse': 'Afro House',
    'indiedance': 'Indie Dance',
    'organichouse': 'Organic House',
    'downtempo': 'Down Tempo',
    'melodichouse': 'Melodic House',
  };

  // Genre icons
  final Map<String, IconData> genreIcons = {
    'afrohouse': Icons.music_note,
    'indiedance': Icons.queue_music,
    'organichouse': Icons.nature,
    'downtempo': Icons.slow_motion_video,
    'melodichouse': Icons.piano,
  };

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

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadHotCategories();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
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

  Future<void> _loadHotCategories() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/hot'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted && data['success'] == true) {
          final categories = data['hotPlaylists'] as List<dynamic>;

          // Pre-process and preload categories
          final processedCategories = categories.map<Map<String, dynamic>>((category) {
            return {
              'genre': category['_id'],
              'displayName': genreDisplayNames[category['_id']] ?? category['_id'],
              'icon': genreIcons[category['_id']] ?? Icons.music_note,
              'musics': category['musics'] as List<dynamic>,
              'playlistInfo': category['playlistInfo'],
            };
          }).toList();

          setState(() {
            hotCategories = processedCategories;
            isLoading = false;
          });

          // Initialize expanded states
          for (var category in hotCategories) {
            _expandedStates[category['genre']] = false;
          }

          // Start preloading first category
          if (hotCategories.isNotEmpty) {
            _preloadCategory(hotCategories.first['genre']);
          }
        } else {
          _handleError('Hot müzikler yüklenemedi');
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
        hasError = true;
        errorMessage = message;
      });
    }
  }

  Future<void> _preloadCategory(String genre) async {
    if (_categoryPreloadStatus[genre] == true || !mounted) return;

    final category = hotCategories.firstWhere(
          (cat) => cat['genre'] == genre,
      orElse: () => {},
    );

    if (category.isEmpty) return;

    _categoryPreloadStatus[genre] = true;

    final musics = category['musics'] as List<dynamic>;
    final preloadedPlayers = <Widget>[];

    for (int i = 0; i < musics.length && i < 10; i++) {
      final music = musics[i];
      final player = CommonMusicPlayer(
        key: ValueKey('hot_${genre}_${music['_id']}_$i'),
        track: music,
        userId: widget.userId,
        preloadWebView: true,
        lazyLoad: false,
      );
      preloadedPlayers.add(player);

      // Small delay between preloads
      if (mounted) {
        await Future.delayed(Duration(milliseconds: 100));
      }
    }

    if (mounted) {
      setState(() {
        _preloadedMusicPlayers[genre] = preloadedPlayers;
      });
    }
  }

  void _toggleCategory(String genre) async {
    setState(() {
      _expandedStates[genre] = !(_expandedStates[genre] ?? false);
    });

    // Preload if expanding and not already preloaded
    if (_expandedStates[genre] == true && _categoryPreloadStatus[genre] != true) {
      await _preloadCategory(genre);
    }

    // Preload next category
    final currentIndex = hotCategories.indexWhere((cat) => cat['genre'] == genre);
    if (currentIndex != -1 && currentIndex + 1 < hotCategories.length) {
      final nextGenre = hotCategories[currentIndex + 1]['genre'];
      _preloadCategory(nextGenre);
    }
  }

  Widget _buildLoadingAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Icon(
                  Icons.whatshot,
                  size: 80,
                  color: _colorAnimation.value,
                ),
              );
            },
          ),
          SizedBox(height: 24),
          Text(
            'Hot Müzikler Yükleniyor...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Container(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Hata Oluştu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
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
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadHotCategories,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.black,
            ),
            child: Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> category) {
    final genre = category['genre'] as String;
    final displayName = category['displayName'] as String;
    final icon = category['icon'] as IconData;
    final musics = category['musics'] as List<dynamic>;
    final isExpanded = _expandedStates[genre] ?? false;
    final isPreloaded = _categoryPreloadStatus[genre] ?? false;
    final preloadedPlayers = _preloadedMusicPlayers[genre] ?? [];

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.orange, size: 24),
        ),
        title: Text(
          displayName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${musics.length} hot şarkı',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPreloaded)
              Container(
                margin: EdgeInsets.only(right: 8),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Hazır',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white70,
            ),
          ],
        ),
        onExpansionChanged: (expanded) {
          if (expanded) {
            _toggleCategory(genre);
          } else {
            setState(() {
              _expandedStates[genre] = false;
            });
          }
        },
        children: isExpanded ? _buildMusicList(genre, musics, preloadedPlayers) : [],
      ),
    );
  }

  List<Widget> _buildMusicList(String genre, List<dynamic> musics, List<Widget> preloadedPlayers) {
    if (musics.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.music_off, color: Colors.grey[600], size: 32),
              SizedBox(height: 8),
              Text(
                'Bu kategoride hot müzik bulunamadı',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
        )
      ];
    }

    // Use preloaded players if available, otherwise create new ones
    if (preloadedPlayers.isNotEmpty) {
      return preloadedPlayers;
    }

    return musics.asMap().entries.map((entry) {
      final index = entry.key;
      final music = entry.value;

      return CommonMusicPlayer(
        key: ValueKey('hot_${genre}_${music['_id']}_$index'),
        track: music,
        userId: widget.userId,
        lazyLoad: true,
      );
    }).toList();
  }

  Widget _buildStatsHeader() {
    final totalMusics = hotCategories.fold<int>(
      0,
          (sum, category) => sum + (category['musics'] as List).length,
    );

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.withOpacity(0.2), Colors.red.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.whatshot, color: Colors.orange, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hot Müzikler',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$totalMusics şarkı • ${hotCategories.length} kategori',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'TREND',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (isLoading) {
      return _buildLoadingAnimation();
    }

    if (hasError) {
      return _buildErrorState();
    }

    if (hotCategories.isEmpty) {
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
              'Hot müzik bulunamadı',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHotCategories,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
              ),
              child: Text('Yenile'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHotCategories,
      backgroundColor: Colors.grey[900],
      color: Colors.orange,
      child: ListView(
        children: [
          _buildStatsHeader(),
          ...hotCategories.map((category) => _buildCategoryTile(category)),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}