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
    await _requestPermissions();
  }

  // Request permissions
  Future<void> _requestPermissions() async {
    // Firebase Messaging permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('Kullanıcı izin durumu: ${settings.authorizationStatus}');

    // Android notification permission (API 33+)
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      print('Android bildirim izni: $status');
    }
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

    // Register device token
    await _registerDeviceToken();
  }

  // Register device token with backend
  Future<void> _registerDeviceToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(Constants.userIdKey);
      final authToken = prefs.getString(Constants.authTokenKey);

      if (userId == null || authToken == null) {
        print('Kullanıcı girişi yapılmamış, token kaydedilemiyor');
        return;
      }

      final deviceInfo = await _getDeviceInfo();

      final response = await _dio.post(
        '${Constants.apiBaseUrl}${Constants.notificationRegisterToken}',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'fcmToken': token,
          'deviceInfo': deviceInfo,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );

      if (response.statusCode == 200) {
        await prefs.setString(Constants.fcmTokenKey, token);
        print('FCM token başarıyla kaydedildi');
      }
    } catch (e) {
      print('FCM token kaydetme hatası: $e');
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
      } else if (Platform.isIOS) {
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

    return {
      'deviceId': 'unknown',
      'deviceModel': 'unknown',
      'osVersion': 'unknown',
      'appVersion': packageInfo.version,
    };
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

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] ?? 'general';
    final imageUrl = message.data['imageUrl'];

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      type,
      _getChannelName(type),
      channelDescription: _getChannelDescription(type),
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      largeIcon: imageUrl != null
          ? NetworkAssetAndroidBitmap(imageUrl)
          : null,
      styleInformation: imageUrl != null
          ? BigPictureStyleInformation(
        NetworkAssetAndroidBitmap(imageUrl),
        contentTitle: notification.title,
        summaryText: notification.body,
      )
          : BigTextStyleInformation(
        notification.body ?? '',
        contentTitle: notification.title,
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  // Get channel name by type
  String _getChannelName(String type) {
    switch (type) {
      case 'music':
        return 'Müzik Bildirimleri';
      case 'playlist':
        return 'Playlist Bildirimleri';
      case 'user':
        return 'Kullanıcı Bildirimleri';
      case 'promotion':
        return 'Promosyon Bildirimleri';
      default:
        return 'Genel Bildirimler';
    }
  }

  // Get channel description by type
  String _getChannelDescription(String type) {
    switch (type) {
      case 'music':
        return 'Müzik ile ilgili bildirimler';
      case 'playlist':
        return 'Playlist ile ilgili bildirimler';
      case 'user':
        return 'Kullanıcı etkileşim bildirimleri';
      case 'promotion':
        return 'Promosyon ve kampanya bildirimleri';
      default:
        return 'Genel uygulama bildirimleri';
    }
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
    final deepLink = data['deepLink'];

    // DeepLink varsa onu kullan
    if (deepLink != null && deepLink.isNotEmpty) {
      // DeepLink handling logic buraya
      print('DeepLink: $deepLink');
      return;
    }

    // Tip bazlı navigasyon
    switch (type) {
      case 'music':
      // Müzik sayfasına git
        navigator.pushNamed('/music');
        break;
      case 'playlist':
      // Playlist sayfasına git
        final playlistId = data['playlistId'];
        if (playlistId != null) {
          navigator.pushNamed('/playlist', arguments: {'id': playlistId});
        } else {
          navigator.pushNamed('/playlists');
        }
        break;
      case 'user':
      // Profil sayfasına git
        final userId = data['userId'];
        if (userId != null) {
          navigator.pushNamed('/profile', arguments: {'userId': userId});
        }
        break;
      case 'promotion':
      // Promosyon sayfasına git
        navigator.pushNamed('/promotions');
        break;
      default:
      // Bildirimler sayfasına git
        navigator.pushNamed('/notifications');
        break;
    }
  }

  // Set notification tap callback
  void setOnNotificationTapped(Function(NotificationModel) callback) {
    _onNotificationTapped = callback;
  }

  // Update notification settings
  Future<bool> updateNotificationSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return false;

      final response = await _dio.put(
        '${Constants.apiBaseUrl}${Constants.notificationSettingsEndpoint}',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
        data: settings,
      );

      if (response.statusCode == 200) {
        await prefs.setString(
          Constants.notificationSettingsKey,
          jsonEncode(settings),
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Bildirim ayarları güncelleme hatası: $e');
      return false;
    }
  }

  // Get notification settings
  Future<Map<String, dynamic>> getNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(Constants.notificationSettingsKey);

      if (settingsJson != null) {
        return jsonDecode(settingsJson);
      }
      return Constants.defaultNotificationSettings;
    } catch (e) {
      print('Bildirim ayarları alma hatası: $e');
      return Constants.defaultNotificationSettings;
    }
  }

  // Deactivate device token (logout)
  Future<void> deactivateDeviceToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);
      final fcmToken = prefs.getString(Constants.fcmTokenKey);

      if (authToken == null || fcmToken == null) return;

      await _dio.post(
        '${Constants.apiBaseUrl}/api/notifications/deactivate-token',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {'fcmToken': fcmToken},
      );

      await prefs.remove(Constants.fcmTokenKey);
      print('FCM token deaktive edildi');
    } catch (e) {
      print('FCM token deaktive etme hatası: $e');
    }
  }

  // Get FCM token
  Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('FCM token alma hatası: $e');
      return null;
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Topic\'e abone olundu: $topic');
    } catch (e) {
      print('Topic abonelik hatası: $e');
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Topic aboneliği iptal edildi: $topic');
    } catch (e) {
      print('Topic abonelik iptal hatası: $e');
    }
  }
}