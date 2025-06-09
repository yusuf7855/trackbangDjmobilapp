// lib/services/message_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../url_constants.dart';

class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  IO.Socket? _socket;
  String? _authToken;
  String? _userId;

  // Callback functions for real-time events
  Function(Map<String, dynamic>)? onNewMessage;
  Function(Map<String, dynamic>)? onUserTyping;
  Function(Map<String, dynamic>)? onUserStopTyping;
  Function(Map<String, dynamic>)? onMessageRead;
  Function(String, bool)? onUserStatusChanged;

  // Initialize socket connection
  Future<void> initializeSocket() async {
    await _loadAuthData();

    if (_authToken == null) return;

    _socket = IO.io(
        UrlConstants.apiBaseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .setAuth({'token': _authToken})
            .build()
    );

    _socket?.onConnect((_) {
      print('Socket connected');
    });

    _socket?.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket?.onConnectError((data) {
      print('Socket connection error: $data');
    });

    // Listen for new messages
    _socket?.on('new_message', (data) {
      print('New message received: $data');
      if (onNewMessage != null) {
        onNewMessage!(data);
      }
    });

    // Listen for typing indicators
    _socket?.on('user_typing', (data) {
      if (onUserTyping != null) {
        onUserTyping!(data);
      }
    });

    _socket?.on('user_stop_typing', (data) {
      if (onUserStopTyping != null) {
        onUserStopTyping!(data);
      }
    });

    // Listen for message read receipts
    _socket?.on('message_read_receipt', (data) {
      if (onMessageRead != null) {
        onMessageRead!(data);
      }
    });

    // Listen for user status changes
    _socket?.on('user_status', (data) {
      if (onUserStatusChanged != null) {
        onUserStatusChanged!(data['userId'], data['isOnline']);
      }
    });

    _socket?.connect();
  }

  Future<void> _loadAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    _userId = prefs.getString('userId') ?? prefs.getString('user_id');
  }

  // Socket utility methods
  void joinConversation(String conversationId) {
    _socket?.emit('join_conversation', conversationId);
  }

  void leaveConversation(String conversationId) {
    _socket?.emit('leave_conversation', conversationId);
  }

  void startTyping(String conversationId) {
    _socket?.emit('typing_start', {'conversationId': conversationId});
  }

  void stopTyping(String conversationId) {
    _socket?.emit('typing_stop', {'conversationId': conversationId});
  }

  void markMessageAsRead(String messageId, String conversationId) {
    _socket?.emit('message_read', {
      'messageId': messageId,
      'conversationId': conversationId
    });
  }

  void getUserStatus(String userId) {
    _socket?.emit('get_user_status', userId);
  }

  // API methods
  Future<Map<String, dynamic>> getConversations() async {
    try {
      await _loadAuthData();

      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/messages/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'conversations': data['conversations'] ?? []
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Konuşmalar alınamadı'
        };
      }
    } catch (e) {
      print('Get conversations error: $e');
      return {
        'success': false,
        'message': 'Bağlantı hatası: $e'
      };
    }
  }

  Future<Map<String, dynamic>> getMessages(String conversationId, {int page = 1, int limit = 50}) async {
    try {
      await _loadAuthData();

      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/messages/conversations/$conversationId/messages?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'messages': data['messages'] ?? [],
          'pagination': data['pagination'] ?? {}
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Mesajlar alınamadı'
        };
      }
    } catch (e) {
      print('Get messages error: $e');
      return {
        'success': false,
        'message': 'Bağlantı hatası: $e'
      };
    }
  }

  Future<Map<String, dynamic>> sendMessage(String conversationId, String content, {String messageType = 'text'}) async {
    try {
      await _loadAuthData();

      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/messages/conversations/$conversationId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({
          'content': content,
          'messageType': messageType,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message']
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Mesaj gönderilemedi'
        };
      }
    } catch (e) {
      print('Send message error: $e');
      return {
        'success': false,
        'message': 'Bağlantı hatası: $e'
      };
    }
  }

  Future<Map<String, dynamic>> createConversation(String receiverId) async {
    try {
      await _loadAuthData();

      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/messages/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({
          'receiverId': receiverId,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'conversation': data['conversation']
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Konuşma başlatılamadı'
        };
      }
    } catch (e) {
      print('Create conversation error: $e');
      return {
        'success': false,
        'message': 'Bağlantı hatası: $e'
      };
    }
  }

  Future<Map<String, dynamic>> markAsRead(String conversationId) async {
    try {
      await _loadAuthData();

      final response = await http.patch(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/messages/conversations/$conversationId/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message']
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'İşlem başarısız'
        };
      }
    } catch (e) {
      print('Mark as read error: $e');
      return {
        'success': false,
        'message': 'Bağlantı hatası: $e'
      };
    }
  }

  Future<Map<String, dynamic>> deleteMessage(String messageId) async {
    try {
      await _loadAuthData();

      final response = await http.delete(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/messages/messages/$messageId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message']
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Mesaj silinemedi'
        };
      }
    } catch (e) {
      print('Delete message error: $e');
      return {
        'success': false,
        'message': 'Bağlantı hatası: $e'
      };
    }
  }

  // Cleanup
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // Getters
  bool get isConnected => _socket?.connected ?? false;
  String? get userId => _userId;
}