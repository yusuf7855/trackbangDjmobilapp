// lib/utils/fcm_debug_helper.dart - Bu dosyayı oluşturun
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import './constants.dart';

class FCMDebugHelper {
  static Future<void> debugFCMStatus() async {
    print('🔍 FCM Debug Başlıyor...');

    try {
      // 1. Firebase Messaging instance kontrolü
      final messaging = FirebaseMessaging.instance;
      print('✅ FirebaseMessaging instance alındı');

      // 2. FCM Token alma
      final token = await messaging.getToken();
      print('🔑 FCM Token: ${token?.substring(0, 50)}...');

      // 3. Notification permissions kontrolü
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('🔔 Bildirim izni: ${settings.authorizationStatus}');

      // 4. SharedPreferences'dan kullanıcı bilgileri
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(Constants.userIdKey);
      final authToken = prefs.getString(Constants.authTokenKey);
      final savedFCMToken = prefs.getString(Constants.fcmTokenKey);

      print('👤 User ID: $userId');
      print('🔐 Auth Token var mı: ${authToken != null}');
      print('💾 Kaydedilmiş FCM Token: ${savedFCMToken?.substring(0, 30)}...');

      // 5. Token karşılaştırması
      if (token != null && savedFCMToken != null) {
        if (token == savedFCMToken) {
          print('✅ FCM Token tutarlı');
        } else {
          print('⚠️ FCM Token farklı - güncelleme gerekli');
        }
      }

      // 6. Kullanıcı girişi kontrolü
      if (userId != null && authToken != null) {
        print('✅ Kullanıcı giriş yapmış - Token kaydedilebilir');
      } else {
        print('❌ Kullanıcı giriş yapmamış - Token kaydedilemez');
      }

    } catch (e) {
      print('💥 FCM Debug Hatası: $e');
    }

    print('🔍 FCM Debug Tamamlandı\n');
  }

  static Future<void> testFCMTokenRegistration() async {
    print('🧪 FCM Token Kayıt Testi Başlıyor...');

    try {
      // NotificationService instance alın ve token kaydetmeyi deneyin
      // Bu kodu NotificationService'inizde çağırın
      print('🚀 FCM Token kayıt işlemi tetikleniyor...');

      // Test için manuel token kaydı
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();

      if (token != null) {
        print('✅ FCM Token alındı: ${token.substring(0, 30)}...');
        print('📱 Manuel backend kaydı için bu token\'ı kullanın');
      } else {
        print('❌ FCM Token alınamadı');
      }

    } catch (e) {
      print('💥 FCM Token Test Hatası: $e');
    }
  }
}

// FCM Test Helper Class
class FCMTestHelper {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final Dio _dio = Dio();

  // Get device information
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
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
      print('Device info alma hatası: $e');
    }

    return {
      'deviceId': 'unknown',
      'deviceModel': 'unknown',
      'osVersion': 'unknown',
      'appVersion': packageInfo.version,
    };
  }

  // DEBUG: FCM token'ı manuel olarak kaydet
  static Future<void> forceRegisterToken() async {
    print('🔧 FCM Token zorla kaydediliyor...');

    try {
      final token = await _messaging.getToken();
      print('🔑 Alınan FCM Token: ${token?.substring(0, 30)}...');

      if (token == null) {
        print('❌ FCM Token null!');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(Constants.userIdKey);
      final authToken = prefs.getString(Constants.authTokenKey);

      print('👤 User ID: $userId');
      print('🔐 Auth Token: ${authToken?.substring(0, 20)}...');

      if (userId == null || authToken == null) {
        print('❌ Kullanıcı bilgileri eksik!');
        return;
      }

      final deviceInfo = await _getDeviceInfo();
      print('📱 Device Info: $deviceInfo');

      print('📤 Backend\'e token gönderiliyor...');

      final response = await _dio.post(
        '${Constants.apiBaseUrl}/api/notifications/register-token',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'fcmToken': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'deviceId': deviceInfo['deviceId'],
          'deviceModel': deviceInfo['deviceModel'],
          'osVersion': deviceInfo['osVersion'],
          'appVersion': deviceInfo['appVersion'],
        },
      );

      print('📥 Backend Response: ${response.statusCode}');
      print('📄 Response Data: ${response.data}');

      if (response.statusCode == 200) {
        await prefs.setString(Constants.fcmTokenKey, token);
        print('✅ FCM token başarıyla kaydedildi!');
      } else {
        print('❌ Backend\'den hata: ${response.data}');
      }
    } catch (e) {
      print('💥 FCM token zorla kaydetme hatası: $e');
    }
  }
}

// Test widget - Herhangi bir sayfa içinde kullanın
class FCMTestWidget extends StatefulWidget {
  @override
  _FCMTestWidgetState createState() => _FCMTestWidgetState();
}

class _FCMTestWidgetState extends State<FCMTestWidget> {
  @override
  void initState() {
    super.initState();
    _testFCM();
  }

  void _testFCM() async {
    // Firebase başlatıldıktan sonra bekle
    await Future.delayed(Duration(seconds: 2));

    // FCM debug
    await FCMDebugHelper.debugFCMStatus();

    // Kullanıcı giriş yapmışsa token'ı kaydet
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(Constants.userIdKey);

    if (userId != null) {
      print('🔄 Kullanıcı giriş yapmış, FCM token kaydediliyor...');
      await FCMTestHelper.forceRegisterToken();
    } else {
      print('⏳ Kullanıcı giriş yapmamış, FCM token kaydı bekleniyor...');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              await FCMDebugHelper.debugFCMStatus();
            },
            child: Text('FCM Durumunu Kontrol Et'),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              await FCMTestHelper.forceRegisterToken();
            },
            child: Text('FCM Token Zorla Kaydet'),
          ),
        ],
      ),
    );
  }
}