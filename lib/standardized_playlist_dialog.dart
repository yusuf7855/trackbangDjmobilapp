import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import './url_constants.dart';

class StandardizedPlaylistDialog extends StatefulWidget {
  final Map<String, dynamic> track;
  final String? userId;
  final List<Map<String, dynamic>> userPlaylists;
  final VoidCallback? onPlaylistsUpdated;

  const StandardizedPlaylistDialog({
    Key? key,
    required this.track,
    this.userId,
    required this.userPlaylists,
    this.onPlaylistsUpdated,
  }) : super(key: key);

  @override
  State<StandardizedPlaylistDialog> createState() => _StandardizedPlaylistDialogState();
}

class _StandardizedPlaylistDialogState extends State<StandardizedPlaylistDialog> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _playlists = [];

  // Çoklu sanatçı desteği için helper method
  String _getDisplayArtists() {
    // 1. displayArtists varsa onu kullan (backend'den gelen hazır format)
    if (widget.track['displayArtists'] != null &&
        widget.track['displayArtists'].toString().isNotEmpty) {
      return widget.track['displayArtists'].toString();
    }

    // 2. artists array varsa onu birleştir
    if (widget.track['artists'] != null &&
        widget.track['artists'] is List &&
        (widget.track['artists'] as List).isNotEmpty) {
      final artistsList = widget.track['artists'] as List;
      return artistsList
          .where((artist) => artist != null && artist.toString().trim().isNotEmpty)
          .map((artist) => artist.toString().trim())
          .join(', ');
    }

    // 3. Eski tek sanatçı field'i varsa onu kullan (backward compatibility)
    if (widget.track['artist'] != null &&
        widget.track['artist'].toString().trim().isNotEmpty) {
      return widget.track['artist'].toString().trim();
    }

    // 4. Hiçbiri yoksa default
    return 'Unknown Artist';
  }

  @override
  void initState() {
    super.initState();
    _playlists = List.from(widget.userPlaylists);
  }

  Future<void> _addToPlaylist(String playlistId, String playlistName) async {
    if (widget.userId == null) {
      _showSnackBar('Giriş yapmanız gerekiyor', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        _showSnackBar('Oturum süresi dolmuş. Tekrar giriş yapın.', Colors.red);
        return;
      }

      final musicId = widget.track['_id']?.toString() ?? widget.track['id']?.toString();
      if (musicId == null) {
        _showSnackBar('Müzik ID\'si bulunamadı', Colors.red);
        return;
      }

      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/$playlistId/add-music'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'musicId': musicId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showSnackBar('Şarkı "$playlistName" playlist\'ine eklendi', Colors.green);
          widget.onPlaylistsUpdated?.call();
          Navigator.of(context).pop();
        } else {
          _showSnackBar(data['message'] ?? 'Ekleme başarısız', Colors.red);
        }
      } else if (response.statusCode == 409) {
        final data = json.decode(response.body);
        _showSnackBar(data['message'] ?? 'Bu şarkı zaten playlist\'te mevcut', Colors.orange);
      } else {
        _showSnackBar('Sunucu hatası: ${response.statusCode}', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Bağlantı hatası: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showCreateNewPlaylist() {
    Navigator.of(context).pop(); // Close current dialog

    // Navigate to create playlist page with this track
    Navigator.pushNamed(
      context,
      '/create_playlist',
      arguments: {
        'initialMusicId': widget.track['_id']?.toString() ?? widget.track['id']?.toString(),
      },
    ).then((_) {
      widget.onPlaylistsUpdated?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayArtists = _getDisplayArtists();
    final title = widget.track['title']?.toString() ?? 'Unknown Title';

    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.playlist_add,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Playlist\'e Ekle',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Şarkıyı bir playlist\'e ekleyin',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Track info
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.music_note, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                displayArtists,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                                maxLines: 2, // Çoklu sanatçı için 2 satır
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: Column(
                children: [
                  // Create new playlist option
                  Container(
                    margin: EdgeInsets.all(16),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showCreateNewPlaylist,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Yeni Playlist Oluştur',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Bu şarkıyla yeni bir playlist oluşturun',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.orange,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Existing playlists
                  if (_playlists.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            'Mevcut Playlistler',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_playlists.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),

                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = _playlists[index];
                          final isPrivate = playlist['isPublic'] != true;

                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isLoading ? null : () {
                                  _addToPlaylist(
                                    playlist['_id']?.toString() ?? '',
                                    playlist['name']?.toString() ?? 'Unnamed Playlist',
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[850],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isPrivate ? Icons.lock : Icons.queue_music,
                                        color: isPrivate ? Colors.grey[600] : Colors.blue,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              playlist['name']?.toString() ?? 'Unnamed Playlist',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (playlist['description'] != null &&
                                                playlist['description'].toString().isNotEmpty) ...[
                                              Text(
                                                playlist['description'].toString(),
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ] else ...[
                                              Text(
                                                '${playlist['musicCount'] ?? 0} şarkı',
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (_isLoading) ...[
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                          ),
                                        ),
                                      ] else ...[
                                        Icon(
                                          Icons.add_circle_outline,
                                          color: Colors.grey[400],
                                          size: 20,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    // No playlists state
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.playlist_add_outlined,
                            color: Colors.grey[600],
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Henüz playlist\'iniz yok',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'İlk playlist\'inizi oluşturmak için yukarıdaki butona tıklayın',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}