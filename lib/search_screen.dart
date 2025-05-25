import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile.dart';
import './url_constants.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAllUsers();
  }

  Future<void> fetchAllUsers() async {
    try {
      final response = await http.get(Uri.parse('${UrlConstants.apiBaseUrl}/api/search?query='));

      if (response.statusCode == 200) {
        setState(() {
          users = json.decode(response.body);
          filteredUsers = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print("Hata: $e");
      setState(() => isLoading = false);
    }
  }

  void filterUsers(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        filteredUsers = [];
      });
      return;
    }

    setState(() {
      filteredUsers = users.where((user) {
        final name = '${user['firstName']} ${user['lastName']}'.toLowerCase();
        final username = user['username']?.toLowerCase() ?? '';
        return name.contains(query.toLowerCase()) || username.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              style: TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Kullanıcı ara...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: filterUsers,
            ),
          ),
        ),

        // Search Results
        Expanded(
          child: isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.blue))
              : filteredUsers.isNotEmpty
              ? ListView.builder(
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  backgroundImage: user['profileImage'] != null && user['profileImage'] != ''
                      ? NetworkImage(user['profileImage'])
                      : AssetImage('assets/default_profile.png') as ImageProvider,
                ),
                title: Text(
                  '${user['firstName']} ${user['lastName']}',
                  style: TextStyle(color: Colors.black87),
                ),
                subtitle: Text(
                  '@${user['username']}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(),
                    ),
                  );
                },
              );
            },
          )
              : Center(
            child: Text(
              'Kullanıcı aramak için yazmaya başlayın',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }
}