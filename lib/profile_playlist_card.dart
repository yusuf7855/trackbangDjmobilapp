import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import './url_constants.dart';
import './common_music_player.dart';

class ProfilePlaylistCard extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final int index;
  final int? currentlyExpandedIndex;
  final Function(int, bool) onExpansionChanged;
  final Map<String, WebViewController> activeWebViews;
  final Map<String, List<WebViewController?>> cachedWebViews;
  final bool isCurrentUser;
  final VoidCallback? onPlaylistUpdated;

  const ProfilePlaylistCard({
    Key? key,
    required this.playlist,
    required this.index,
    required this.currentlyExpandedIndex,
    required this.onExpansionChanged,
    required this.activeWebViews,
    required this.cachedWebViews,
    required this.isCurrentUser,
    this.onPlaylistUpdated,
  }) : super(key: key);

  @override
  State<ProfilePlaylistCard> createState() => _ProfilePlaylistCardState();
}

class _ProfilePlaylistCardState extends State<ProfilePlaylistCard>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  bool _isEditMode = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _playlistMusics = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _initializePlaylistMusics();
  }

// BURAYA EKLEYİN ↓
  @override
  void didUpdateWidget(ProfilePlaylistCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Playlist verileri değiştiyse local state'i güncelle
    if (oldWidget.playlist != widget.playlist) {
      _initializePlaylistMusics();
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId') ?? prefs.getString('user_id');
    });
  }

  void _initializePlaylistMusics() {
    final musics = widget.playlist['musics'] as List<dynamic>? ?? [];
    _playlistMusics = musics.map((music) => Map<String, dynamic>.from(music)).toList();
  }

  Future<void> _toggleEditMode() async {
    if (!widget.isCurrentUser) return;

    setState(() {
      _isEditMode = !_isEditMode;
    });

    if (!_isEditMode) {
      // Çıkarken değişiklikleri kaydet
      await _savePlaylistChanges();
    }
  }

  Future<void> _savePlaylistChanges() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // Playlist'i güncelle - sadece müzik ID'lerini gönder
      final musicIds = _playlistMusics.map((music) => music['_id']).toList();

      final response = await http.put(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/${widget.playlist['_id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'musicIds': musicIds,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Playlist güncellendi', Colors.green);

        // YENİ: Playlist verilerini güncelle
        setState(() {
          // Local playlist verilerini güncelle
          widget.playlist['musics'] = List.from(_playlistMusics);
          widget.playlist['musicCount'] = _playlistMusics.length;
        });

        // Parent'a güncellendiğini bildir
        widget.onPlaylistUpdated?.call();
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(errorData['message'] ?? 'Güncelleme başarısız', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Hata: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeTrackFromPlaylist(int index) async {
    if (!widget.isCurrentUser || !_isEditMode) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Şarkıyı Kaldır', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bu şarkıyı playlist\'ten kaldırmak istediğinizden emin misiniz?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _playlistMusics.removeAt(index);
                // YENİ: Hemen local state'i güncelle
                widget.playlist['musicCount'] = _playlistMusics.length;
              });
              _showSnackBar('Şarkı kaldırıldı', Colors.orange);

              // YENİ: Parent'a değişikliği bildir
              Future.delayed(Duration(milliseconds: 300), () {
                widget.onPlaylistUpdated?.call();
              });
            },
            child: Text('Kaldır', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlaylist() async {
    if (!widget.isCurrentUser) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Playlist\'i Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bu playlist\'i kalıcı olarak silmek istediğinizden emin misiniz?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDeletePlaylist();
            },
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeletePlaylist() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.delete(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/${widget.playlist['_id']}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar('Playlist silindi', Colors.green);

        // YENİ: Üst widget'a playlist silindiğini bildir ve hemen yenile
        widget.onExpansionChanged(-1, false); // Refresh signal

        // Biraz bekle ve sonra callback'i çağır
        Future.delayed(Duration(milliseconds: 500), () {
          widget.onPlaylistUpdated?.call();
        });
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(errorData['message'] ?? 'Silme başarısız', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Hata: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.green ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isExpanded = widget.currentlyExpandedIndex == widget.index;

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: ValueKey('${widget.playlist['_id']}_${widget.index}'),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) {
          widget.onExpansionChanged(widget.index, expanded);
        },
        title: Row(
          children: [
            // Playlist icon
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: widget.playlist['isPublic'] == true
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.playlist['isPublic'] == true
                      ? Colors.green
                      : Colors.orange,
                  width: 1,
                ),
              ),
              child: Icon(
                widget.playlist['isPublic'] == true
                    ? Icons.public
                    : Icons.lock,
                color: widget.playlist['isPublic'] == true
                    ? Colors.green
                    : Colors.orange,
                size: 16,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.playlist['name'] ?? 'Untitled Playlist',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    "${_playlistMusics.length} songs • ${widget.playlist['genre'] ?? 'Unknown'}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Edit mode indicator
            if (_isEditMode)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: Text(
                  'EDIT',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: widget.isCurrentUser ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Loading indicator
            if (_isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            if (_isLoading) SizedBox(width: 8),
            // Edit button
            IconButton(
              icon: Icon(
                _isEditMode ? Icons.save : Icons.edit,
                color: _isEditMode ? Colors.green : Colors.white70,
                size: 18,
              ),
              onPressed: _isLoading ? null : _toggleEditMode,
              tooltip: _isEditMode ? 'Kaydet' : 'Düzenle',
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            // Delete button (only in edit mode)
            if (_isEditMode)
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red, size: 18),
                onPressed: _isLoading ? null : _deletePlaylist,
                tooltip: 'Playlist\'i Sil',
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            // Expansion arrow
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white70,
            ),
          ],
        ) : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white70,
            ),
          ],
        ),
        children: isExpanded ? _buildPlaylistChildren() : [],
      ),
    );
  }

  List<Widget> _buildPlaylistChildren() {
    if (_playlistMusics.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.music_off, color: Colors.grey[600], size: 32),
              SizedBox(height: 8),
              Text(
                "Bu playlist'te şarkı yok",
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
        )
      ];
    }

    return _playlistMusics.asMap().entries.map((entry) {
      final index = entry.key;
      final music = entry.value;

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Stack(
          children: [
            // Ana müzik player
            CommonMusicPlayer(
              key: ValueKey('profile_${widget.playlist['_id']}_${music['_id']}_$index'),
              track: music,
              userId: _userId,
              preloadWebView: false,
              lazyLoad: true,
              onLikeChanged: () {
                // Beğeni değiştiğinde herhangi bir işlem yapmaya gerek yok
                // Çünkü bu sadece müzik beğenisi, playlist içeriği değişmiyor
              },
            ),

            // Edit mode overlay - sadece remove butonu
            if (_isEditMode && widget.isCurrentUser)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.remove, color: Colors.white, size: 16),
                    onPressed: () => _removeTrackFromPlaylist(index),
                    tooltip: 'Şarkıyı Kaldır',
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }
}
