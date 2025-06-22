// lib/profile_playlist_card.dart - Complete Fixed Version

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

  // Public/Private toggle için yeni metod
  Future<void> _togglePublicPrivate() async {
    if (!widget.isCurrentUser || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // Public/Private durumunu toggle et
      final newIsPublic = !(widget.playlist['isPublic'] ?? false);

      final response = await http.put(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/${widget.playlist['_id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'isPublic': newIsPublic,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          widget.playlist['isPublic'] = newIsPublic;
        });

        _showSnackBar(
          newIsPublic ? 'Playlist herkese açık yapıldı' : 'Playlist gizli yapıldı',
          Colors.green,
        );

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

        // Local playlist verilerini güncelle
        setState(() {
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
            onPressed: () => Navigator.of(context).pop(),
            child: Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _playlistMusics.removeAt(index);
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
            onPressed: () => Navigator.of(context).pop(),
            child: Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performDeletePlaylist();
            },
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeletePlaylist() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.delete(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/${widget.playlist['_id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar('Playlist silindi', Colors.green);
        widget.onPlaylistUpdated?.call();
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          expansionTileTheme: ExpansionTileThemeData(
            tilePadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            childrenPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            iconColor: Colors.white70,
            collapsedIconColor: Colors.white70,
          ),
        ),
        child: ExpansionTile(
          key: ValueKey('${widget.playlist['_id']}_${widget.index}'),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            widget.onExpansionChanged(widget.index, expanded);
            if (expanded) {
              // Açıldığında şarkıları yeniden yükle
              setState(() {
                _initializePlaylistMusics();
              });
            }
          },
          // Modern ok ikonu ve animasyon
          trailing: AnimatedRotation(
            turns: isExpanded ? 0.5 : 0.0,
            duration: Duration(milliseconds: 200),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isExpanded
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[600]!.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: isExpanded ? Colors.white : Colors.grey[400],
                size: 18,
              ),
            ),
          ),
          title: SizedBox(
            height: 48, // Sabit yükseklik
            child: Row(
              children: [
                // Public/Private Switch Button
                if (widget.isCurrentUser)
                  GestureDetector(
                    onTap: _isLoading ? null : _togglePublicPrivate,
                    child: Container(
                      width: 28,
                      height: 18,
                      decoration: BoxDecoration(
                        color: widget.playlist['isPublic'] == true
                            ? Colors.green
                            : Colors.grey[600],
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: widget.playlist['isPublic'] == true
                              ? Colors.green[300]!
                              : Colors.grey[500]!,
                          width: 0.5,
                        ),
                      ),
                      child: AnimatedAlign(
                        duration: Duration(milliseconds: 200),
                        alignment: widget.playlist['isPublic'] == true
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 14,
                          height: 14,
                          margin: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 1,
                                offset: Offset(0, 0.5),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.playlist['isPublic'] == true
                                ? Icons.public
                                : Icons.lock,
                            size: 8,
                            color: widget.playlist['isPublic'] == true
                                ? Colors.green
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                // Read-only indicator for other users
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: widget.playlist['isPublic'] == true
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: widget.playlist['isPublic'] == true
                            ? Colors.green
                            : Colors.orange,
                        width: 0.5,
                      ),
                    ),
                    child: Icon(
                      widget.playlist['isPublic'] == true
                          ? Icons.public
                          : Icons.lock,
                      color: widget.playlist['isPublic'] == true
                          ? Colors.green
                          : Colors.orange,
                      size: 10,
                    ),
                  ),

                SizedBox(width: 8),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.playlist['name'] ?? 'Untitled Playlist',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 1),
                      Text(
                        "${_playlistMusics.length} songs • ${widget.playlist['genre'] ?? 'Unknown'}",
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                ),

                // Edit mode indicator - kompakt
                if (_isEditMode)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.orange, width: 0.5),
                    ),
                    child: Text(
                      'EDIT',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // Trailing actions area
                SizedBox(width: 8),
                SizedBox(
                  width: _isEditMode ? 80 : 40, // Sabit genişlik
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Loading indicator
                      if (_isLoading)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else if (widget.isCurrentUser) ...[
                        // Edit button
                        GestureDetector(
                          onTap: _isLoading ? null : _toggleEditMode,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _isEditMode ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              _isEditMode ? Icons.save : Icons.edit,
                              color: _isEditMode ? Colors.green : Colors.white70,
                              size: 14,
                            ),
                          ),
                        ),

                        // Delete button (only in edit mode)
                        if (_isEditMode) ...[
                          SizedBox(width: 4),
                          GestureDetector(
                            onTap: _isLoading ? null : _deletePlaylist,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          children: isExpanded ? _buildPlaylistChildren() : [],
        ),
      ),
    );
  }

  List<Widget> _buildPlaylistChildren() {
    if (_playlistMusics.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(Icons.music_off, color: Colors.grey[600], size: 24),
              SizedBox(height: 4),
              Text(
                "Bu playlist'te şarkı yok",
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
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
        margin: EdgeInsets.only(bottom: 2), // Çok minimal spacing
        child: Stack(
          children: [
            // CommonMusicPlayer - sıkıştırılmış container
            Container(
              height: 120, // Sadece Spotify frame + minimal button area
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: OverflowBox(
                  maxHeight: 156,
                  alignment: Alignment.topCenter, // Üstten hizala
                  child: Transform.translate(
                    offset: Offset(0, 0), // Offset yok
                    child: CommonMusicPlayer(
                      key: ValueKey('profile_${widget.playlist['_id']}_${music['_id']}_$index'),
                      track: music,
                      userId: _userId,
                      preloadWebView: false,
                      lazyLoad: false,
                      onLikeChanged: () {
                        // Beğeni değiştiğinde herhangi bir işlem yapmaya gerek yok
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Edit mode overlay - remove butonu
            if (_isEditMode && widget.isCurrentUser)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeTrackFromPlaylist(index),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 12,
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