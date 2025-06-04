import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import './url_constants.dart';
import './standardized_playlist_dialog.dart';
import './create_playlist.dart';

class Top10MusicCard extends StatefulWidget {
  final Map<String, dynamic> track;
  final int rank;
  final String? userId;
  final VoidCallback? onLikeChanged;
  final String? webViewKey;
  final Function(String)? onWebViewLoaded;
  final bool preloadWebView;

  const Top10MusicCard({
    Key? key,
    required this.track,
    required this.rank,
    this.userId,
    this.onLikeChanged,
    this.webViewKey,
    this.onWebViewLoaded,
    this.preloadWebView = false,
  }) : super(key: key);

  @override
  State<Top10MusicCard> createState() => _Top10MusicCardState();
}

class _Top10MusicCardState extends State<Top10MusicCard>
    with AutomaticKeepAliveClientMixin {

  late WebViewController _webViewController;
  bool _isWebViewInitialized = false;
  bool _isWebViewLoaded = false;
  List<Map<String, dynamic>> userPlaylists = [];
  String? _currentSpotifyId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    if (widget.preloadWebView) {
      _initializeWebView();
    }

    if (widget.userId != null) {
      _loadUserPlaylists();
    }
  }

  @override
  void didUpdateWidget(Top10MusicCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newSpotifyId = widget.track['spotifyId']?.toString();
    if (newSpotifyId != _currentSpotifyId) {
      print('Top10MusicCard: Spotify ID changed from $_currentSpotifyId to $newSpotifyId - Reloading WebView');
      _isWebViewLoaded = false;
      _initializeWebView();
    }
  }

  void _initializeWebView() {
    final spotifyId = widget.track['spotifyId']?.toString();
    print('Top10MusicCard: Initializing WebView for track: ${widget.track['title']} with Spotify ID: $spotifyId');

    if (spotifyId != null && spotifyId.isNotEmpty) {
      _currentSpotifyId = spotifyId;

      late final PlatformWebViewControllerCreationParams params;
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      _webViewController = WebViewController.fromPlatformCreationParams(params)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1')
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              print('Top10MusicCard WebView started loading: $url');
            },
            onPageFinished: (url) async {
              print('Top10MusicCard WebView loaded: $url for track: ${widget.track['title']}');

              try {
                await _webViewController.runJavaScript('''
                  (function() {
                    var existingStyle = document.getElementById('top10-custom-style');
                    if (existingStyle) existingStyle.remove();
                    
                    var style = document.createElement('style');
                    style.id = 'top10-custom-style';
                    style.innerHTML = \`
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
                    \`;
                    document.head.appendChild(style);
                    
                    setTimeout(function() {
                      var iframe = document.querySelector('iframe');
                      if (iframe) {
                        iframe.onload = function() {
                          console.log('Top10MusicCard Iframe fully loaded');
                        };
                      }
                    }, 500);
                  })();
                ''');
              } catch (e) {
                print('JavaScript execution error: $e');
              }

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
              print('Top10MusicCard WebView error: ${error.description}');
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

      if (_webViewController.platform is AndroidWebViewController) {
        AndroidWebViewController.enableDebugging(true);
        (_webViewController.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }

      if (mounted) {
        setState(() {
          _isWebViewInitialized = true;
        });
      }
    }
  }

  void startWebViewLoading() {
    if (!_isWebViewInitialized && !widget.preloadWebView) {
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
        widget.onLikeChanged?.call();
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
        height: 85,
        margin: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[800]!, width: 1),
        ),
        child: Stack(
          children: [
            // Rank badge positioned in top-left
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[600]!, width: 1),
                ),
                child: Center(
                  child: Text(
                    widget.rank.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
            ),
            // Loading indicator
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 85,
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Stack(
        children: [
          // WebView
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: WebViewWidget(controller: _webViewController),
          ),
          // Rank badge positioned in top-left
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[600]!, width: 1),
              ),
              child: Center(
                child: Text(
                  widget.rank.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 8,
                  ),
                ),
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

    final uniqueKey = '${widget.track['_id']}_${widget.rank}_${widget.track['spotifyId']}';

    return GestureDetector(
      onTap: () {
        if (!_isWebViewInitialized) {
          startWebViewLoading();
        }
      },
      child: Container(
        key: ValueKey(uniqueKey),
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
        child: Column(
          children: [
            // Spotify Embed Section
            _buildWebViewSection(),

            // Action Buttons - Ultra compact
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                children: [
                  // Like Button
                  if (widget.userId != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: _toggleLike,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          margin: EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: _isLikedByUser()
                                ? Colors.red.withOpacity(0.15)
                                : Colors.grey[700]?.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
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
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${widget.track['likes'] ?? 0}',
                                style: TextStyle(
                                  color: _isLikedByUser() ? Colors.red : Colors.white70,
                                  fontSize: 10,
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
                                  'Add to Playlist',
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

                  // Beatport Button
                  if (widget.track['beatportUrl']?.isNotEmpty == true)
                    Expanded(
                      child: GestureDetector(
                        onTap: _launchBeatportUrl,
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
                                width: 10,
                                height: 10,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  'Buy on Beatport',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}