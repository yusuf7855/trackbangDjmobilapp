// lib/screens/dm_inbox_screen.dart
import 'package:flutter/material.dart';
import '../services/chat_screen.dart';
import '../services/message_service.dart';
import '../url_constants.dart';
import 'dart:async';

class DMInboxScreen extends StatefulWidget {
  @override
  _DMInboxScreenState createState() => _DMInboxScreenState();
}

class _DMInboxScreenState extends State<DMInboxScreen> with WidgetsBindingObserver {
  final MessageService _messageService = MessageService();
  List<dynamic> conversations = [];
  bool isLoading = true;
  String? error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeMessaging();
    _loadConversations();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadConversations();
    }
  }

  Future<void> _initializeMessaging() async {
    await _messageService.initializeSocket();

    // Listen for new messages to update conversation list
    _messageService.onNewMessage = (data) {
      _loadConversations();
    };
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (mounted) {
        _loadConversations();
      }
    });
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await _messageService.getConversations();

      if (mounted) {
        if (result['success']) {
          setState(() {
            conversations = result['conversations'] ?? [];
            isLoading = false;
          });
        } else {
          setState(() {
            error = result['message'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Bağlantı hatası: $e';
          isLoading = false;
        });
      }
    }
  }

  String _formatTime(String? timeString) {
    if (timeString == null) return '';

    try {
      final DateTime messageTime = DateTime.parse(timeString);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(messageTime);

      if (difference.inDays > 0) {
        if (difference.inDays == 1) {
          return 'dün';
        } else if (difference.inDays < 7) {
          return '${difference.inDays} gün';
        } else {
          return '${messageTime.day}/${messageTime.month}';
        }
      } else if (difference.inHours > 0) {
        return '${difference.inHours}s';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}dk';
      } else {
        return 'şimdi';
      }
    } catch (e) {
      return '';
    }
  }

  ImageProvider _getProfileImage(dynamic user) {
    if (user['profilePicture'] != null && user['profilePicture'].isNotEmpty) {
      final String imageUrl = user['profilePicture'].startsWith('http')
          ? user['profilePicture']
          : '${UrlConstants.apiBaseUrl}/uploads/${user['profilePicture']}';
      return NetworkImage(imageUrl);
    }
    return const AssetImage('assets/default_avatar.png');
  }

  String _getDisplayName(dynamic user) {
    final firstName = user['firstName'] ?? '';
    final lastName = user['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    if (fullName.isEmpty) {
      return user['username'] ?? 'Bilinmeyen Kullanıcı';
    }
    return fullName;
  }

  String _getLastMessagePreview(dynamic lastMessage) {
    if (lastMessage == null) return 'Henüz mesaj yok';

    String content = lastMessage['content'] ?? '';
    if (content.length > 50) {
      content = content.substring(0, 50) + '...';
    }

    final messageType = lastMessage['messageType'] ?? 'text';
    switch (messageType) {
      case 'image':
        return '📷 Fotoğraf';
      case 'audio':
        return '🎵 Ses kaydı';
      case 'file':
        return '📎 Dosya';
      default:
        return content;
    }
  }

  void _navigateToChat(dynamic conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation['_id'],
          otherUser: conversation['otherParticipant'],
        ),
      ),
    ).then((_) {
      // Refresh conversations when returning from chat
      _loadConversations();
    });
  }

  void _showConversationOptions(dynamic conversation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.mark_as_unread, color: Colors.white),
              title: Text('Okunmadı Olarak İşaretle', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Mark as unread logic
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications_off, color: Colors.white),
              title: Text('Bildirimleri Kapat', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Mute notifications logic
              },
            ),
            ListTile(
              leading: Icon(Icons.person, color: Colors.white),
              title: Text('Profili Görüntüle', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Konuşmayı Sil', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(conversation);
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(dynamic conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Konuşmayı Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bu konuşmayı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Delete conversation logic
              _deleteConversation(conversation['_id']);
            },
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteConversation(String conversationId) {
    // Implement delete conversation logic
    setState(() {
      conversations.removeWhere((conv) => conv['_id'] == conversationId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Konuşma silindi'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
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
        title: Text(
          'Mesajlar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Search in conversations
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadConversations,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // More options
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadConversations,
        backgroundColor: Colors.grey[900],
        color: Colors.white,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to new message screen or user search
          _showNewMessageDialog();
        },
        backgroundColor: Colors.blue,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Konuşmalar yükleniyor...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              error!,
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message_outlined,
              color: Colors.grey,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Henüz mesaj yok',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Arkadaşlarınla konuşmaya başla!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showNewMessageDialog(),
              icon: Icon(Icons.add),
              label: Text('Yeni Mesaj'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final otherUser = conversation['otherParticipant'];
        final lastMessage = conversation['lastMessage'];
        final unreadCount = conversation['unreadCount'] ?? 0;
        final lastMessageTime = conversation['lastMessageTime'];

        return Card(
          color: Colors.grey[900],
          margin: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: _getProfileImage(otherUser),
                ),
                if (otherUser['isOnline'] == true)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              _getDisplayName(otherUser),
              style: TextStyle(
                color: Colors.white,
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              _getLastMessagePreview(lastMessage),
              style: TextStyle(
                color: unreadCount > 0 ? Colors.white70 : Colors.grey,
                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(lastMessageTime),
                  style: TextStyle(
                    color: unreadCount > 0 ? Colors.white : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                if (unreadCount > 0) ...[
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
            onTap: () => _navigateToChat(conversation),
            onLongPress: () => _showConversationOptions(conversation),
          ),
        );
      },
    );
  }

  void _showNewMessageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Yeni Mesaj', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bu özellik yakında eklenecek. Şimdilik kullanıcı profillerinden mesaj gönderebilirsiniz.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}