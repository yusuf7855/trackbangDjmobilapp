// lib/services/notification_permission_service.dart - Bu dosyayı oluşturun

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class NotificationPermissionService {
  static const String _permissionAskedKey = 'notification_permission_asked';
  static const String _permissionGrantedKey = 'notification_permission_granted';

  // Uygulama başladığında izin kontrolü yap
  static Future<void> checkAndRequestPermission(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasAsked = prefs.getBool(_permissionAskedKey) ?? false;

    // Eğer daha önce sorulmadıysa, dialog göster
    if (!hasAsked) {
      await _showPermissionDialog(context);
    } else {
      // Daha önce sorulmuşsa, mevcut durumu kontrol et
      await _checkCurrentPermissionStatus();
    }
  }

  // Bildirim izin dialog'u göster
  static Future<void> _showPermissionDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Dialog dışına tıklayarak kapatılamaz
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bildirimler',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yeni şarkılar, playlist güncellemeleri ve özel etkinlikler hakkında bildirim almak ister misiniz?',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.music_note,
                      color: Colors.blue,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Yeni müzikler ve hot listeler için anlık bildirimler',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handlePermissionDenied();
              },
              child: Text(
                'Şimdi Değil',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handlePermissionGranted(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'İzin Ver',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // İzin verildiğinde
  static Future<void> _handlePermissionGranted(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionAskedKey, true);

    try {
      // Firebase Messaging permission iste
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print('🔔 Firebase izin durumu: ${settings.authorizationStatus}');

      // Android 13+ için ek izin
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        print('📱 Android bildirim izni: $status');
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await prefs.setBool(_permissionGrantedKey, true);

        // Başarılı mesajı göster
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Bildirimler aktif edildi!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // FCM token'ı kaydet
        await _registerFCMToken();
      } else {
        await prefs.setBool(_permissionGrantedKey, false);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bildirim izni reddedildi'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ İzin verme hatası: $e');
    }
  }

  // İzin reddedildiğinde
  static Future<void> _handlePermissionDenied() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionAskedKey, true);
    await prefs.setBool(_permissionGrantedKey, false);

    print('⚠️ Kullanıcı bildirim izni vermedi');
  }

  // Mevcut izin durumunu kontrol et
  static Future<void> _checkCurrentPermissionStatus() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();

      print('📋 Mevcut izin durumu: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _registerFCMToken();
      }
    } catch (e) {
      print('❌ İzin durumu kontrolü hatası: $e');
    }
  }

  // FCM Token'ı backend'e kaydet
  static Future<void> _registerFCMToken() async {
    try {
      print('🔄 FCM Token kaydediliyor...');

      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();

      if (token == null) {
        print('❌ FCM Token alınamadı');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final authToken = prefs.getString('auth_token');

      if (userId == null || authToken == null) {
        print('⚠️ Kullanıcı giriş yapmamış, token kaydı beklemede');
        // Token'ı local'e kaydet, login sonrası kaydedilecek
        await prefs.setString('pending_fcm_token', token);
        return;
      }

      // Backend'e kaydet
      final dio = Dio();
      final response = await dio.post(
        'http://192.168.1.103:5000/api/notifications/register-token',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'fcmToken': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'deviceId': 'device_${DateTime.now().millisecondsSinceEpoch}',
          'deviceModel': 'Flutter Device',
          'osVersion': Platform.operatingSystemVersion,
          'appVersion': '1.0.0',
        },
      );

      if (response.statusCode == 200) {
        await prefs.setString('fcm_token', token);
        print('✅ FCM token başarıyla backend\'e kaydedildi!');
      }
    } catch (e) {
      print('❌ FCM token kaydetme hatası: $e');
    }
  }

  // Manuel izin isteme (ayarlar sayfası için)
  static Future<bool> requestPermissionManually(BuildContext context) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (Platform.isAndroid) {
        await Permission.notification.request();
      }

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_permissionGrantedKey, granted);

      if (granted) {
        await _registerFCMToken();
      }

      return granted;
    } catch (e) {
      print('❌ Manuel izin isteme hatası: $e');
      return false;
    }
  }

  // İzin durumunu kontrol et
  static Future<bool> isPermissionGranted() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      return false;
    }
  }
}

