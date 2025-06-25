// lib/firebase_options.dart
// Firebase CLI kullanarak generate edilmesi gereken dosya
// firebase flutterfire configure komutu ile oluşturulmalı
// Bu versiyon sadece Android platformunu destekler

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Bu konfigürasyon SADECE Android platformu için optimize edilmiştir.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Web desteği kaldırıldı
    if (kIsWeb) {
      throw UnsupportedError(
        'Web platformu desteklenmemektedir. Bu uygulama sadece Android için tasarlanmıştır.',
      );
    }

    // Platform kontrolü - sadece Android desteklenir
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS platformu desteklenmemektedir. Bu uygulama sadece Android için tasarlanmıştır.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'macOS platformu desteklenmemektedir. Bu uygulama sadece Android için tasarlanmıştır.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'Windows platformu desteklenmemektedir. Bu uygulama sadece Android için tasarlanmıştır.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Linux platformu desteklenmemektedir. Bu uygulama sadece Android için tasarlanmıştır.',
        );
      default:
        throw UnsupportedError(
          'Bu platform desteklenmemektedir. Sadece Android cihazlarda çalışır.',
        );
    }
  }

  /// Android Firebase Configuration
  /// Bu ayarlar Firebase Console'dan alınmalıdır
  static const FirebaseOptions android = FirebaseOptions(
    // Android API Key - Firebase Console > Project Settings > General > Android apps
    apiKey: 'YOUR_ANDROID_API_KEY',

    // Android App ID - Firebase Console > Project Settings > General > Android apps
    appId: 'YOUR_ANDROID_APP_ID',

    // Messaging Sender ID - Firebase Console > Project Settings > Cloud Messaging
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',

    // Project ID - Firebase Console > Project Settings > General
    projectId: 'YOUR_PROJECT_ID',

    // Storage Bucket - Firebase Console > Storage
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',

    // Android Client ID (isteğe bağlı) - Firebase Console > Project Settings > General > Android apps
    // androidClientId: 'YOUR_ANDROID_CLIENT_ID',

    // Database URL (Realtime Database kullanıyorsanız)
    // databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com/',

    // Auth Domain (Authentication kullanıyorsanız)
    // authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
  );
}

/// Firebase Configuration Helper Class
/// Firebase ayarlarını kontrol etmek ve doğrulamak için yardımcı sınıf
class FirebaseConfigHelper {

  /// Firebase konfigürasyonunun geçerli olup olmadığını kontrol eder
  static bool isConfigurationValid() {
    try {
      final config = DefaultFirebaseOptions.android;

      // Temel alanların dolu olup olmadığını kontrol et
      return config.apiKey.isNotEmpty &&
          config.appId.isNotEmpty &&
          config.messagingSenderId.isNotEmpty &&
          config.projectId.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Platform desteğini kontrol eder
  static bool isPlatformSupported() {
    try {
      DefaultFirebaseOptions.currentPlatform;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Hata mesajları için yardımcı metod
  static String getConfigurationError() {
    if (!isPlatformSupported()) {
      return 'Bu platform desteklenmemektedir. Lütfen Android cihaz kullanın.';
    }

    if (!isConfigurationValid()) {
      return 'Firebase konfigürasyonu eksik. Lütfen firebase_options.dart dosyasını kontrol edin.';
    }

    return '';
  }
}

/// Firebase konfigürasyon constants
class FirebaseConfig {
  // Bildirim kanalları
  static const String defaultNotificationChannelId = 'djmobilapp_notifications';
  static const String defaultNotificationChannelName = 'DJ Mobil App Bildirimleri';
  static const String defaultNotificationChannelDescription = 'DJ Mobil App genel bildirimleri';

  // Bildirim kategorileri
  static const String musicNotificationChannelId = 'music_notifications';
  static const String musicNotificationChannelName = 'Müzik Bildirimleri';

  static const String promotionNotificationChannelId = 'promotion_notifications';
  static const String promotionNotificationChannelName = 'Promosyon Bildirimleri';

  // FCM Topic'leri (Android için)
  static const String allUsersTopicAndroid = 'all_users_android';
  static const String musicLoversTopicAndroid = 'music_lovers_android';
  static const String premiumUsersTopicAndroid = 'premium_users_android';

  // Firebase özellik bayrakları
  static const bool enableAnalytics = true;
  static const bool enableCrashlytics = true;
  static const bool enablePerformanceMonitoring = true;
  static const bool enableRemoteConfig = true;

  // Android özel ayarları
  static const String androidPackageName = 'com.djmobilapp.android';
  static const int minAndroidSdkVersion = 21; // Android 5.0 (API level 21)
  static const int targetAndroidSdkVersion = 34; // Android 14 (API level 34)
}