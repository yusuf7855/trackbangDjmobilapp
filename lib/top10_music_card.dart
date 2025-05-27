import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import './url_constants.dart';

class Top10MusicCard extends StatefulWidget {
  final Map<String, dynamic> track;
  final int rank;
  final String? userId;
  final VoidCallback? onLikeChanged;
  final String? webViewKey;
  final Function(String)? onWebViewLoaded;
  final bool preloadWebView; // Yeni parametre

  const Top10MusicCard({
    Key? key,
    required this.track,
    required this.rank,
    this.userId,
    this.onLikeChanged,
    this.webViewKey,
    this.onWebViewLoaded,
    this.preloadWebView = false, // Default false
  }) : super(key: key);

  @override
  State<Top10MusicCard> createState() => _Top10MusicCardState();
}

class _Top10MusicCardState extends State<Top10MusicCard>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {

  late WebViewController _webViewController;
  bool _isWebViewInitialized = false;
  bool _isWebViewLoaded = false; // WebView tam yüklenme durumu
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

    // Preload durumunda hemen WebView'ı başlat
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
      print('Spotify ID changed from $_currentSpotifyId to $newSpotifyId - Reloading WebView');
      _isWebViewLoaded = false; // Reset loaded state
      _initializeWebView();
    }

    if (oldWidget.rank != widget.rank) {
      print('Rank changed from ${oldWidget.rank} to ${widget.rank}');
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
    print('Initializing WebView for track: ${widget.track['title']} with Spotify ID: $spotifyId');

    if (spotifyId != null && spotifyId.isNotEmpty) {
      _currentSpotifyId = spotifyId;

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1')
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              print('WebView started loading: $url');
            },
            onPageFinished: (url) async {
              print('WebView loaded: $url for track: ${widget.track['title']}');

              // CSS ve JavaScript optimizasyonları
              await _webViewController.runJavaScript('''
                (function() {
                  // Remove any existing styles
                  var existingStyle = document.getElementById('custom-style');
                  if (existingStyle) existingStyle.remove();
                  
                  // Add optimized styles
                  var style = document.createElement('style');
                  style.id = 'custom-style';
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
                        console.log('Iframe fully loaded');
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
              print('WebView error: ${error.description}');
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

      if (mounted) {
        setState(() {
          _isWebViewInitialized = true;
        });
      }
    }
  }

  // Lazy loading için WebView'ı manuel başlatma
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[900]!,
              Colors.black,
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (userPlaylists.isNotEmpty) ...[
              Text(
                'Your Playlists',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              Container(
                constraints: BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.grey[800]?.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[600]!, width: 0.5),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: userPlaylists.length,
                  itemBuilder: (context, index) {
                    final playlist = userPlaylists[index];
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[700]?.withOpacity(0.5),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue, Colors.purple],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.playlist_play, color: Colors.white, size: 24),
                        ),
                        title: Text(
                          playlist['name'] ?? 'Untitled',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          "${playlist['musicCount']} songs • ${playlist['genre'] ?? 'Unknown'}",
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                        trailing: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                        onTap: () {
                          _addToExistingPlaylist(playlist['_id']);
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),
              Divider(color: Colors.grey[600]),
              const SizedBox(height: 16),
            ],

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green, Colors.teal],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, color: Colors.white, size: 24),
                ),
                title: Text(
                  'Create New Playlist',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'Add this song to a new playlist',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _navigateToCreatePlaylist();
                },
              ),
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
    _showSnackBar('Create playlist feature available in main music section', Colors.blue);
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
          badgeColor = Color(0xFFFFD700);
          textColor = Colors.black;
          icon = Icons.emoji_events;
          break;
        case 2:
          badgeColor = Color(0xFFC0C0C0);
          textColor = Colors.black;
          icon = Icons.emoji_events;
          break;
        case 3:
          badgeColor = Color(0xFFCD7F32);
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
    // WebView tamamen yüklenmemiş ise şık placeholder göster
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
              // Rank badge mini version
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

    // WebView tamamen yüklendi - direkt göster
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
        // Lazy loading için WebView'ı başlat
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

            // Action Buttons
            Container(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Like Button
                  if (widget.userId != null)
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isLikedByUser() ? Colors.red : Colors.grey[700],
                          borderRadius: BorderRadius.circular(20),
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
                          children: [
                            Icon(
                              _isLikedByUser() ? Icons.favorite : Icons.favorite_border,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.track['likes'] ?? 0}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Add to Playlist Button
                  if (widget.userId != null)
                    GestureDetector(
                      onTap: _showAddToPlaylistDialog,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(Icons.playlist_add, color: Colors.white, size: 18),
                      ),
                    ),

                  // Beatport Button
                  if (widget.track['beatportUrl']?.isNotEmpty == true)
                    GestureDetector(
                      onTap: _launchBeatportUrl,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
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
                              'Beatport',
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