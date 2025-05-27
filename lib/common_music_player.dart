import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import './url_constants.dart';
import './create_playlist.dart';

class CommonMusicPlayer extends StatefulWidget {
  final Map<String, dynamic> track;
  final String? userId;
  final VoidCallback? onLikeChanged;
  final Function(String)? onWebViewLoaded;
  final String? webViewKey;
  final bool preloadWebView; // Yeni parametre
  final bool lazyLoad; // Lazy loading için

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

  @override
  void initState() {
    super.initState();

    // Preload durumunda veya lazy load kapalıysa hemen WebView'ı başlat
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
    if (_hasStartedLoading) return; // Prevent multiple initializations

    final spotifyId = widget.track['spotifyId']?.toString();
    if (spotifyId != null && spotifyId.isNotEmpty) {
      _hasStartedLoading = true;
      _currentSpotifyId = spotifyId;

      print('CommonMusicPlayer: Initializing WebView for track: ${widget.track['title']} with Spotify ID: $spotifyId');

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1')
        ..enableZoom(false)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              print('CommonMusicPlayer WebView started loading: $url');
            },
            onPageFinished: (url) async {
              print('CommonMusicPlayer WebView loaded: $url for track: ${widget.track['title']}');

              // JavaScript optimizasyonları
              await _webViewController.runJavaScript('''
                (function() {
                  // Remove any existing styles
                  var existingStyle = document.getElementById('common-custom-style');
                  if (existingStyle) existingStyle.remove();
                  
                  // Add optimized styles
                  var style = document.createElement('style');
                  style.id = 'common-custom-style';
                  style.innerHTML = `
                    * { 
                      -webkit-transform: translateZ(0); 
                      transform: translateZ(0);
                      -webkit-backface-visibility: hidden;
                      backface-visibility: hidden;
                    }
                    body { 
                      overflow: hidden !important; 
                      margin: 0 !important; 
                      padding: 0 !important;
                      background: transparent !important;
                    }
                    iframe {
                      border: none !important;
                      background: transparent !important;
                      border-radius: 8px !important;
                    }
                    .spotifyContent {
                      border-radius: 8px !important;
                    }
                  `;
                  document.head.appendChild(style);
                  
                  // Wait for iframe to be fully loaded
                  setTimeout(function() {
                    var iframe = document.querySelector('iframe');
                    if (iframe) {
                      iframe.onload = function() {
                        console.log('CommonMusicPlayer Iframe fully loaded');
                      };
                    }
                  }, 500);
                })();
              ''');

              // WebView tam yüklendiğinde state'i güncelle
              if (mounted) {
                setState(() {
                  _isWebViewLoaded = true;
                });
              }

              // Callback'i çağır
              if (widget.webViewKey != null && widget.onWebViewLoaded != null) {
                widget.onWebViewLoaded!(widget.webViewKey!);
              }
            },
            onWebResourceError: (error) {
              print('CommonMusicPlayer WebView error: ${error.description}');
              if (mounted) {
                setState(() {
                  _isWebViewLoaded = true; // Hata durumunda da yüklenmiş say
                });
              }
              if (widget.webViewKey != null && widget.onWebViewLoaded != null) {
                widget.onWebViewLoaded!(widget.webViewKey!);
              }
            },
            onNavigationRequest: (request) {
              if (request.url.contains('spotify.com') ||
                  request.url.contains('scdn.co') ||
                  request.url.contains('spotilocal.com')) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
            },
          ),
        )
        ..loadRequest(Uri.parse(
          'https://open.spotify.com/embed/track/$spotifyId?utm_source=generator&theme=0&view=compact&show-cover=0',
        ));

      setState(() {
        _isWebViewInitialized = true;
      });
    }
  }

  // Lazy loading için WebView'ı manuel başlatma
  void startWebViewLoading() {
    if (!_isWebViewInitialized && !_hasStartedLoading) {
      _initializeWebView();
    }
  }

  Future<void> _loadUserPlaylists() async {
    if (widget.userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/${widget.userId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted && data['success'] == true) {
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
    if (widget.userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/music/${widget.track['_id']}/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': widget.userId}),
      );

      if (response.statusCode == 200 && mounted) {
        final currentLikes = widget.track['likes'] ?? 0;
        final userLikes = List<String>.from(widget.track['userLikes'] ?? []);

        if (userLikes.contains(widget.userId)) {
          userLikes.remove(widget.userId);
          widget.track['likes'] = currentLikes - 1;
        } else {
          userLikes.add(widget.userId!);
          widget.track['likes'] = currentLikes + 1;
        }
        widget.track['userLikes'] = userLikes;

        setState(() {});
        widget.onLikeChanged?.call();

        _showSnackBar('Like updated', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error liking track: $e', Colors.red);
    }
  }

  bool _isLikedByUser() {
    return widget.track['userLikes']?.contains(widget.userId) ?? false;
  }

  Future<void> _launchBeatportUrl() async {
    final url = widget.track['beatportUrl']?.toString();
    if (url == null || url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not launch Beatport link', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error launching URL: $e', Colors.red);
    }
  }

  void _showAddToPlaylistDialog() {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add to Playlist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (userPlaylists.isNotEmpty) ...[
              Text(
                'Your Playlists',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                constraints: BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: userPlaylists.length,
                  itemBuilder: (context, index) {
                    final playlist = userPlaylists[index];
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.playlist_play, color: Colors.white),
                      ),
                      title: Text(
                        playlist['name'] ?? 'Untitled',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        "${playlist['musicCount']} songs • ${playlist['genre'] ?? 'Unknown'}",
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      trailing: Icon(Icons.add, color: Colors.green),
                      onTap: () {
                        _addToExistingPlaylist(playlist['_id']);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              Divider(color: Colors.grey[700]),
              const SizedBox(height: 12),
            ],

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.add, color: Colors.white),
              ),
              title: Text(
                'Create New Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Add this song to a new playlist',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToCreatePlaylist();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToExistingPlaylist(String playlistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/music/${widget.track['_id']}/add-to-playlist'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'playlistId': playlistId,
          'userId': widget.userId,
        }),
      );

      final responseData = json.decode(response.body);
      _showSnackBar(
        responseData['message'] ?? 'Added to playlist successfully',
        response.statusCode == 200 ? Colors.green : Colors.red,
      );

      if (response.statusCode == 200) {
        await _loadUserPlaylists();
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _navigateToCreatePlaylist() async {
    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => CreatePlaylistPage(initialMusicId: widget.track['_id']),
        ),
      );

      if (result == true) {
        _showSnackBar('Playlist created successfully!', Colors.green);
        await _loadUserPlaylists();
      }
    } catch (e) {
      _showSnackBar('Error creating playlist: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildWebViewSection() {
    // WebView tamamen yüklenmemiş ise şık placeholder göster
    if (!_isWebViewInitialized || !_isWebViewLoaded) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[850]!,
              Colors.grey[900]!,
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Music note icon
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.music_note,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.track['title'] ?? 'Unknown Track',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.track['artist'] ?? 'Unknown Artist',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Loading indicator
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // WebView tamamen yüklendi - direkt göster
    return Container(
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        child: WebViewWidget(controller: _webViewController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final uniqueKey = '${widget.track['_id']}_${widget.track['spotifyId']}';

    return GestureDetector(
      onTap: () {
        // Lazy loading için WebView'ı başlat
        if (!_isWebViewInitialized && widget.lazyLoad) {
          startWebViewLoading();
        }
      },
      child: Container(
        key: ValueKey(uniqueKey),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Spotify Embed Section
            _buildWebViewSection(),

            // Action Buttons Section
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Like Button
                  GestureDetector(
                    onTap: widget.userId != null ? _toggleLike : null,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLikedByUser() ? Icons.favorite : Icons.favorite_border,
                            color: _isLikedByUser() ? Colors.red : Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.track['likes'] ?? 0}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Action Buttons Row
                  Row(
                    children: [
                      // Add to Playlist Button
                      if (widget.userId != null)
                        Container(
                          margin: EdgeInsets.only(right: 8),
                          child: IconButton(
                            onPressed: _showAddToPlaylistDialog,
                            icon: Icon(Icons.playlist_add, color: Colors.white, size: 22),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey[700],
                              shape: CircleBorder(),
                              padding: EdgeInsets.all(8),
                            ),
                          ),
                        ),

                      // Beatport Button
                      if (widget.track['beatportUrl']?.isNotEmpty == true)
                        GestureDetector(
                          onTap: _launchBeatportUrl,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade700,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/beatport_logo.png',
                                  width: 16,
                                  height: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Buy on Beatport',
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
      ),
    );
  }
}