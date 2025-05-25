import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'user_profile.dart';
import './url_constants.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<dynamic> users = [];
  bool isLoading = false;
  TextEditingController searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () { // Debounce süresini azalttık
      final query = searchController.text.trim();
      print('Search query changed: "$query"'); // Debug log

      if (query.isNotEmpty) {
        searchUsers(query);
      } else {
        setState(() {
          users = [];
        });
      }
    });
  }

  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        users = [];
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final url = '${UrlConstants.apiBaseUrl}/api/search?query=${Uri.encodeComponent(query)}';
      print('Making request to: $url'); // Debug log

      final response = await http.get(Uri.parse(url));

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Found ${data.length} users'); // Debug log

        setState(() {
          users = data;
          isLoading = false;
        });
      } else {
        throw Exception('Arama başarısız: ${response.statusCode}');
      }
    } catch (e) {
      print("Arama hatası: $e"); // Debug log
      setState(() {
        isLoading = false;
        users = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Arama sırasında bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getProfileImageUrl(String? profileImage) {
    if (profileImage != null && profileImage.isNotEmpty) {
      return '${UrlConstants.apiBaseUrl}$profileImage';
    }
    return 'assets/default_profile.png'; // Local asset fallback
  }

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[700]!, width: 1),
              ),
              child: TextField(
                controller: searchController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Kullanıcı ara...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Search Results
          Expanded(
            child: isLoading
                ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : users.isNotEmpty
                ? ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return _buildUserCard(user);
              },
            )
                : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  SizedBox(height: 16),
                  Text(
                    searchController.text.isEmpty
                        ? 'Kullanıcı aramak için yazmaya başlayın'
                        : 'Eşleşen kullanıcı bulunamadı',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: InkWell(
        onTap: () => _navigateToProfile(user['_id']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile Image
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[700]!, width: 2),
                ),
                child: ClipOval(
                  child: user['profileImage'] != null
                      ? Image.network(
                    _getProfileImageUrl(user['profileImage']),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[400],
                          size: 32,
                        ),
                      );
                    },
                  )
                      : Container(
                    color: Colors.grey[800],
                    child: Icon(
                      Icons.person,
                      color: Colors.grey[400],
                      size: 32,
                    ),
                  ),
                ),
              ),

              SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user['firstName']} ${user['lastName']}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '@${user['username']}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    if (user['bio'] != null && user['bio'].isNotEmpty) ...[
                      SizedBox(height: 6),
                      Text(
                        user['bio'],
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[600],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}