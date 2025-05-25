import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'url_constants.dart';
import 'playlist_card.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MyBangsScreen extends StatefulWidget {
  const MyBangsScreen({Key? key}) : super(key: key);

  @override
  State<MyBangsScreen> createState() => _MyBangsScreenState();
}

class _MyBangsScreenState extends State<MyBangsScreen> {
  List<Map<String, dynamic>> _privatePlaylists = [];
  List<Map<String, dynamic>> _filteredPlaylists = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _userId;
  int? _currentlyExpandedIndex;
  final Map<String, WebViewController> _activeWebViews = {};
  final Map<String, List<WebViewController>> _playlistWebViewCache = {};
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _activeWebViews.clear();
    _playlistWebViewCache.clear();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (userId != null) {
      setState(() => _userId = userId);
      await _fetchPrivatePlaylists();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPrivatePlaylists() async {
    if (_userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/$_userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && mounted) {
          final playlists = (responseData['playlists'] as List)
              .map((item) => _mapPlaylistItem(item))
              .where((playlist) => playlist['isPublic'] == false)
              .toList();

          if (mounted) {
            setState(() {
              _privatePlaylists = playlists;
              _filteredPlaylists = List.from(playlists);
              _isLoading = false;
            });
          }

          _updateWebViewCache();
        } else {
          _handleError("Sunucu hatası");
        }
      } else {
        _handleError("Playlist alınamadı (${response.statusCode})");
      }
    } catch (e) {
      _handleError("İnternet bağlantısı hatası: ${e.toString()}");
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }


  void _updateWebViewCache() {
    final activePlaylistIds = _filteredPlaylists.map((p) => p['_id']).toSet();

    _playlistWebViewCache.removeWhere((key, _) => !activePlaylistIds.contains(key));
    _activeWebViews.removeWhere((key, _) {
      final playlistId = key.split('-').first;
      return !activePlaylistIds.contains(playlistId);
    });
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        setState(() {
          _filteredPlaylists = List.from(_privatePlaylists);
          _isSearching = false;
        });
        _updateWebViewCache();
      } else {
        _searchPrivatePlaylists(query);
      }
    });
  }


  Future<void> _searchPrivatePlaylists(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _filteredPlaylists = List.from(_privatePlaylists);
        _updateWebViewCache();
      });
      return;
    }

    try {
      setState(() => _isSearching = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse(
            '${UrlConstants.apiBaseUrl}/api/playlists/search-private?query=$encodedQuery&userId=$_userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && mounted) {
          setState(() {
            _isSearching = false;
            _filteredPlaylists = (responseData['playlists'] as List)
                .map((p) => _mapPlaylistItem(p))
                .toList();
            _updateWebViewCache();
          });
        }
      } else {
        _localSearch(query);
      }
    } catch (e) {
      _localSearch(query);
    }
  }

  void _localSearch(String query) {
    final q = query.toLowerCase();
    final filtered = _privatePlaylists.where((playlist) {
      return (playlist['name'] ?? '').toString().toLowerCase().contains(q) ||
          (playlist['description'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    setState(() {
      _filteredPlaylists = filtered;
      _isSearching = false;
    });

    _updateWebViewCache();
  }


  Map<String, dynamic> _mapPlaylistItem(dynamic item) {
    return {
      '_id': item['_id'],
      'name': item['name'],
      'description': item['description'] ?? '',
      'musicCount': item['musicCount'] ?? 0,
      'genre': item['genre'] ?? 'other',
      'isPublic': item['isPublic'] ?? false,
      'musics': item['musics'] ?? [],
    };
  }

  void _handleExpansionChanged(int index, bool expanded) {
    setState(() {
      _currentlyExpandedIndex = expanded ? index : null;
      if (!expanded) {
        final playlistId = _filteredPlaylists[index]['_id'];
        _activeWebViews.removeWhere((key, _) => key.startsWith(playlistId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(


      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                hintText: 'Özel playlistlerde ara...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : _isSearching
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : _filteredPlaylists.isEmpty
                ? Center(
              child: Text(
                _searchController.text.isEmpty
                    ? 'Özel playlist bulunamadı'
                    : 'Eşleşen playlist bulunamadı',
                style: const TextStyle(color: Colors.white70),
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchPrivatePlaylists,
              color: Colors.white,
              backgroundColor: Colors.black,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _filteredPlaylists.length,
                itemBuilder: (context, index) {
                  return PlaylistCard(
                    playlist: _filteredPlaylists[index],
                    index: index,
                    currentlyExpandedIndex: _currentlyExpandedIndex,
                    onExpansionChanged: _handleExpansionChanged,
                    activeWebViews: _activeWebViews,
                    cachedWebViews: _playlistWebViewCache,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}