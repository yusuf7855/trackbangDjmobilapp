import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {

  late WebViewController _webViewController;
  bool _isWebViewInitialized = false;
  bool _isWebViewLoaded = false;
  List<Map<String, dynamic>> userPlaylists = [];
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  String? _currentSpotifyId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();

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

    if (oldWidget.rank != widget.rank) {
      print('Top10MusicCard: Rank changed from ${oldWidget.rank} to ${widget.rank}');
      _restartPulseAnimation();
    }
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.rank <= 3) {
      _animationController.repeat(reverse: true);
    }
  }

  void _restartPulseAnimation() {
    if (widget.rank <= 3) {
      _animationController.reset();
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.reset();
    }
  }

  void _initializeWebView() {
    final spotifyId = widget.track['spotifyId']?.toString();
    print('Top10MusicCard: Initializing WebView for track: ${widget.track['title']} with Spotify ID: $spotifyId');

    if (spotifyId != null && spotifyId.isNotEmpty) {
      _currentSpotifyId = spotifyId;

      _webViewController = WebViewController()
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

              await _webViewController.runJavaScript('''
                (function() {
                  var existingStyle = document.getElementById('top10-custom-style');
                  if (existingStyle) existingStyle.remove();
                  
                  var style = document.createElement('style');
                  style.id = 'top10-custom-style';
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
                        console.log('Top10MusicCard Iframe fully loaded');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildRankBadge() {
    Color badgeColor;
    Color textColor;
    IconData? icon;
    bool hasGlow = false;

    if (widget.rank <= 3) {
      hasGlow = true;
      switch (widget.rank) {
        case 1:
          badgeColor = Color(0xFFFFD700); // Gold
          textColor = Colors.black;
          icon = Icons.emoji_events;
          break;
        case 2:
          badgeColor = Color(0xFFC0C0C0); // Silver
          textColor = Colors.black;
          icon = Icons.emoji_events;
          break;
        case 3:
          badgeColor = Color(0xFFCD7F32); // Bronze
          textColor = Colors.white;
          icon = Icons.emoji_events;
          break;
        default:
          badgeColor = Colors.grey[800]!;
          textColor = Colors.white;
      }
    } else {
      badgeColor = Colors.grey[800]!;
      textColor = Colors.white;
    }

    Widget badge = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.rank <= 3 ? Colors.white : Colors.grey[600]!,
          width: 2,
        ),
        boxShadow: hasGlow ? [
          BoxShadow(
            color: badgeColor.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ] : null,
      ),
      child: widget.rank <= 3 && icon != null
          ? Icon(icon, color: textColor, size: 24)
          : Center(
        child: Text(
          widget.rank.toString(),
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );

    if (widget.rank <= 3) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: badge,
          );
        },
      );
    }

    return badge;
  }

  Widget _buildWebViewSection() {
    if (!_isWebViewInitialized || !_isWebViewLoaded) {
      return Container(
        height: 80,
        margin: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[700]!, width: 1),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.rank <= 3
                      ? Colors.amber.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.rank.toString(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  valueColor: AlwaysStoppedAnimation<Color>(
                      widget.rank <= 3
                          ? Colors.amber.withOpacity(0.7)
                          : Colors.white.withOpacity(0.7)
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 80,
      margin: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: WebViewWidget(controller: _webViewController),
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.rank <= 3
                ? [
              Colors.grey[850]!,
              Colors.grey[900]!,
              Colors.black,
            ]
                : [
              Colors.grey[900]!,
              Colors.black,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.rank <= 3
                ? Colors.amber.withOpacity(0.3)
                : Colors.grey[700]!,
            width: widget.rank <= 3 ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.rank <= 3
                  ? Colors.amber.withOpacity(0.1)
                  : Colors.black.withOpacity(0.3),
              blurRadius: widget.rank <= 3 ? 12 : 6,
              offset: Offset(0, widget.rank <= 3 ? 4 : 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with rank and track info
            Container(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildRankBadge(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.track['title'] ?? 'Unknown Track',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: widget.track['artist'] ?? 'Unknown Artist',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: ' • ',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: widget.track['category'] ?? 'Unknown',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Spotify Embed Section
            _buildWebViewSection(),

            // Action Buttons - Responsive Layout
            Container(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  // Like Button
                  if (widget.userId != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: _toggleLike,
                        child: Container(
                          margin: EdgeInsets.only(right: 6),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isLikedByUser() ? Colors.red.withOpacity(0.15) : Colors.grey[700],
                            borderRadius: BorderRadius.circular(20),
                            border: _isLikedByUser()
                                ? Border.all(color: Colors.red.withOpacity(0.4), width: 1)
                                : null,
                            boxShadow: _isLikedByUser() ? [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isLikedByUser() ? Icons.favorite : Icons.favorite_border,
                                color: _isLikedByUser() ? Colors.red : Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.track['likes'] ?? 0}',
                                style: TextStyle(
                                  color: _isLikedByUser() ? Colors.red : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
                          margin: EdgeInsets.symmetric(horizontal: 3),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.2),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.playlist_add, color: Colors.blue, size: 16),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Lista',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
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
                          margin: EdgeInsets.only(left: 6),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/beatport_logo.png',
                                width: 14,
                                height: 14,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Buy',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
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
    _animationController.dispose();
    super.dispose();
  }
}