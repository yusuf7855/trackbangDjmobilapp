// lib/screens/notifications_screen.dart - Debug özellikli tam sürüm

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Dio _dio = Dio();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  final int _limit = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupDio();
    _loadNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupDio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Add interceptor for debugging
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('🚀 REQUEST: ${options.method} ${options.uri}');
          print('🚀 HEADERS: ${options.headers}');
          print('🚀 DATA: ${options.data}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ RESPONSE: ${response.statusCode}');
          print('✅ DATA: ${response.data}');
          handler.next(response);
        },
        onError: (error, handler) {
          print('❌ ERROR: ${error.response?.statusCode} - ${error.message}');
          print('❌ RESPONSE DATA: ${error.response?.data}');
          handler.next(error);
        },
      ),
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreNotifications();
      }
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    print('🔄 Bildirimler yükleniyor...');

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      print('🔑 Auth Token: ${authToken != null ? "Mevcut" : "Yok"}');
      if (authToken != null) {
        print('🔑 Token başlangıcı: ${authToken.substring(0, 20)}...');
      }

      if (authToken == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Oturum açmanız gerekiyor';
          _isLoading = false;
        });
        return;
      }

      // ✅ Constants'tan endpoint kullan
      final url = '${Constants.apiBaseUrl}${Constants.notificationUserEndpoint}?page=1&limit=$_limit';
      print('🌐 API URL: $url');

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        print('📥 Response data: $data');

        if (data is Map<String, dynamic>) {
          if (data['success'] == true) {
            // Backend response yapısı: data.data.notifications
            final responseData = data['data'];
            if (responseData != null && responseData is Map<String, dynamic>) {
              final notificationsList = responseData['notifications'] as List<dynamic>? ?? [];
              print('📋 Bildirimlerin sayısı: ${notificationsList.length}');

              setState(() {
                _notifications = notificationsList
                    .map((json) {
                  try {
                    return NotificationModel.fromJson(json);
                  } catch (e) {
                    print('❌ Bildirim parse hatası: $e');
                    print('❌ Problematik data: $json');
                    return null;
                  }
                })
                    .where((notification) => notification != null)
                    .cast<NotificationModel>()
                    .toList();
                _hasMoreData = notificationsList.length == _limit;
                _currentPage = 1;
                _isLoading = false;
              });

              print('✅ ${_notifications.length} bildirim başarıyla yüklendi');
            } else {
              throw Exception('Response data yapısı beklenmiyor: $responseData');
            }
          } else {
            throw Exception(data['message'] ?? 'API başarısız response döndü');
          }
        } else {
          throw Exception('Response beklenen formatta değil: $data');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } catch (e) {
      print('❌ Bildirim yükleme hatası: $e');

      String errorMessage = 'Bilinmeyen hata oluştu';

      if (e is DioException) {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.receiveTimeout:
            errorMessage = 'Bağlantı zaman aşımı';
            break;
          case DioExceptionType.connectionError:
            errorMessage = 'İnternet bağlantısı yok';
            break;
          case DioExceptionType.badResponse:
            if (e.response?.statusCode == 401) {
              errorMessage = 'Oturum süresi doldu, tekrar giriş yapın';
            } else if (e.response?.statusCode == 403) {
              errorMessage = 'Bu işlem için yetkiniz yok';
            } else if (e.response?.statusCode == 500) {
              errorMessage = 'Sunucu hatası';
            } else {
              errorMessage = 'API Hatası: ${e.response?.statusCode}';
            }
            break;
          default:
            errorMessage = 'Ağ hatası: ${e.message}';
        }
      } else {
        errorMessage = 'Uygulama hatası: $e';
      }

      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (!mounted || _isLoadingMore) return;

    print('🔄 Daha fazla bildirim yükleniyor... (Sayfa: ${_currentPage + 1})');

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return;

      final url = '${Constants.apiBaseUrl}${Constants.notificationUserEndpoint}?page=${_currentPage + 1}&limit=$_limit';

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        if (data['success'] == true) {
          final responseData = data['data'];
          final notificationsList = responseData['notifications'] as List<dynamic>? ?? [];

          setState(() {
            _notifications.addAll(
                notificationsList.map((json) => NotificationModel.fromJson(json)).toList()
            );
            _hasMoreData = notificationsList.length == _limit;
            _currentPage++;
            _isLoadingMore = false;
          });

          print('✅ ${notificationsList.length} ek bildirim yüklendi');
        }
      }
    } catch (e) {
      print('❌ Daha fazla bildirim yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Daha fazla bildirim yüklenemedi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId, int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return;

      // ✅ Constants'tan endpoint kullan ve ID'yi yerine koy
      final endpoint = Constants.notificationMarkReadEndpoint.replaceAll('{id}', notificationId);
      final url = '${Constants.apiBaseUrl}$endpoint';

      print('📝 Okundu işaretleniyor: $url');

      final response = await _dio.put(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _notifications[index] = _notifications[index].copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        });
        print('✅ Bildirim okundu olarak işaretlendi');
      }
    } catch (e) {
      print('❌ Bildirim okundu işaretleme hatası: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return;

      // ✅ Constants'tan endpoint kullan
      final url = '${Constants.apiBaseUrl}${Constants.notificationMarkAllReadEndpoint}';
      print('📝 Tümü okundu işaretleniyor: $url');

      final response = await _dio.put(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        if (data['success'] == true) {
          setState(() {
            _notifications = _notifications.map((notification) =>
                notification.copyWith(
                  isRead: true,
                  readAt: DateTime.now(),
                )
            ).toList();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tüm bildirimler okundu olarak işaretlendi'),
              backgroundColor: Colors.green,
            ),
          );

          print('✅ Tüm bildirimler okundu olarak işaretlendi');
        }
      }
    } catch (e) {
      print('❌ Tümünü okundu işaretleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bir hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleNotificationTap(NotificationModel notification, int index) {
    print('📱 Bildirim tıklandı: ${notification.title}');

    // Eğer okunmamışsa okundu olarak işaretle
    if (!notification.isRead) {
      _markAsRead(notification.id, index);
    }

    // Deep link varsa işle
    if (notification.deepLink != null && notification.deepLink!.isNotEmpty) {
      _handleDeepLink(notification.deepLink!);
    }
  }

  void _handleDeepLink(String deepLink) {
    print('🔗 Deep link işleniyor: $deepLink');

    // Örnek deep link işleme:
    if (deepLink.contains('/music/')) {
      // Müzik sayfasına yönlendir
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Müzik sayfasına yönlendiriliyor: $deepLink')),
      );
    } else if (deepLink.contains('/playlist/')) {
      // Playlist sayfasına yönlendir
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playlist sayfasına yönlendiriliyor: $deepLink')),
      );
    }
    // Diğer deep link'ler...
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Bildirimler',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadNotifications,
            tooltip: 'Yenile',
          ),
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white),
              onPressed: _markAllAsRead,
              tooltip: 'Tümünü okundu işaretle',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 16),
            Text(
              'Bildirimler yükleniyor...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 80,
              ),
              const SizedBox(height: 16),
              const Text(
                'Bildirimler yüklenemedi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadNotifications,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Tekrar Dene'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // Debug bilgilerini göster
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: const Text('Debug Bilgileri', style: TextStyle(color: Colors.white)),
                      content: SingleChildScrollView(
                        child: Text(
                          'API URL: ${Constants.apiBaseUrl}${Constants.notificationUserEndpoint}\n'
                              'Error: $_errorMessage\n'
                              'Auth Token Var: ${Constants.authTokenKey}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tamam'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Debug Bilgileri', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              color: Colors.grey,
              size: 80,
            ),
            SizedBox(height: 16),
            Text(
              'Henüz bildirim yok',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Yeni bildirimler burada görünecek',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: Colors.blue,
      backgroundColor: Colors.grey[900],
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _notifications.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            );
          }

          final notification = _notifications[index];
          return _buildNotificationItem(notification, index);
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.grey[900] : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Colors.grey[800]! : Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getNotificationColor(notification.type),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            _getNotificationIcon(notification.type),
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.body,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(notification.createdAt),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        )
            : null,
        onTap: () => _handleNotificationTap(notification, index),
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'music':
        return Colors.purple;
      case 'playlist':
        return Colors.green;
      case 'user':
        return Colors.orange;
      case 'promotion':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'music':
        return Icons.music_note;
      case 'playlist':
        return Icons.playlist_add;
      case 'user':
        return Icons.person;
      case 'promotion':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Şimdi';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}