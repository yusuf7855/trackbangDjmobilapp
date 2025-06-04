import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'url_constants.dart';

class CreatePlaylistPage extends StatefulWidget {
  final String? initialMusicId;

  const CreatePlaylistPage({Key? key, this.initialMusicId}) : super(key: key);

  @override
  _CreatePlaylistPageState createState() => _CreatePlaylistPageState();
}

class _CreatePlaylistPageState extends State<CreatePlaylistPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedGenre = 'afrohouse';
  bool _isPublic = false;
  bool _isLoading = false;
  String? _userId;

  final List<Map<String, String>> genres = [
    {'key': 'afrohouse', 'display': 'Afro House'},
    {'key': 'indiedance', 'display': 'Indie Dance'},
    {'key': 'organichouse', 'display': 'Organic House'},
    {'key': 'downtempo', 'display': 'Down Tempo'},
    {'key': 'melodichouse', 'display': 'Melodic House'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
    });
  }

  Future<void> _createPlaylist() async {
    if (_userId == null) {
      _showSnackBar('Giriş yapmanız gerekiyor');
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Lütfen playlist adı girin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        _showSnackBar('Oturum süresi dolmuş. Tekrar giriş yapın.');
        return;
      }

      print('Creating playlist with data:');
      print('- Name: ${_nameController.text.trim()}');
      print('- Genre: $_selectedGenre');
      print('- Is Public: $_isPublic');
      print('- Initial Music ID: ${widget.initialMusicId}');
      print('- User ID: $_userId');

      final requestBody = {
        'name': _nameController.text.trim(),
        'description': '', // Boş description
        'genre': _selectedGenre,
        'isPublic': _isPublic,
      };

      // Eğer başlangıç müziği varsa ekle
      if (widget.initialMusicId != null && widget.initialMusicId!.isNotEmpty) {
        requestBody['musicId'] = widget.initialMusicId as Object;
      }

      print('Request body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (mounted) {
          Navigator.of(context).pop(true);
          // Success message will be shown in the calling screen
        }
      } else {
        final errorData = json.decode(response.body);
        final error = errorData['message'] ?? 'Playlist oluşturulamadı';
        _showSnackBar(error);
        print('Create playlist error: $error');
      }
    } catch (e) {
      print('Exception creating playlist: $e');
      _showSnackBar('Hata: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildGenreChip(Map<String, String> genre) {
    final isSelected = _selectedGenre == genre['key'];

    return GestureDetector(
      onTap: () => setState(() => _selectedGenre = genre['key']!),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(right: 8, bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[800],
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.grey[600]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle, color: Colors.black, size: 16),
              SizedBox(width: 6),
            ],
            Text(
              genre['display']!,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Yeni Playlist Oluştur',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[700]!, width: 1),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.playlist_add, color: Colors.black, size: 32),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Playlist Oluştur',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Kendi müzik koleksiyonunu oluştur',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Playlist Name Section
            Text(
              'PLAYLIST ADI',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[600]!, width: 1),
              ),
              child: TextField(
                controller: _nameController,
                style: TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  hintText: 'Playlist adını girin',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                  prefixIcon: Icon(Icons.music_note, color: Colors.grey[500]),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Description Section
            Text(
              'AÇIKLAMA (İSTEĞE BAĞLI)',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[600]!, width: 1),
              ),
              child: TextField(
                controller: _descriptionController,
                style: TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 3,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  hintText: 'Playlist hakkında kısa bir açıklama',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: Icon(Icons.description, color: Colors.grey[500]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Genre Section
            Text(
              'TÜR',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              children: genres.map((genre) => _buildGenreChip(genre)).toList(),
            ),
            const SizedBox(height: 32),

            // Privacy Section
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[600]!, width: 1),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Row(
                  children: [
                    Icon(
                      _isPublic ? Icons.public : Icons.lock,
                      color: _isPublic ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Herkese Açık Playlist',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: EdgeInsets.only(left: 32, top: 4),
                  child: Text(
                    _isPublic
                        ? 'Herkes bu playlist\'i görebilir ve dinleyebilir'
                        : 'Sadece siz bu playlist\'i görebilirsiniz',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ),
                activeColor: Colors.green,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[600],
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
              ),
            ),
            const SizedBox(height: 40),

            // Create Button
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isLoading ? null : _createPlaylist,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoading) ...[
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'OLUŞTURULUYOR...',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ] else ...[
                      Icon(Icons.add_circle_outline, color: Colors.black, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'PLAYLIST OLUŞTUR',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}