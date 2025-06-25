// lib/screens/notifications_screen.dart dosyasının sonuna eklenecek NotificationsScreen widget'ı

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
  int _currentPage = 1;
  final int _limit = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        return;
      }

      final response = await _dio.get(
        '${Constants.apiBaseUrl}/notifications?page=1&limit=$_limit',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        final notificationsList = data['notifications'] as List<dynamic>? ?? [];

        setState(() {
          _notifications = notificationsList
              .map((json) => NotificationModel.fromJson(json))
              .toList();
          _hasMoreData = notificationsList.length == _limit;
          _currentPage = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Bildirim yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (!mounted || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return;

      final response = await _dio.get(
        '${Constants.apiBaseUrl}/notifications?page=${_currentPage + 1}&limit=$_limit',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        final notificationsList = data['notifications'] as List<dynamic>? ?? [];

        setState(() {
          _notifications.addAll(
              notificationsList.map((json) => NotificationModel.fromJson(json)).toList()
          );
          _hasMoreData = notificationsList.length == _limit;
          _currentPage++;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Daha fazla bildirim yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String notificationId, int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return;

      final response = await _dio.put(
        '${Constants.apiBaseUrl}/notifications/$notificationId/read',
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
      }
    } catch (e) {
      print('Bildirim okundu işaretleme hatası: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return;

      final response = await _dio.put(
        '${Constants.apiBaseUrl}/notifications/mark-all-read',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
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
      }
    } catch (e) {
      print('Tümünü okundu işaretleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bir hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleNotificationTap(NotificationModel notification, int index) {
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
    // Deep link işleme mantığı
    // Örneğin: "playlist/123" -> Playlist sayfasına git
    // "music/456" -> Müzik detay sayfasına git
    print('Deep link işleniyor: $deepLink');

    // Bu kısım uygulamanıza göre özelleştirilebilir
    final parts = deepLink.split('/');
    if (parts.length >= 2) {
      final type = parts[0];
      final id = parts[1];

      switch (type) {
        case 'playlist':
        // Playlist sayfasına navigasyon
          break;
        case 'music':
        // Müzik detay sayfasına navigasyon
          break;
        case 'profile':
        // Profil sayfasına navigasyon
          break;
      }
    }
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Bildirimler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_notifications.any((notification) => !notification.isRead))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Tümünü Okundu İşaretle',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
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
            const Text(
              'Lütfen tekrar deneyin',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
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
          ],
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: notification.typeColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            notification.typeIcon,
            color: notification.typeColor,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.body,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              notification.timeAgo,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
          width: 8,
          height: 8,
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
}