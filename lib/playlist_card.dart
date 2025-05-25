import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class PlaylistCard extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final int index;
  final int? currentlyExpandedIndex;
  final Function(int, bool) onExpansionChanged;
  final Map<String, WebViewController> activeWebViews;
  final Map<String, List<WebViewController?>> cachedWebViews;

  const PlaylistCard({
    Key? key,
    required this.playlist,
    required this.index,
    required this.currentlyExpandedIndex,
    required this.onExpansionChanged,
    required this.activeWebViews,
    required this.cachedWebViews,
  }) : super(key: key);

  @override
  State<PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<PlaylistCard> with AutomaticKeepAliveClientMixin {
  late List<WebViewController?> _webViewControllers;
  bool _isInitialized = false;
  bool _isExpanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.currentlyExpandedIndex == widget.index;
    _initializeWebViews();
  }

  void _initializeWebViews() {
    final playlistId = widget.playlist['_id'];

    // Önbellekte varsa al
    if (widget.cachedWebViews.containsKey(playlistId)) {
      _webViewControllers = widget.cachedWebViews[playlistId]!;
      _isInitialized = true;
      return;
    }

    final musics = widget.playlist['musics'] as List<dynamic>?;

    if (musics == null || musics.isEmpty) {
      _webViewControllers = [];
      _isInitialized = true;
      return;
    }

    _webViewControllers = List<WebViewController?>.filled(musics.length, null);

    for (int i = 0; i < musics.length; i++) {
      final music = musics[i] as Map<String, dynamic>;
      final spotifyId = music['spotifyId']?.toString();
      final uniqueKey = '$playlistId-$i';

      if (spotifyId != null) {
        _createWebViewController(spotifyId, uniqueKey).then((controller) {
          if (mounted) {
            setState(() {
              _webViewControllers[i] = controller;
              if (_webViewControllers.every((c) => c != null)) {
                _isInitialized = true;
                widget.cachedWebViews[playlistId] = List.from(_webViewControllers);
              }
            });
          }
        });
      } else {
        _webViewControllers[i] = null;
        if (i == musics.length - 1) _isInitialized = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: ValueKey('${widget.playlist['_id']}_${widget.index}'),
        initiallyExpanded: widget.currentlyExpandedIndex == widget.index,
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
          widget.onExpansionChanged(widget.index, expanded);
        },
        title: Text(
          widget.playlist['name'] ?? 'Untitled Playlist',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        subtitle: Text(
          "${widget.playlist['musicCount'] ?? 0} songs",
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        children: _isExpanded ? _buildPlaylistChildren() : [],
      ),
    );
  }

  List<Widget> _buildPlaylistChildren() {
    final musics = widget.playlist['musics'] as List<dynamic>?;

    if (!_isInitialized || musics == null || musics.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "No songs in this playlist",
            style: TextStyle(color: Colors.grey),
          ),
        )
      ];
    }

    return List.generate(musics.length, (index) {
      return _buildMusicPlayer(musics[index] as Map<String, dynamic>, index);
    });
  }

  Widget _buildMusicPlayer(Map<String, dynamic> music, int index) {
    final controller = _webViewControllers[index];
    final spotifyId = music['spotifyId']?.toString();

    if (controller == null || spotifyId == null) {
      return Container(
        height: 60,
        color: Colors.grey[800],
        child: ListTile(
          leading: const Icon(Icons.music_note, color: Colors.white70),
          title: Text(
            music['title'] ?? 'Unknown Track',
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            music['artist'] ?? 'Unknown Artist',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 80,
        child: WebViewWidget(controller: controller),
      ),
    );
  }

  Future<WebViewController> _createWebViewController(String spotifyId, String uniqueKey) async {
    late final PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => NavigationDecision.navigate,
        ),
      )
      ..loadRequest(Uri.parse('https://open.spotify.com/embed/track/$spotifyId'));

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    widget.activeWebViews[uniqueKey] = controller;
    return controller;
  }

  @override
  void dispose() {
    final playlistId = widget.playlist['_id'];
    if (!widget.cachedWebViews.containsKey(playlistId)) {
      for (int i = 0; i < _webViewControllers.length; i++) {
        final uniqueKey = '$playlistId-$i';
        widget.activeWebViews.remove(uniqueKey);
      }
    }
    super.dispose();
  }
}
