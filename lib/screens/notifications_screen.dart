// lib/services/notification_service.dart - Eksiksiz ve hatasız versiyon

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
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
    await _createNotificationChannels();
  }

  // Notification channels oluştur
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Default channel
        const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
          'djmobilapp_notifications',
          'DJ Mobil App Bildirimleri',
          description: 'DJ Mobil App genel bildirimleri',
          importance: Importance.high,
          enableLights: true,
          enableVibration: true,
          playSound: true,
        );

        // Music channel
        const AndroidNotificationChannel musicChannel = AndroidNotificationChannel(
          'music_notifications',
          'Müzik Bildirimleri',
          description: 'Müzik ile ilgili bildirimler',
          importance: Importance.high,
          enableLights: true,
          enableVibration: true,
          playSound: true,
        );

        // Promotion channel
        const AndroidNotificationChannel promotionChannel = AndroidNotificationChannel(
          'promotion_notifications',
          'Promosyon Bildirimleri',
          description: 'Promosyon ve kampanya bildirimleri',
          importance: Importance.defaultImportance,
          enableLights: true,
          enableVibration: false,
          playSound: true,
        );

        await androidPlugin.createNotificationChannel(defaultChannel);
        await androidPlugin.createNotificationChannel(musicChannel);
        await androidPlugin.createNotificationChannel(promotionChannel);
      }
    }
  }

  // Firebase messaging setup
  Future<void> _initializeFirebaseMessaging() async {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background message tapped
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // App opened from terminated state
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 2), () {
        _handleBackgroundMessage(initialMessage);
      });
    }

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
        Constants.fullNotificationRegisterTokenUrl,
        options: Options(
          headers: Constants.getDefaultHeaders(authToken: authToken),
        ),
        data: {
          'fcmToken': token,
          'deviceInfo': deviceInfo,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'deviceId': deviceInfo['deviceId'],
          'deviceModel': deviceInfo['deviceModel'],
          'osVersion': deviceInfo['osVersion'],
          'appVersion': deviceInfo['appVersion'],
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
      return {
        'deviceId': 'unknown',
        'deviceModel': 'unknown',
        'osVersion': 'unknown',
        'appVersion': packageInfo.version,
      };
    } catch (e) {
      print('Device info alma hatası: $e');
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

    try {
      final notification = NotificationModel.fromMap(message.data);
      _showLocalNotification(notification, message);

      // Overlay notification göster
      if (_context != null) {
        showOverlayNotification((context) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: ListTile(
              leading: Icon(notification.typeIcon),
              title: Text(notification.title),
              subtitle: Text(notification.body),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => OverlaySupportEntry.of(context)?.dismiss(),
              ),
              onTap: () {
                OverlaySupportEntry.of(context)?.dismiss();
                _handleNotificationTap(message.data);
              },
            ),
          );
        }, duration: const Duration(seconds: 4));
      }

    } catch (e) {
      print('Foreground bildirim işleme hatası: $e');
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(NotificationModel notification, RemoteMessage message) async {
    final String channelId = _getChannelId(notification.type);

    // Basit Android bildirim oluştur
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(notification.type),
      channelDescription: _getChannelDescription(notification.type),
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(
        notification.body,
        contentTitle: notification.title,
        summaryText: 'DJ Mobil App',
      ),
      icon: '@mipmap/ic_launcher',
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

  // Channel ID alma
  String _getChannelId(String type) {
    switch (type) {
      case 'music':
        return 'music_notifications';
      case 'playlist':
        return 'music_notifications';
      case 'promotion':
        return 'promotion_notifications';
      default:
        return 'djmobilapp_notifications';
    }
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

    if (deepLink != null) {
      // Deep link navigation
      print('Deep link navigation: $deepLink');
      // Implement deep link logic here
    } else {
      // Default navigation based on type
      switch (type) {
        case 'music':
        // Navigate to music player or track detail
          break;
        case 'playlist':
        // Navigate to playlist
          break;
        case 'user':
        // Navigate to user profile or activity
          break;
        case 'promotion':
        // Navigate to promotion page
          break;
        default:
        // Navigate to notifications screen
          navigator.pushNamed('/notifications');
          break;
      }
    }
  }

  // Okunmamış bildirim sayısını al
  Future<int> getUnreadNotificationCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return 0;

      final response = await _dio.get(
        Constants.fullNotificationUnreadCountUrl,
        options: Options(
          headers: Constants.getDefaultHeaders(authToken: authToken),
        ),
      );

      if (response.statusCode == 200) {
        return response.data['data']['unreadCount'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Okunmamış bildirim sayısı alma hatası: $e');
      return 0;
    }
  }

  // Bildirimi okundu olarak işaretle
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return false;

      final response = await _dio.put(
        Constants.getFullNotificationMarkReadUrl(notificationId),
        options: Options(
          headers: Constants.getDefaultHeaders(authToken: authToken),
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Bildirim okundu işaretleme hatası: $e');
      return false;
    }
  }

  // Tüm bildirimleri okundu olarak işaretle
  Future<bool> markAllNotificationsAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return false;

      final response = await _dio.put(
        Constants.fullNotificationMarkAllReadUrl,
        options: Options(
          headers: Constants.getDefaultHeaders(authToken: authToken),
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Tümünü okundu işaretleme hatası: $e');
      return false;
    }
  }

  // Update notification settings
  Future<bool> updateNotificationSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return false;

      final response = await _dio.put(
        Constants.fullNotificationSettingsUrl,
        options: Options(
          headers: Constants.getDefaultHeaders(authToken: authToken),
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
        Constants.fullNotificationDeactivateTokenUrl,
        options: Options(
          headers: Constants.getDefaultHeaders(authToken: authToken),
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

  // Bildirim tıklama callback'ini ayarla
  void setOnNotificationTapped(Function(NotificationModel) callback) {
    _onNotificationTapped = callback;
  }

  // Okunmamış bildirim sayısı stream'i (gerçek zamanlı güncelleme için)
  Stream<int> get unreadCountStream async* {
    while (true) {
      yield await getUnreadNotificationCount();
      await Future.delayed(const Duration(seconds: 30)); // 30 saniyede bir güncelle
    }
  }

  // Bildirim dinleyicisini başlat (homepage'de kullanmak için)
  void startNotificationListener(Function(int) onUnreadCountChanged) {
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      final count = await getUnreadNotificationCount();
      onUnreadCountChanged(count);
    });
  }
}