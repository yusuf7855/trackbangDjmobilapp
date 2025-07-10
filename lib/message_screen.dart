import 'package:djmobilapp/url_constants.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../utils/constants.dart';

class MessageScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String recipientUsername;
  final String? recipientProfileImage;

  const MessageScreen({
    Key? key,
    required this.recipientId,
    required this.recipientName,
    required this.recipientUsername,
    this.recipientProfileImage,
  }) : super(key: key);

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Dio _dio = Dio();

  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? currentUserId;
  String? authToken;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getString('userId') ?? prefs.getString('user_id');
      authToken = prefs.getString('auth_token'); // 'authToken' yerine 'auth_token' kullan
    });

    print('🔍 MessageScreen - User data loaded:');
    print('   Current User ID: $currentUserId');
    print('   Current User ID Type: ${currentUserId.runtimeType}');
    print('   Recipient ID: ${widget.recipientId}');
    print('   Recipient ID Type: ${widget.recipientId.runtimeType}');
    print('   Auth Token exists: ${authToken != null}');
    print('   Auth Token length: ${authToken?.length}');

    if (authToken != null) {
      await _loadMessages();
    } else {
      print('❌ Auth token bulunamadı!');
    }
  }

  Future<void> _loadMessages() async {
    try {
      setState(() => isLoading = true);

      print('📥 Mesajlar yükleniyor:');
      print('   Recipient ID: ${widget.recipientId}');
      print('   Current User ID: $currentUserId');

      final response = await _dio.get(
        '${UrlConstants.apiBaseUrl}/api/messages/conversation/${widget.recipientId}',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('📨 Messages API response: ${response.statusCode}');

      if (response.statusCode == 200 && mounted) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          final messagesList = List<Map<String, dynamic>>.from(responseData['messages'] ?? []);

          // Her mesaj için debug bilgisi yazdır
          for (int i = 0; i < messagesList.length; i++) {
            final msg = messagesList[i];
            print('📝 Message $i:');
            print('   ID: ${msg['_id']}');
            print('   Sender ID: ${msg['senderId']}');
            print('   Sender Type: ${msg['senderId'].runtimeType}');
            print('   Message: ${msg['message']}');

            // Eğer senderId bir obje ise, _id'sini çıkar
            if (msg['senderId'] is Map && msg['senderId']['_id'] != null) {
              msg['senderId'] = msg['senderId']['_id'].toString();
              print('   Fixed Sender ID: ${msg['senderId']}');
            } else if (msg['senderId'] != null) {
              msg['senderId'] = msg['senderId'].toString();
            }

            // recipientId için de aynı kontrolü yap
            if (msg['recipientId'] is Map && msg['recipientId']['_id'] != null) {
              msg['recipientId'] = msg['recipientId']['_id'].toString();
            } else if (msg['recipientId'] != null) {
              msg['recipientId'] = msg['recipientId'].toString();
            }
          }

          setState(() {
            messages = messagesList;
            isLoading = false;
          });
          print('✅ ${messages.length} mesaj yüklendi');
        } else {
          print('❌ API Success false: ${responseData['message']}');
          setState(() {
            messages = [];
            isLoading = false;
          });
        }
        _scrollToBottom();
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        setState(() {
          isLoading = false;
          messages = [];
        });
      }
    } catch (e) {
      print('❌ Mesajlar yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          messages = [];
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || isSending) return;
    if (authToken == null) {
      print('❌ Auth token null - mesaj gönderilemez');
      _showErrorSnackbar('Oturum süresi dolmuş, tekrar giriş yapın');
      return;
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() => isSending = true);

    try {
      print('📤 Mesaj gönderiliyor:');
      print('   Recipient ID: ${widget.recipientId}');
      print('   Message: $messageText');
      print('   Current User ID: $currentUserId');

      // Direkt API'ye gönder, optimistic UI kullanma
      final response = await _dio.post(
        '${UrlConstants.apiBaseUrl}/api/messages/send',
        data: {
          'recipientId': widget.recipientId,
          'message': messageText,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('✅ Mesaj gönderildi - Status: ${response.statusCode}');
      print('📦 Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Başarılı - mesajları yeniden yükle
        await _loadMessages();
      } else {
        _showErrorSnackbar('Mesaj gönderilemedi');
      }
    } catch (e) {
      print('❌ Mesaj gönderme hatası: $e');
      if (mounted) {
        _showErrorSnackbar('Mesaj gönderilemedi: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return; // Widget hala mounted kontrolü
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  ImageProvider _getRecipientProfileImage() {
    print('🖼️ Recipient profil resmi kontrol ediliyor:');
    print('   recipientProfileImage: ${widget.recipientProfileImage}');

    // Widget'dan gelen profil resmi
    if (widget.recipientProfileImage != null && widget.recipientProfileImage!.isNotEmpty) {
      String imageUrl;

      // Eğer tam URL ise direkt kullan
      if (widget.recipientProfileImage!.startsWith('http')) {
        imageUrl = widget.recipientProfileImage!;
      }
      // Eğer '/uploads/' ile başlıyorsa base URL ekle
      else if (widget.recipientProfileImage!.startsWith('/uploads/')) {
        imageUrl = '${UrlConstants.apiBaseUrl}${widget.recipientProfileImage}';
      }
      // Eğer sadece dosya adı ise uploads path'i ekle
      else if (widget.recipientProfileImage != 'image.jpg') {
        imageUrl = '${UrlConstants.apiBaseUrl}/uploads/${widget.recipientProfileImage}';
      }
      // Default image
      else {
        print('   Default image kullanılıyor');
        return const AssetImage('assets/default_avatar.png');
      }

      print('   Final image URL: $imageUrl');
      return NetworkImage(imageUrl);
    }

    print('   Profile image null - default kullanılıyor');
    return const AssetImage('assets/default_avatar.png');
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isMe = message['senderId'].toString() == currentUserId.toString();
    final createdAt = DateTime.tryParse(message['createdAt'] ?? '') ?? DateTime.now();
    final timeFormat = "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";

    print('🔍 Message debug:');
    print('   Sender ID: ${message['senderId']}');
    print('   Current User ID: $currentUserId');
    print('   Is Me: $isMe');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Karşı tarafın profil resmi (sadece karşı tarafın mesajlarında)
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: _getRecipientProfileImage(),
            ),
            const SizedBox(width: 8),
          ],

          // Mesaj balonu
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue[600] : Colors.grey[800], // Benim mesajlarım mavi, karşı tarafınkiler gri
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['message'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeFormat,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Benim mesajlarım için okundu ikonu (sağ tarafta)
          if (isMe) ...[
            const SizedBox(width: 8),
            Icon(
              message['isRead'] == true ? Icons.done_all : Icons.done,
              color: message['isRead'] == true ? Colors.blue[300] : Colors.grey[400],
              size: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[700]!),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Mesaj yazın...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue[600],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: isSending ? null : _sendMessage,
                icon: isSending
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Icon(
                  Icons.send,
                  color: Colors.white,
                ),
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
        backgroundColor: Colors.grey[900],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: _getRecipientProfileImage(),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recipientName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '@${widget.recipientUsername}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: () {
              // Telefon araması özelliği eklenebilir
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              // Video arama özelliği eklenebilir
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Mesajlar listesi
          Expanded(
            child: isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : messages.isEmpty
                ? Center(
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
                    'Henüz mesaj yok',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İlk mesajı gönderin!',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(messages[index]);
              },
            ),
          ),

          // Mesaj input alanı
          _buildMessageInput(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}