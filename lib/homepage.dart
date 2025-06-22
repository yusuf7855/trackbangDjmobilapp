import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import './url_constants.dart';
import './create_playlist.dart';
import './standardized_playlist_dialog.dart';
import './menu/listeler_screen.dart';
import './menu/sample_bank_screen.dart';
import './menu/mostening_screen.dart';
import './menu/magaza_screen.dart';
import './menu/biz_kimiz_screen.dart';
import './world_page.dart';
import './hot_page.dart';
import './login_page.dart';
import './common_music_player.dart';
import './top10_music_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;

  const HomeScreen({Key? key, this.onMenuPressed}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  Map<String, bool> _houseExpandedStates = {};
  String selectedHouseGenre = 'Genre Filter';
  String houseFilterOrder = 'Newest First';

// Genre listesi
  final List<Map<String, String>> houseGenres = [
    {'display': 'Genre Filter', 'value': 'all'},
    {'display': 'Afro House', 'value': 'afrohouse'},
    {'display': 'Indie Dance', 'value': 'indiedance'},
    {'display': 'Organic House', 'value': 'organichouse'},
    {'display': 'Down Tempo', 'value': 'downtempo'},
    {'display': 'Melodic House', 'value': 'melodichouse'},
  ];


  void _toggleHousePlaylistExpansion(String playlistId) {
    setState(() {
      _houseExpandedStates[playlistId] = !(_houseExpandedStates[playlistId] ?? false);
    });
  }
  late TabController _tabController;
  String? userId;

  // Data for different tabs
  Map<String, List<dynamic>> top10Data = {};
  List<dynamic> housePlaylists = [];
  List<dynamic> userPlaylists = [];

  // Loading states
  bool isLoadingTop10 = true;
  bool isLoadingHouse = true;

  // WebView Cache sistemi
  final Map<String, WebViewController> _preloadedControllers = {};

  // Preloading management for Top10
  final Map<String, bool> _top10WebViewLoadedStatus = {};
  final Set<String> _allTop10TrackIds = {};
  bool _allTop10WebViewsLoaded = false;

  // Animation controller for loading
  late AnimationController _loadingAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeLoadingAnimation();
    _initializeUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  void _initializeLoadingAnimation() {
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _colorAnimation = ColorTween(
      begin: Colors.white.withOpacity(0.8),
      end: Colors.white,
    ).animate(_loadingAnimationController);
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });

    // Load all data
    await Future.wait([
      _loadTop10Data(),
      _loadHousePlaylists(),
    ]);

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
          final top10Map = Map<String, List<dynamic>>.from(data['top10']);

          setState(() {
            top10Data = top10Map;
          });

          // WebView'ları data yüklendikten hemen sonra başlat
          await _preloadAllWebViews();
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

  // Yeni preloading metodu - Her şarkı için benzersiz cache key
  Future<void> _preloadAllWebViews() async {
    print('Starting to preload ALL WebViews...');

    final List<Map<String, String>> allTracks = [];

    // Tüm kategorilerdeki tüm şarkıları topla - Her şarkı için benzersiz key
    top10Data.forEach((categoryKey, tracks) {
      for (int i = 0; i < tracks.length; i++) {
        final track = tracks[i];
        final spotifyId = track['spotifyId']?.toString();
        final trackId = track['_id']?.toString() ?? '';

        if (spotifyId != null && spotifyId.isNotEmpty) {
          // Benzersiz cache key: category_trackId_spotifyId
          final uniqueKey = '${categoryKey}_${trackId}_${spotifyId}';
          allTracks.add({
            'uniqueKey': uniqueKey,
            'spotifyId': spotifyId,
            'title': track['title'] ?? 'Unknown',
            'category': categoryKey,
            'trackId': trackId,
          });
        }
      }
    });

    print('Total tracks to preload: ${allTracks.length}');

    // Batch'ler halinde yükle (5'erli gruplar)
    const batchSize = 5;
    int loadedCount = 0;

    for (int i = 0; i < allTracks.length; i += batchSize) {
      final batch = allTracks.skip(i).take(batchSize).toList();

      print('Loading batch ${(i ~/ batchSize) + 1}: ${batch.map((t) => t['title']).join(', ')}');

      // Bu batch'i paralel yükle
      final batchFutures = batch.map((track) =>
          _preloadSingleWebView(
              track['uniqueKey']!,
              track['spotifyId']!,
              track['title']!
          ).then((_) {
            loadedCount++;
            print('✓ Loaded $loadedCount/${allTracks.length}: ${track['title']} (${track['category']})');
          }).catchError((e) {
            loadedCount++;
            print('✗ Failed $loadedCount/${allTracks.length}: ${track['title']} - $e');
          })
      ).toList();

      // Bu batch'in tamamlanmasını bekle
      await Future.wait(batchFutures);

      // Batch'ler arası kısa bekleme (sistem nefes alsın)
      if (i + batchSize < allTracks.length) {
        await Future.delayed(Duration(milliseconds: 200));
      }
    }

    print('🎉 All WebViews preloaded successfully! Total: $loadedCount');

    if (mounted) {
      setState(() {
        isLoadingTop10 = false;
        _allTop10WebViewsLoaded = true;
      });
    }

    _loadingAnimationController.stop();
  }

  // Tek WebView preload metodu - Benzersiz key ile
  Future<void> _preloadSingleWebView(String uniqueKey, String spotifyId, String trackTitle) async {
    try {
      // Eğer zaten cache'de varsa skip et
      if (_preloadedControllers.containsKey(uniqueKey)) {
        print('Already cached: $trackTitle');
        return;
      }

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15')
        ..enableZoom(false);

      // Basit ve hızlı yükleme - sadece temel setup
      final completer = Completer<void>();
      bool isCompleted = false;

      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            print('Starting load: $trackTitle');
          },
          onPageFinished: (url) async {
            if (isCompleted) return;

            try {
              // Minimal JavaScript - sadece gerekli olanlar
              await controller.runJavaScript('''
                document.body.style.margin = '0';
                document.body.style.padding = '0';
                document.body.style.overflow = 'hidden';
              ''');

              // Daha kısa bekleme
              await Future.delayed(Duration(milliseconds: 100));

              if (!isCompleted) {
                isCompleted = true;
                completer.complete();
              }
            } catch (e) {
              if (!isCompleted) {
                isCompleted = true;
                completer.complete();
              }
            }
          },
          onWebResourceError: (error) {
            if (!isCompleted) {
              isCompleted = true;
              completer.complete();
            }
          },
        ),
      );

      // URL yükle
      await controller.loadRequest(
          Uri.parse('https://open.spotify.com/embed/track/$spotifyId?utm_source=generator&theme=0')
      );

      // Daha kısa timeout (5 saniye)
      await Future.any([
        completer.future,
        Future.delayed(Duration(seconds: 5)).then((_) {
          if (!isCompleted) {
            isCompleted = true;
            completer.complete();
          }
        }),
      ]);

      // Cache'e benzersiz key ile kaydet
      _preloadedControllers[uniqueKey] = controller;

    } catch (e) {
      print('Failed to preload $trackTitle: $e');
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  // Loading animation widget
  Widget _buildLoadingAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _loadingAnimationController,
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
                        offset: Offset(0, 0),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 30),
          Text(
            'Trackbang Yükleniyor...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),

          SizedBox(height: 10),
          // Progress indicator
          Container(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTop10Tab() {
    // Show loading animation if still loading
    if (isLoadingTop10 || !_allTop10WebViewsLoaded) {
      return _buildLoadingAnimation();
    }

    final categories = [
      {'key': 'all', 'title': 'Trackbang Top 10'},
      {'key': 'afrohouse', 'title': 'Afro House'},
      {'key': 'indiedance', 'title': 'Indie Dance'},
      {'key': 'organichouse', 'title': 'Organic House'},
      {'key': 'downtempo', 'title': 'Down Tempo'},
      {'key': 'melodichouse', 'title': 'Melodic House'},
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: 0), // 16'dan 8'e düşürüldü
        ),
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
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basit başlık - sola dayalı ve modern font
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(
              '# $title',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w300, // Light weight
                fontStyle: FontStyle.italic, // İtalik
                letterSpacing: 0, // Daha geniş harf aralığı
                shadows: [
                  Shadow(
                    offset: Offset(1.0, 1.0),
                    blurRadius: 3.0,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),

          // Şarkılar - Cache'den benzersiz key ile al
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: tracks.asMap().entries.map<Widget>((entry) {
                final index = entry.key;
                final music = entry.value;
                final spotifyId = music['spotifyId']?.toString();
                final trackId = music['_id']?.toString() ?? '';

                // Benzersiz cache key oluştur
                final categoryKey = _getCategoryKey(title);
                final uniqueKey = '${categoryKey}_${trackId}_${spotifyId}';

                // Cache'de varsa direkt WebView göster
                if (spotifyId != null && _preloadedControllers.containsKey(uniqueKey)) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[900]?.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[700]!, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Cache'den alınan WebView
                        Container(
                          height: 80,
                          child: ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                            ),
                            child: WebViewWidget(controller: _preloadedControllers[uniqueKey]!),
                          ),
                        ),
                        // Action buttons bölümü - Tüm butonlar dahil
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                            border: Border(
                              top: BorderSide(color: Colors.grey[700]!, width: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _buildCachedActionButtons(music),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Cache'de yoksa normal CommonMusicPlayer (fallback)
                return CommonMusicPlayer(
                  key: ValueKey('top10_${music['_id']}_${title}_$index'),
                  track: music,
                  userId: userId,
                  preloadWebView: true,
                  lazyLoad: false,
                  onLikeChanged: () {
                    _loadTop10Data();
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Kategori title'ından key oluşturmak için helper metod
  String _getCategoryKey(String title) {
    switch (title) {
      case 'Trackbang Top 10':
        return 'all';
      case 'Afro House':
        return 'afrohouse';
      case 'Indie Dance':
        return 'indiedance';
      case 'Organic House':
        return 'organichouse';
      case 'Down Tempo':
        return 'downtempo';
      case 'Melodic House':
        return 'melodichouse';
      default:
        return title.toLowerCase().replaceAll(' ', '');
    }
  }

  // Cache'li şarkılar için action buttons
  List<Widget> _buildCachedActionButtons(Map<String, dynamic> music) {
    List<Widget> buttons = [];

    // Like Button
    if (userId != null) {
      buttons.add(
        Expanded(
          child: GestureDetector(
            onTap: () => _toggleLike(music),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              margin: EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: _isLikedByUser(music)
                    ? Colors.red.withOpacity(0.15)
                    : Colors.grey[700]?.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
                border: _isLikedByUser(music)
                    ? Border.all(color: Colors.red.withOpacity(0.4), width: 1)
                    : Border.all(color: Colors.grey[600]!, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isLikedByUser(music) ? Icons.favorite : Icons.favorite_border,
                    color: _isLikedByUser(music) ? Colors.red : Colors.white70,
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${music['likes'] ?? 0}',
                    style: TextStyle(
                      color: _isLikedByUser(music) ? Colors.red : Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Playlist Button
    if (userId != null) {
      buttons.add(
        Expanded(
          child: GestureDetector(
            onTap: () => _showAddToPlaylistDialog(music),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              margin: EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.playlist_add,
                    color: Colors.blue,
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      'Playliste Ekle',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Beatport Button
    if (music['beatportUrl']?.isNotEmpty == true) {
      buttons.add(
        Expanded(
          child: GestureDetector(
            onTap: () => _launchBeatportUrl(music['beatportUrl']),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              margin: EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/beatport_logo.png',
                    width: 8,
                    height: 10,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      'Beatport',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  // Helper methods for like functionality
  bool _isLikedByUser(Map<String, dynamic> music) {
    if (userId == null) return false;
    final userLikes = List<String>.from(music['userLikes'] ?? []);
    return userLikes.contains(userId);
  }

  Future<void> _toggleLike(Map<String, dynamic> music) async {
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/music/${music['_id']}/like'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final currentLikes = music['likes'] ?? 0;
        final userLikes = List<String>.from(music['userLikes'] ?? []);

        if (mounted) {
          setState(() {
            if (userLikes.contains(userId)) {
              userLikes.remove(userId);
              music['likes'] = currentLikes - 1;
            } else {
              userLikes.add(userId!);
              music['likes'] = currentLikes + 1;
            }
            music['userLikes'] = userLikes;
          });
        }
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  // Playlist dialog'u göster - CategoryPage ile aynı
  void _showAddToPlaylistDialog(Map<String, dynamic> music) {
    if (userId == null) return;

    StandardizedPlaylistDialog.show(
      context: context,
      track: music,
      userId: userId,
      onPlaylistUpdated: () {
        _loadTop10Data(); // Top10 verilerini yenile
      },
    );
  }

  // Bu metodları kaldırabiliriz - artık StandardizedPlaylistDialog kullanıyoruz
  // Eski metodlar yerine StandardizedPlaylistDialog kullanılıyor

  // Beatport URL'ini aç
  Future<void> _launchBeatportUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Beatport linki açılamadı'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // World tab uses the separate WorldPage
  Widget _buildWorldTab() {
    return WorldPage(userId: userId);
  }

  Widget _buildHouseTab() {
    return Column(
      children: [
        // Filter Header - Same as World page
        Container(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Color(0xFF0A0A0A),
          ),
          child: Row(
            children: [
              // Genre Filter Dropdown
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
                      value: selectedHouseGenre,
                      isExpanded: true,
                      dropdownColor: Color(0xFF111111),
                      isDense: true,
                      style: TextStyle(
                        color: selectedHouseGenre == 'Genre Filter' ? Colors.grey[400] : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      icon: Icon(
                        Icons.expand_more,
                        color: Colors.grey[400],
                        size: 17,
                      ),
                      items: houseGenres.map((genre) {
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
                            selectedHouseGenre = newValue;
                            _loadHousePlaylists(); // Bu fonksiyonu güncelleyeceksiniz
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),

              SizedBox(width: 10),

              // Sort Dropdown
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
                      value: houseFilterOrder,
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
                            houseFilterOrder = newValue;
                            _loadHousePlaylists(); // Bu fonksiyonu güncelleyeceksiniz
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
          child: isLoadingHouse
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
                    turns: _loadingAnimationController,
                    child: Icon(
                      Icons.refresh,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Loading House Playlists...',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
              : housePlaylists.isEmpty
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
                  'No House Playlists',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  selectedHouseGenre != 'Genre Filter'
                      ? 'No playlists in $selectedHouseGenre category'
                      : 'No house playlists found',
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
            onRefresh: _loadHousePlaylists,
            backgroundColor: Color(0xFF1A1A1A),
            color: Colors.white,
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 32),
              itemCount: housePlaylists.length,
              itemBuilder: (context, index) {
                final playlist = housePlaylists[index];
                final playlistId = playlist['_id']?.toString() ?? '';
                final isExpanded = _houseExpandedStates[playlistId] ?? false;
                final musics = playlist['musics'] as List<dynamic>? ?? [];

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
                      // Playlist Header - Clickable
                      InkWell(
                        onTap: () => _toggleHousePlaylistExpansion(playlistId),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Playlist Icon
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Color(0xFF333333), width: 1),
                                ),
                                child: Icon(
                                  Icons.queue_music,
                                  color: Colors.blue[400],
                                  size: 24,
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
                                        SizedBox(width: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Color(0xFF2A2A2A),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${musics.length} tracks',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[500],
                                              fontWeight: FontWeight.w500,
                                            ),
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
                        ),
                      ),

                      // Expanded Music List
                      if (isExpanded && musics.isNotEmpty)
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
                            children: musics.map((music) {
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: CommonMusicPlayer(
                                  track: music,
                                  userId: userId,
                                  preloadWebView: true,
                                  lazyLoad: false,
                                  onLikeChanged: () {
                                    _loadHousePlaylists();
                                  },
                                ),
                              );
                            }).toList(),
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
    );
  }

// Expansion state toggle fonksiyonu

  // Hot tab uses the separate HotPage
  Widget _buildHotTab() {
    return HotPage(userId: userId);
  }

  Widget _buildPlaylistCard(Map<String, dynamic> playlist) {
    final musics = playlist['musics'] as List<dynamic>? ?? [];
    final owner = playlist['owner'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern playlist header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist['name'] ?? 'Unnamed Playlist',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (owner != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'by ${owner['displayName'] ?? owner['username']}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${musics.length}',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Music cards
          if (musics.isNotEmpty)
            ...musics.map((music) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: CommonMusicPlayer(
                track: music,
                userId: userId,
                preloadWebView: true,
                lazyLoad: false,
                onLikeChanged: () {
                  _loadHousePlaylists();
                },
              ),
            )).toList()
          else
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!, width: 1),
              ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // Menu button
            IconButton(
              icon: Icon(Icons.menu, color: Colors.white, size: 28),
              onPressed: widget.onMenuPressed,
              padding: EdgeInsets.zero,
            ),

            // Logo
            Container(
              margin: EdgeInsets.only(left: 0),
              child: Image.asset(
                'assets/your_logo.png',
                height: 30,
                fit: BoxFit.contain,
              ),
            ),

            Spacer(),

            // Actions
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