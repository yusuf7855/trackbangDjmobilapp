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
  String _selectedGenre = 'pop';
  bool _isPublic = false;
  bool _isLoading = false;
  String? _userId;

  final List<String> genres = [
    'pop', 'rock', 'hiphop', 'jazz',
    'classical', 'electronic', 'rnb', 'country', 'other'
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
      _showSnackBar('Please login to create a playlist');
      return;
    }

    if (_nameController.text.isEmpty) {
      _showSnackBar('Please enter a playlist name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': _nameController.text,
          'musicId': widget.initialMusicId,
          'genre': _selectedGenre,
          'isPublic': _isPublic,
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pop(true);
          // Show success message in the previous screen
        }
      } else {
        final error = json.decode(response.body)['message'] ?? 'Failed to create playlist';
        _showSnackBar(error);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Create New Playlist',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PLAYLIST NAME',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _nameController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  hintText: 'Enter playlist name',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'GENRE',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: genres.map((genre) {
                return ChoiceChip(
                  label: Text(
                    genre,
                    style: TextStyle(
                      color: _selectedGenre == genre
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                  selected: _selectedGenre == genre,
                  selectedColor: Colors.white,
                  backgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (selected) {
                    setState(() => _selectedGenre = genre);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                title: Text(
                  'Public Playlist',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _isPublic
                      ? 'Visible to everyone'
                      : 'Only visible to you',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                activeColor: Colors.white,
                inactiveTrackColor: Colors.grey[600],
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _createPlaylist,
                child: Text(
                  'CREATE PLAYLIST',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}