import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import './url_constants.dart';
import 'message_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final Dio _dio = Dio();

  List<Map<String, dynamic>> conversations = [];
  bool isLoading = true;
  String? authToken;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getString('userId') ?? prefs.getString('user_id');
      authToken = prefs.getString('auth_token');
    });

    print('🔍 ConversationsScreen - User data loaded:');
    print('   Current User ID: $currentUserId');
    print('   Auth Token exists: ${authToken != null}');

    if (authToken != null) {
      await _loadConversations();
    } else {
      print('❌ Auth token bulunamadı!');
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadConversations() async {
    try {
      setState(() => isLoading = true);

      print('📥 Konuşmalar yükleniyor...');

      final response = await _dio.get(
        '${UrlConstants.apiBaseUrl}/api/messages/conversations',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('📨 Conversations API response: ${response.statusCode}');

      if (response.statusCode == 200 && mounted) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          final conversationsList = List<Map<String, dynamic>>.from(responseData['conversations'] ?? []);

          setState(() {
            conversations = conversationsList;
            isLoading = false;
          });
          print('✅ ${conversations.length} konuşma yüklendi');
        } else {
          print('❌ API Success false: ${responseData['message']}');
          setState(() {
            conversations = [];
            isLoading = false;
          });
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        setState(() {
          isLoading = false;
          conversations = [];
        });
      }
    } catch (e) {
      print('❌ Konuşmalar yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          conversations = [];
        });
      }
    }
  }

  ImageProvider _getProfileImage(Map<String, dynamic>? user) {
    print('🖼️ Conversation profil resmi kontrol ediliyor:');
    print('   User data: $user');

    if (user?['profileImage'] != null && user!['profileImage'].isNotEmpty) {
      String imageUrl;

      // Eğer tam URL ise direkt kullan
      if (user['profileImage'].startsWith('http')) {
        imageUrl = user['profileImage'];
      }
      // Eğer '/uploads/' ile başlıyorsa base URL ekle
      else if (user['profileImage'].startsWith('/uploads/')) {
        imageUrl = '${UrlConstants.apiBaseUrl}${user['profileImage']}';
      }
      // Eğer sadece dosya adı ise uploads path'i ekle
      else if (user['profileImage'] != 'image.jpg') {
        imageUrl = '${UrlConstants.apiBaseUrl}/uploads/${user['profileImage']}';
      }
      // Default image
      else {
        print('   Default image kullanılıyor (image.jpg)');
        return const AssetImage('assets/default_avatar.png');
      }

      print('   Final image URL: $imageUrl');
      return NetworkImage(imageUrl);
    }

    print('   Profile image null - default kullanılıyor');
    return const AssetImage('assets/default_avatar.png');
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return '';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        if (difference.inDays == 1) {
          return 'Dün';
        } else if (difference.inDays < 7) {
          return '${difference.inDays} gün';
        } else {
          return '${date.day}/${date.month}';
        }
      } else if (difference.inHours > 0) {
        return '${difference.inHours}s';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}d';
      } else {
        return 'Şimdi';
      }
    } catch (e) {
      return '';
    }
  }

  String _getLastMessageText(Map<String, dynamic> lastMessage) {
    final message = lastMessage['message'] ?? '';
    if (message.length > 40) {
      return '${message.substring(0, 40)}...';
    }
    return message;
  }

  Widget _buildConversationItem(Map<String, dynamic> conversation) {
    final otherUser = conversation['otherUser'];
    final lastMessage = conversation['lastMessage'];
    final unreadCount = conversation['unreadCount'] ?? 0;

    final fullName = '${otherUser['firstName'] ?? ''} ${otherUser['lastName'] ?? ''}'.trim();
    final username = otherUser['username'] ?? '';

    // Profil resmi URL'sini düzelt
    String? profileImageUrl;
    if (otherUser['profileImage'] != null && otherUser['profileImage'].isNotEmpty) {
      if (otherUser['profileImage'].startsWith('http')) {
        profileImageUrl = otherUser['profileImage'];
      } else if (otherUser['profileImage'].startsWith('/uploads/')) {
        profileImageUrl = otherUser['profileImage'];
      } else if (otherUser['profileImage'] != 'image.jpg') {
        profileImageUrl = '/uploads/${otherUser['profileImage']}';
      }
    }

    print('🔗 MessageScreen\'e gönderilen veriler:');
    print('   Recipient ID: ${otherUser['_id']}');
    print('   Recipient Name: $fullName');
    print('   Profile Image URL: $profileImageUrl');

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessageScreen(
              recipientId: otherUser['_id'],
              recipientName: fullName,
              recipientUsername: username,
              recipientProfileImage: profileImageUrl, // Düzeltilmiş URL
            ),
          ),
        ).then((_) {
          // Mesajlaşma sayfasından döndüğünde konuşmaları yenile
          _loadConversations();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Profil resmi
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: _getProfileImage(otherUser),
                ),
                // Online durumu için yeşil nokta (opsiyonel)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Kullanıcı bilgileri ve son mesaj
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // İsim
                      Expanded(
                        child: Text(
                          fullName.isNotEmpty ? fullName : '@$username',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Zaman
                      Text(
                        _formatTime(lastMessage['createdAt']),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      // Son mesaj
                      Expanded(
                        child: Text(
                          _getLastMessageText(lastMessage),
                          style: TextStyle(
                            color: unreadCount > 0 ? Colors.white : Colors.grey[400],
                            fontSize: 14,
                            fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Okunmamış mesaj sayısı
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz mesajınız yok',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Birisiyle konuşmaya başlayın!',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mesajlar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              // Yeni mesaj başlatma özelliği eklenebilir
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : conversations.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadConversations,
        backgroundColor: Colors.grey[900],
        color: Colors.white,
        child: ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            return _buildConversationItem(conversations[index]);
          },
        ),
      ),
    );
  }
}