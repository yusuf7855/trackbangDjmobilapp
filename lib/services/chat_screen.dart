// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/message_service.dart';
import '../url_constants.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final dynamic otherUser;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.otherUser,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final MessageService _messageService = MessageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> messages = [];
  bool isLoading = true;
  bool isSending = false;
  bool isTyping = false;
  bool hasMoreMessages = true;
  int currentPage = 1;
  Timer? _typingTimer;
  String? typingUser;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _loadMessages();
    _setupScrollListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageService.leaveConversation(widget.conversationId);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _messageService.markAsRead(widget.conversationId);
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Load more messages when scrolled to top
      if (_scrollController.position.pixels == _scrollController.position.minScrollExtent &&
          hasMoreMessages && !isLoading) {
        _loadMessages(loadMore: true);
      }
    });
  }

  void _initializeChat() {
    _messageService.joinConversation(widget.conversationId);

    // Listen for new messages
    _messageService.onNewMessage = (data) {
      if (data['conversationId'] == widget.conversationId) {
        setState(() {
          messages.add(data['message']);
        });
        _scrollToBottom();

        // Mark message as read
        _messageService.markAsRead(widget.conversationId);
      }
    };

    // Listen for typing indicators
    _messageService.onUserTyping = (data) {
      if (data['conversationId'] == widget.conversationId &&
          data['userId'] != _messageService.userId) {
        setState(() {
          typingUser = data['username'];
        });

        // Auto clear typing indicator after 3 seconds
        Timer(Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              typingUser = null;
            });
          }
        });
      }
    };

    _messageService.onUserStopTyping = (data) {
      if (data['conversationId'] == widget.conversationId) {
        setState(() {
          typingUser = null;
        });
      }
    };

    // Listen for user status
    _messageService.onUserStatusChanged = (userId, isOnline) {
      if (userId == widget.otherUser['_id']) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    };

    // Get initial user status
    _messageService.getUserStatus(widget.otherUser['_id']);
  }

  Future<void> _loadMessages({bool loadMore = false}) async {
    if (!hasMoreMessages && loadMore) return;

    if (!loadMore) {
      setState(() {
        isLoading = true;
        currentPage = 1;
      });
    }

    try {
      final result = await _messageService.getMessages(
        widget.conversationId,
        page: loadMore ? currentPage + 1 : 1,
      );

      if (result['success']) {
        final newMessages = result['messages'] as List;
        final pagination = result['pagination'] as Map;

        setState(() {
          if (loadMore) {
            messages.insertAll(0, newMessages);
            currentPage++;
          } else {
            messages = newMessages;
          }

          hasMoreMessages = pagination['hasMore'] ?? false;
          isLoading = false;
        });

        if (!loadMore) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }

        // Mark messages as read
        await _messageService.markAsRead(widget.conversationId);
      } else {
        _showError(result['message']);
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      _showError('Mesajlar yüklenirken hata oluştu: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || isSending) return;

    setState(() {
      isSending = true;
    });

    // Stop typing indicator
    _messageService.stopTyping(widget.conversationId);

    try {
      final result = await _messageService.sendMessage(
        widget.conversationId,
        content,
      );

      if (result['success']) {
        _messageController.clear();
        setState(() {
          messages.add(result['message']);
        });
        _scrollToBottom();
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('Mesaj gönderilemedi: $e');
    } finally {
      setState(() {
        isSending = false;
      });
    }
  }

  void _onTyping() {
    if (!isTyping) {
      isTyping = true;
      _messageService.startTyping(widget.conversationId);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 2), () {
      isTyping = false;
      _messageService.stopTyping(widget.conversationId);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatMessageTime(String? timeString) {
    if (timeString == null) return '';

    try {
      final DateTime messageTime = DateTime.parse(timeString);
      final DateTime now = DateTime.now();

      if (messageTime.day == now.day &&
          messageTime.month == now.month &&
          messageTime.year == now.year) {
        return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${messageTime.day}/${messageTime.month} ${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  ImageProvider _getProfileImage() {
    if (widget.otherUser['profilePicture'] != null &&
        widget.otherUser['profilePicture'].isNotEmpty) {
      final String imageUrl = widget.otherUser['profilePicture'].startsWith('http')
          ? widget.otherUser['profilePicture']
          : '${UrlConstants.apiBaseUrl}/uploads/${widget.otherUser['profilePicture']}';
      return NetworkImage(imageUrl);
    }
    return const AssetImage('assets/default_avatar.png');
  }

  String _getDisplayName() {
    final firstName = widget.otherUser['firstName'] ?? '';
    final lastName = widget.otherUser['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    if (fullName.isEmpty) {
      return widget.otherUser['username'] ?? 'Bilinmeyen Kullanıcı';
    }
    return fullName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: _getProfileImage(),
                ),
                if (_isOnline || widget.otherUser['isOnline'] == true)
                  Positioned(
                    bottom: 0,
                    right: 0,
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
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getDisplayName(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    typingUser != null
                        ? 'yazıyor...'
                        : (_isOnline || widget.otherUser['isOnline'] == true)
                        ? 'çevrimiçi'
                        : 'çevrimdışı',
                    style: TextStyle(
                      color: typingUser != null
                          ? Colors.green
                          : (_isOnline || widget.otherUser['isOnline'] == true)
                          ? Colors.green
                          : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              // Video call özelliği
            },
          ),
          IconButton(
            icon: Icon(Icons.call, color: Colors.white),
            onPressed: () {
              // Voice call özelliği
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          if (typingUser != null)
            _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (isLoading && messages.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (messages.isEmpty) {
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
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'İlk mesajı gönder!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(8),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0 && isLoading) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
          );
        }

        final messageIndex = isLoading ? index - 1 : index;
        final message = messages[messageIndex];
        final isCurrentUser = message['sender']['_id'] == _messageService.userId;

        return _buildMessageBubble(message, isCurrentUser);
      },
    );
  }

  Widget _buildMessageBubble(dynamic message, bool isCurrentUser) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(isCurrentUser ? 20 : 5),
            bottomRight: Radius.circular(isCurrentUser ? 5 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['content'] ?? '',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(message['createdAt']),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                if (isCurrentUser) ...[
                  SizedBox(width: 4),
                  Icon(
                    message['isRead'] == true
                        ? Icons.done_all
                        : Icons.done,
                    color: message['isRead'] == true
                        ? Colors.blue[300]
                        : Colors.white70,
                    size: 16,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 50),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'yazıyor...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: Colors.white70),
            onPressed: () {
              // Dosya ekleme özelliği
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Mesaj yazın...',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[800],
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => _onTyping(),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: isSending ? null : _sendMessage,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _messageController.text.trim().isNotEmpty
                    ? Colors.blue
                    : Colors.grey[700],
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptions() {
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
              leading: Icon(Icons.person, color: Colors.white),
              title: Text('Profili Görüntüle', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile
              },
            ),
            ListTile(
              leading: Icon(Icons.search, color: Colors.white),
              title: Text('Mesajlarda Ara', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Search in messages
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications_off, color: Colors.white),
              title: Text('Bildirimleri Kapat', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Mute notifications
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: Colors.red),
              title: Text('Engelle', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                // Block user
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Konuşmayı Sil', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
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
              Navigator.pop(context);
              // Delete conversation logic
            },
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}