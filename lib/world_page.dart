import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import '../url_constants.dart';
import '../common_music_player.dart';

class WorldPage extends StatefulWidget {
  final String? userId;

  const WorldPage({Key? key, this.userId}) : super(key: key);

  @override
  State<WorldPage> createState() => _WorldPageState();
}

class _WorldPageState extends State<WorldPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> worldPlaylists = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Cache for expanded playlists - removed WebView cache as we'll use CommonMusicPlayer
  final Map<String, bool> _expandedStates = {};

  @override
  void initState() {
    super.initState();
    _loadWorldPlaylists();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadWorldPlaylists() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/public-world'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          final playlists = data['playlists'] ?? [];

          // Pre-process playlists
          await _preprocessPlaylists(playlists);

          setState(() {
            worldPlaylists = playlists;
            isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load playlists: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _preprocessPlaylists(List<dynamic> playlists) async {
    for (final playlist in playlists) {
      final playlistId = playlist['_id']?.toString();
      if (playlistId == null) continue;

      // Initialize expanded state
      _expandedStates[playlistId] = false;
    }
  }


  void _onExpansionChanged(String playlistId, bool expanded) {
    if (!mounted) return;

    setState(() {
      _expandedStates[playlistId] = expanded;
    });
  }

  Widget _buildPlaylistCard(Map<String, dynamic> playlist) {
    final playlistId = playlist['_id']?.toString() ?? '';
    final musics = playlist['musics'] as List<dynamic>? ?? [];
    final owner = playlist['owner'] as Map<String, dynamic>?;
    final isExpanded = _expandedStates[playlistId] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: ExpansionTile(
        key: ValueKey(playlistId),
        tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: EdgeInsets.only(bottom: 16),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white70,
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) => _onExpansionChanged(playlistId, expanded),
        title: Text(
          playlist['name'] ?? 'Unnamed Playlist',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (owner != null)
              Text(
                'by ${owner['displayName'] ?? owner['username'] ?? 'Unknown'}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.music_note, color: Colors.grey[400], size: 16),
                const SizedBox(width: 4),
                Text(
                  '${playlist['musicCount'] ?? musics.length} songs',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Icon(Icons.category, color: Colors.grey[400], size: 16),
                const SizedBox(width: 4),
                Text(
                  playlist['genre'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        children: [
          if (musics.isNotEmpty && isExpanded)
            ...musics.map((music) {
              return CommonMusicPlayer(
                track: music,
                userId: widget.userId,
                onLikeChanged: () {
                  // Refresh callback if needed - we can add state refresh here
                  _loadWorldPlaylists();
                },
              );
            }).toList()
          else if (musics.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
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
    super.build(context);

    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Loading World Playlists...',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
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
                'Failed to load playlists',
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
                onPressed: _loadWorldPlaylists,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (worldPlaylists.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.playlist_remove,
                color: Colors.grey[600],
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'No world playlists found',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Check back later for new content',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _loadWorldPlaylists,
        color: Colors.white,
        backgroundColor: Colors.black,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final playlist = worldPlaylists[index];
                  return _buildPlaylistCard(playlist);
                },
                childCount: worldPlaylists.length,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 100), // Bottom padding
            ),
          ],
        ),
      ),
    );
  }
}