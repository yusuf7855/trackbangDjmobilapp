// lib/services/notification_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:dio/dio.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();
  final Dio _dio = Dio();

  BuildContext? _context;
  Function(NotificationModel)? _onNotificationTapped;

  // Initialize notification service
  Future<void> initialize(BuildContext context) async {
    _context = context;
    await _initializeLocalNotifications();
    await _initializeFirebaseMessaging();
  }

  // Local notifications setup
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Android notification channels
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  // Create Android notification channels
  Future<void> _createNotificationChannels() async {
    const List<AndroidNotificationChannel> channels = [
      AndroidNotificationChannel(
        'default',
        'Genel Bildirimler',
        description: 'Genel uygulama bildirimleri',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        'music',
        'Müzik Bildirimleri',
        description: 'Müzik ile ilgili bildirimler',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        'playlist',
        'Playlist Bildirimleri',
        description: 'Playlist ile ilgili bildirimler',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        'user',
        'Kullanıcı Bildirimleri',
        description: 'Kullanıcı etkileşim bildirimleri',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        'promotion',
        'Promosyon Bildirimleri',
        description: 'Promosyon ve kampanya bildirimleri',
        importance: Importance.default,
        playSound: true,
        enableVibration: false,
      ),
    ];

    for (final channel in channels) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // Firebase messaging setup
  Future<void> _initializeFirebaseMessaging() async {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background message tapped
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // App opened from terminated state
    FirebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        Future.delayed(const Duration(seconds: 2), () {
          _handleBackgroundMessage(message);
        });
      }
    });

    // Token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);
  }

  // Request permissions
  Future<bool> requestPermissions() async {
    try {
      // Android 13+ notification permission
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        if (status != PermissionStatus.granted) {
          _showPermissionDialog();
          return false;
        }
      }

      // Firebase messaging permission
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        _showPermissionDialog();
        return false;
      }

      print('Bildirim izni verildi: ${settings.authorizationStatus}');
      return true;
    } catch (e) {
      print('İzin isteme hatası: $e');
      return false;
    }
  }

  // Show permission dialog
  void _showPermissionDialog() {
    if (_context == null) return;

    showDialog(
      context: _context!,
      builder: (context) => AlertDialog(
        title: const Text('Bildirim İzni Gerekli'),
        content: const Text(
          'Uygulamamızdan önemli güncellemeleri ve bildirimleri alabilmek için bildirim iznini etkinleştirmeniz gerekiyor.\n\n'
              'Ayarlar > Uygulamalar > [Uygulama Adı] > Bildirimler bölümünden izni etkinleştirebilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Ayarlara Git'),
          ),
        ],
      ),
    );
  }

  // Get and register FCM token
  Future<String?> getAndRegisterToken(String userId) async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        throw Exception('Bildirim izni verilmedi');
      }

      final fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken == null) {
        throw Exception('FCM token alınamadı');
      }

      print('FCM Token: $fcmToken');

      // Get device info
      final deviceInfo = await _getDeviceInfo();

      // Register token with backend
      final response = await _dio.post(
        '${Constants.apiBaseUrl}/api/notifications/register-token',
        data: {
          'fcmToken': fcmToken,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          ...deviceInfo,
          'notificationSettings': {
            'enabled': true,
            'sound': true,
            'vibration': true,
            'badge': true,
            'types': {
              'general': true,
              'music': true,
              'playlist': true,
              'user': true,
              'promotion': true,
            },
          },
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${await _getAuthToken()}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data['success']) {
        print('Token başarıyla kaydedildi');
        await _saveTokenLocally(fcmToken);
        return fcmToken;
      } else {
        throw Exception(response.data['message']);
      }
    } catch (e) {
      print('Token kaydetme hatası: $e');
      rethrow;
    }
  }

  // Get device information
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'deviceId': androidInfo.id,
          'deviceModel': androidInfo.model,
          'osVersion': androidInfo.version.release,
          'appVersion': packageInfo.version,
        };
      } else {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'deviceId': iosInfo.identifierForVendor ?? 'unknown',
          'deviceModel': iosInfo.model,
          'osVersion': iosInfo.systemVersion,
          'appVersion': packageInfo.version,
        };
      }
    } catch (e) {
      print('Cihaz bilgisi alma hatası: $e');
      return {
        'deviceId': 'unknown',
        'deviceModel': 'unknown',
        'osVersion': 'unknown',
        'appVersion': packageInfo.version,
      };
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground bildirim alındı: ${message.messageId}');

    // Show overlay notification
    showOverlayNotification(
          (context) {
        return Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 50),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.notification?.title ?? 'Yeni Bildirim',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (message.notification?.body != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          message.notification!.body!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      duration: const Duration(seconds: 4),
    );

    // Also show local notification
    _showLocalNotification(message);
  }

  // Handle background/terminated message tapped
  void _handleBackgroundMessage(RemoteMessage message) {
    print('Background bildirim tıklandı: ${message.messageId}');
    _handleNotificationTap(message.data);
  }

  // Handle local notification response
  void _onNotificationResponse(NotificationResponse response) {
    print('Local bildirim tıklandı: ${response.payload}');
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _handleNotificationTap(data);
      } catch (e) {
        print('Payload parse hatası: $e');
      }
    }
  }

  // Handle notification tap
  void _handleNotificationTap(Map<String, dynamic> data) {
    if (_onNotificationTapped != null) {
      final notification = NotificationModel.fromMap(data);
      _onNotificationTapped!(notification);
    }

    // Navigate based on type
    _navigateFromNotification(data);
  }

  // Navigate from notification
  void _navigateFromNotification(Map<String, dynamic> data) {
    if (_context == null) return;

    final navigator = Navigator.of(_context!);
    final type = data['type'] ?? 'general';

    try {
      switch (type) {
        case 'music':
          if (data['musicId'] != null) {
            navigator.pushNamed('/music-detail', arguments: data['musicId']);
          }
          break;
        case 'playlist':
          if (data['playlistId'] != null) {
            navigator.pushNamed('/playlist-detail', arguments: data['playlistId']);
          }
          break;
        case 'user':
          if (data['userId'] != null) {
            navigator.pushNamed('/user-profile', arguments: data['userId']);
          }
          break;
        case 'general':
        default:
          navigator.pushNamed('/notifications');
          break;
      }
    } catch (e) {
      print('Navigation hatası: $e');
      navigator.pushNamed('/notifications');
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final type = message.data['type'] ?? 'default';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default',
      'Genel Bildirimler',
      channelDescription: 'Genel uygulama bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      message.notification?.title,
      message.notification?.body,
      platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  // Token refresh handler
  Future<void> _onTokenRefresh(String token) async {
    print('FCM Token yenilendi: $token');
    try {
      final userId = await _getUserId();
      if (userId != null) {
        await getAndRegisterToken(userId);
      }
    } catch (e) {
      print('Token yenileme hatası: $e');
    }
  }

  // Update notification settings
  Future<bool> updateNotificationSettings(Map<String, dynamic> settings) async {
    try {
      final deviceInfo = await _getDeviceInfo();

      final response = await _dio.put(
        '${Constants.apiBaseUrl}/api/notifications/settings',
        data: {
          'deviceId': deviceInfo['deviceId'],
          'settings': settings,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${await _getAuthToken()}',
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.data['success'] == true;
    } catch (e) {
      print('Ayar güncelleme hatası: $e');
      return false;
    }
  }

  // Deactivate token (on logout)
  Future<void> deactivateToken() async {
    try {
      final deviceInfo = await _getDeviceInfo();

      await _dio.post(
        '${Constants.apiBaseUrl}/api/notifications/deactivate-token',
        data: {
          'deviceId': deviceInfo['deviceId'],
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${await _getAuthToken()}',
            'Content-Type': 'application/json',
          },
        ),
      );

      await _clearTokenLocally();
    } catch (e) {
      print('Token deaktive etme hatası: $e');
    }
  }

  // Set notification tap callback
  void setOnNotificationTapped(Function(NotificationModel) callback) {
    _onNotificationTapped = callback;
  }

  // Helper methods
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  Future<void> _saveTokenLocally(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  Future<void> _clearTokenLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fcm_token');
  }
}