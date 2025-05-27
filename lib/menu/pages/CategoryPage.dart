import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../url_constants.dart';
import '../../common_music_player.dart';

class CategoryPage extends StatefulWidget {
  final String category;
  final String title;

  const CategoryPage({Key? key, required this.category, required this.title}) : super(key: key);

  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<Map<String, dynamic>> musicList = [];
  bool isLoading = true;
  String? userId;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _fetchCategoryMusic();
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });
  }

  Future<void> _fetchCategoryMusic() async {
    try {
      final response = await http.get(Uri.parse('${UrlConstants.apiBaseUrl}/api/music'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          musicList = data
              .where((item) => item['category'].toLowerCase() == widget.category.toLowerCase())
              .map((item) => ({
            'id': item['spotifyId'],
            'title': item['title'],
            'artist': item['artist'],
            'likes': item['likes'] ?? 0,
            '_id': item['_id'],
            'userLikes': item['userLikes'] ?? [],
            'beatportUrl': item['beatportUrl'] ?? '',
            'spotifyId': item['spotifyId'],
            'category': item['category'],
          }))
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load music');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.title} müzikleri yüklenirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _refreshData() {
    _fetchCategoryMusic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: 28,
        ),
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      backgroundColor: Colors.black,
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : musicList.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.title} kategorisinde şarkı bulunamadı',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          _refreshData();
        },
        color: Colors.white,
        backgroundColor: Colors.black,
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          physics: BouncingScrollPhysics(),
          itemCount: musicList.length,
          itemBuilder: (context, index) {
            final track = musicList[index];
            return Container(
              margin: EdgeInsets.only(bottom: 16),
              child: CommonMusicPlayer(
                track: track,
                userId: userId,
                onLikeChanged: _refreshData,
              ),
            );
          },
        ),
      ),
    );
  }
}