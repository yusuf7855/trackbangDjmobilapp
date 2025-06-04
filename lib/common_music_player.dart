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
        ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1')
        ..enableZoom(false)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              print('CommonMusicPlayer WebView started loading: $url');
            },
            onPageFinished: (url) async {
              print('CommonMusicPlayer WebView loaded: $url for track: ${widget.track['title']}');

              await _webViewController.runJavaScript('''
                (function() {
                  var existingStyle = document.getElementById('common-custom-style');
                  if (existingStyle) existingStyle.remove();
                  
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

              if (mounted) {
                setState(() {
                  _isWebViewLoaded = true;
                });
              }

              if (widget.webViewKey != null && widget.onWebViewLoaded != null) {
                widget.onWebViewLoaded!(widget.webViewKey!);
              }
            },
            onWebResourceError: (error) {
              print('CommonMusicPlayer WebView error: ${error.description}');
              if (mounted) {
                setState(() {
                  _isWebViewLoaded = true;
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
    StandardizedPlaylistDialog.show(
      context: context,
      track: widget.track,
      userId: widget.userId,
      onPlaylistUpdated: () {
        _loadUserPlaylists();
        widget.onLikeChanged?.call();
      },
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

            // Action Bar - Compact and Responsive
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey[700]!, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Like Button
                  if (widget.userId != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: _toggleLike,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: _isLikedByUser()
                                ? Colors.red.withOpacity(0.15)
                                : Colors.grey[700]?.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: _isLikedByUser()
                                ? Border.all(color: Colors.red.withOpacity(0.4), width: 1)
                                : Border.all(color: Colors.grey[600]!, width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isLikedByUser() ? Icons.favorite : Icons.favorite_border,
                                color: _isLikedByUser() ? Colors.red : Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.track['likes'] ?? 0}',
                                style: TextStyle(
                                  color: _isLikedByUser() ? Colors.red : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Add to Playlist Button
                  if (widget.userId != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: _showAddToPlaylistDialog,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.playlist_add,
                                color: Colors.blue,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Lista',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 10,
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

                  // Beatport Button
                  if (widget.track['beatportUrl']?.isNotEmpty == true)
                    Expanded(
                      child: GestureDetector(
                        onTap: _launchBeatportUrl,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/beatport_logo.png',
                                width: 12,
                                height: 12,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Buy',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}