import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import './url_constants.dart';
import './create_playlist.dart';
import './standardized_playlist_dialog.dart';

class CommonMusicPlayer extends StatefulWidget {
  final Map<String, dynamic> track;
  final String? userId;
  final VoidCallback? onLikeChanged;
  final Function(String)? onWebViewLoaded;
  final String? webViewKey;
  final bool preloadWebView;
  final bool lazyLoad;

  const CommonMusicPlayer({
    Key? key,
    required this.track,
    this.userId,
    this.onLikeChanged,
    this.onWebViewLoaded,
    this.webViewKey,
    this.preloadWebView = false,
    this.lazyLoad = true,
  }) : super(key: key);

  @override
  State<CommonMusicPlayer> createState() => _CommonMusicPlayerState();
}

class _CommonMusicPlayerState extends State<CommonMusicPlayer> with AutomaticKeepAliveClientMixin {
  late WebViewController _webViewController;
  bool _isWebViewInitialized = false;
  bool _isWebViewLoaded = false;
  bool _hasStartedLoading = false;
  List<Map<String, dynamic>> userPlaylists = [];
  String? _currentSpotifyId;

  @override
  bool get wantKeepAlive => true;

  // Çoklu sanatçı desteği için helper method
  String _getDisplayArtists() {
    // 1. displayArtists varsa onu kullan (backend'den gelen hazır format)
    if (widget.track['displayArtists'] != null &&
        widget.track['displayArtists'].toString().isNotEmpty) {
      return widget.track['displayArtists'].toString();
    }

    // 2. artists array varsa onu birleştir
    if (widget.track['artists'] != null &&
        widget.track['artists'] is List &&
        (widget.track['artists'] as List).isNotEmpty) {
      final artistsList = widget.track['artists'] as List;
      return artistsList
          .where((artist) => artist != null && artist.toString().trim().isNotEmpty)
          .map((artist) => artist.toString().trim())
          .join(', ');
    }

    // 3. Eski tek sanatçı field'i varsa onu kullan (backward compatibility)
    if (widget.track['artist'] != null &&
        widget.track['artist'].toString().trim().isNotEmpty) {
      return widget.track['artist'].toString().trim();
    }

    // 4. Hiçbiri yoksa default
    return 'Unknown Artist';
  }

  @override
  void initState() {
    super.initState();

    if (widget.preloadWebView || !widget.lazyLoad) {
      _initializeWebView();
    }

    if (widget.userId != null) {
      _loadUserPlaylists();
    }
  }

  @override
  void didUpdateWidget(CommonMusicPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newSpotifyId = widget.track['spotifyId']?.toString();
    if (newSpotifyId != _currentSpotifyId) {
      print('CommonMusicPlayer: Spotify ID changed from $_currentSpotifyId to $newSpotifyId - Reloading WebView');
      _isWebViewLoaded = false;
      _hasStartedLoading = false;
      _initializeWebView();
    }
  }

  void _initializeWebView() {
    if (_hasStartedLoading) return;

    final spotifyId = widget.track['spotifyId']?.toString();
    if (spotifyId != null && spotifyId.isNotEmpty) {
      _hasStartedLoading = true;
      _currentSpotifyId = spotifyId;

      print('CommonMusicPlayer: Initializing WebView for track: ${widget.track['title']} with Spotify ID: $spotifyId');

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              print('CommonMusicPlayer: Page started loading: $url');
            },
            onPageFinished: (String url) async {
              if (mounted) {
                setState(() {
                  _isWebViewLoaded = true;
                });
                widget.onWebViewLoaded?.call(widget.webViewKey ?? spotifyId);
                print('CommonMusicPlayer: Page finished loading: $url');
              }
            },
            onWebResourceError: (WebResourceError error) {
              print('CommonMusicPlayer: WebView error: ${error.description}');
            },
          ),
        )
        ..loadRequest(Uri.parse('https://open.spotify.com/embed/track/$spotifyId?utm_source=generator&theme=0'));

      if (mounted) {
        setState(() {
          _isWebViewInitialized = true;
        });
      }
    }
  }

  Future<void> _loadUserPlaylists() async {
    if (widget.userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) return;

      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/${widget.userId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            userPlaylists = List<Map<String, dynamic>>.from(data['playlists'] ?? []);
          });
        }
      }
    } catch (e) {
      print('Error loading user playlists: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Beğenmek için giriş yapmalısınız'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Oturum süresi dolmuş. Tekrar giriş yapın.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final musicId = widget.track['_id']?.toString() ?? widget.track['id']?.toString();
      if (musicId == null) return;

      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/music/like/$musicId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            widget.track['likes'] = data['likes'];
            widget.track['userLikes'] = List<String>.from(data['userLikes'] ?? []);
          });
          widget.onLikeChanged?.call();
        }
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  bool _isLikedByUser() {
    if (widget.userId == null) return false;
    final userLikes = widget.track['userLikes'] as List?;
    return userLikes?.contains(widget.userId) ?? false;
  }

  void _showPlaylistOptions() {
    showDialog(
      context: context,
      builder: (context) => StandardizedPlaylistDialog(
        track: widget.track,
        userId: widget.userId,
        userPlaylists: userPlaylists,
        onPlaylistsUpdated: _loadUserPlaylists,
      ),
    );
  }

  void _launchBeatportUrl() async {
    final beatportUrl = widget.track['beatportUrl']?.toString();
    if (beatportUrl != null && beatportUrl.isNotEmpty) {
      final Uri url = Uri.parse(beatportUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final displayArtists = _getDisplayArtists();
    final title = widget.track['title']?.toString() ?? 'Unknown Title';
    final likes = widget.track['likes'] ?? 0;
    final category = widget.track['category']?.toString();
    final isLiked = _isLikedByUser();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        color: Colors.grey[900],
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            // Header with title and artist info
            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  // Music icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.music_note,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),

                  // Title and artist info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          displayArtists,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          maxLines: 2, // Çoklu sanatçı için 2 satır
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (category != null) ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Action buttons
                  Column(
                    children: [
                      // Like button
                      IconButton(
                        onPressed: _toggleLike,
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey[400],
                          size: 20,
                        ),
                      ),
                      Text(
                        '$likes',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  // More actions menu
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                    color: Colors.grey[800],
                    onSelected: (String choice) {
                      switch (choice) {
                        case 'add_to_playlist':
                          _showPlaylistOptions();
                          break;
                        case 'beatport':
                          _launchBeatportUrl();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'add_to_playlist',
                        child: Row(
                          children: [
                            Icon(Icons.playlist_add, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Playlist\'e Ekle', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      if (widget.track['beatportUrl'] != null &&
                          widget.track['beatportUrl'].toString().isNotEmpty)
                        PopupMenuItem<String>(
                          value: 'beatport',
                          child: Row(
                            children: [
                              Icon(Icons.shopping_cart, color: Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Text('Beatport\'ta Aç', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Spotify Player
            if (_isWebViewInitialized) ...[
              Container(
                height: 152,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _webViewController),
                      if (!_isWebViewLoaded)
                        Container(
                          color: Colors.black,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                  strokeWidth: 2,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Spotify Player Yükleniyor...',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ] else if (widget.lazyLoad) ...[
              // Lazy load button
              Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _initializeWebView,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_filled, color: Colors.orange, size: 28),
                          SizedBox(width: 8),
                          Text(
                            'Player\'ı Yükle',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}