// lib/utils/constants.dart - Eksiksiz versiyon

class Constants {
  // ✅ API Base URL - Kendi API URL'nizi buraya yazın
  static const String apiBaseUrl = 'http://192.168.1.103:5000'; // DEĞİŞTİRİN!

  // Authentication endpoints
  static const String loginEndpoint = '/api/auth/login';
  static const String registerEndpoint = '/api/auth/register';
  static const String logoutEndpoint = '/api/auth/logout';
  static const String refreshTokenEndpoint = '/api/auth/refresh';

  // User endpoints
  static const String userProfileEndpoint = '/api/user/profile';
  static const String updateProfileEndpoint = '/api/user/update';

  // Music endpoints
  static const String musicListEndpoint = '/api/music/list';
  static const String musicSearchEndpoint = '/api/music/search';
  static const String musicLikeEndpoint = '/api/music/like';
  static const String playlistEndpoint = '/api/playlist';

  // ✅ Notification endpoints - EKSIKSIZ
  static const String notificationRegisterToken = '/api/notifications/register-token';
  static const String notificationUserEndpoint = '/api/notifications/user';
  static const String notificationSettingsEndpoint = '/api/notifications/settings';
  static const String notificationUnreadCountEndpoint = '/api/notifications/unread-count';
  static const String notificationMarkReadEndpoint = '/api/notifications/{id}/read';
  static const String notificationMarkAllReadEndpoint = '/api/notifications/mark-all-read';
  static const String notificationDeactivateTokenEndpoint = '/api/notifications/deactivate-token';
  static const String notificationSendEndpoint = '/api/notifications/send';
  static const String notificationHistoryEndpoint = '/api/notifications/history';

  // Storage keys
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String usernameKey = 'username';
  static const String emailKey = 'email';
  static const String fcmTokenKey = 'fcm_token';
  static const String notificationSettingsKey = 'notification_settings';
  static const String appSettingsKey = 'app_settings';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const int minPageSize = 5;

  // File upload
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'gif'];
  static const List<String> allowedAudioTypes = ['mp3', 'wav', 'flac', 'm4a'];

  // Network timeouts
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
  static const int sendTimeout = 30000; // 30 seconds

  // ✅ Default notification settings
  static const Map<String, dynamic> defaultNotificationSettings = {
    'enabled': true,
    'sound': true,
    'vibration': true,
    'badge': true,
    'general': true,
    'music': true,
    'playlist': true,
    'user': true,
    'promotion': true,
    'marketing': false,
    'system': true,
  };

  // ✅ Default app settings
  static const Map<String, dynamic> defaultAppSettings = {
    'darkMode': true,
    'autoPlay': false,
    'downloadOnWifi': true,
    'highQualityAudio': false,
    'showLyrics': true,
    'shuffleMode': false,
    'repeatMode': 'off', // 'off', 'one', 'all'
  };

  // Theme colors
  static const Map<String, dynamic> themeColors = {
    'primary': 0xFF6200EE,
    'primaryVariant': 0xFF3700B3,
    'secondary': 0xFF03DAC6,
    'secondaryVariant': 0xFF018786,
    'background': 0xFF121212,
    'surface': 0xFF1E1E1E,
    'error': 0xFFCF6679,
    'onPrimary': 0xFFFFFFFF,
    'onSecondary': 0xFF000000,
    'onBackground': 0xFFFFFFFF,
    'onSurface': 0xFFFFFFFF,
    'onError': 0xFF000000,
  };

  // Music player constants
  static const double minVolume = 0.0;
  static const double maxVolume = 1.0;
  static const double defaultVolume = 0.7;
  static const Duration seekInterval = Duration(seconds: 10);
  static const Duration updateInterval = Duration(milliseconds: 500);

  // Validation constants
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
  static const int maxBioLength = 500;
  static const int maxPlaylistNameLength = 100;

  // Firebase constants
  static const String firebaseStorageBucket = 'djmobilapp-default-rtdb.firebaseio.com';
  static const String firebaseProjectId = 'djmobilapp';

  // ✅ HELPER METHODS

  // API URL builders
  static String buildApiUrl(String endpoint) {
    return apiBaseUrl + endpoint;
  }

  static String buildNotificationMarkReadUrl(String notificationId) {
    return notificationMarkReadEndpoint.replaceAll('{id}', notificationId);
  }

  static String buildMusicUrl(String musicId) {
    return '$musicListEndpoint/$musicId';
  }

  static String buildPlaylistUrl(String playlistId) {
    return '$playlistEndpoint/$playlistId';
  }

  static String buildUserProfileUrl(String userId) {
    return '$userProfileEndpoint/$userId';
  }

  // Full URL builders
  static String get fullNotificationUnreadCountUrl => buildApiUrl(notificationUnreadCountEndpoint);
  static String get fullNotificationMarkAllReadUrl => buildApiUrl(notificationMarkAllReadEndpoint);
  static String get fullNotificationSettingsUrl => buildApiUrl(notificationSettingsEndpoint);
  static String get fullNotificationRegisterTokenUrl => buildApiUrl(notificationRegisterToken);
  static String get fullNotificationDeactivateTokenUrl => buildApiUrl(notificationDeactivateTokenEndpoint);
  static String get fullNotificationUserUrl => buildApiUrl(notificationUserEndpoint);
  static String get fullLoginUrl => buildApiUrl(loginEndpoint);
  static String get fullRegisterUrl => buildApiUrl(registerEndpoint);
  static String get fullLogoutUrl => buildApiUrl(logoutEndpoint);

  static String getFullNotificationMarkReadUrl(String notificationId) {
    return buildApiUrl(buildNotificationMarkReadUrl(notificationId));
  }

  // Validation helpers
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  static bool isValidUsername(String username) {
    return username.length >= minUsernameLength &&
        username.length <= maxUsernameLength &&
        RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username);
  }

  static bool isValidPassword(String password) {
    return password.length >= minPasswordLength &&
        password.length <= maxPasswordLength;
  }

  // File validation
  static bool isValidImageFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return allowedImageTypes.contains(extension);
  }

  static bool isValidAudioFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return allowedAudioTypes.contains(extension);
  }

  static String getFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.bitLength - 1) ~/ 10;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  // Time formatting
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} yıl önce';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} ay önce';
    } else if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} hafta önce';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Şimdi';
    }
  }

  // Network helpers
  static Map<String, String> getDefaultHeaders({String? authToken}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    return headers;
  }

  // Error messages
  static const Map<String, String> errorMessages = {
    'network_error': 'İnternet bağlantınızı kontrol edin',
    'server_error': 'Sunucu hatası, lütfen daha sonra tekrar deneyin',
    'auth_error': 'Oturum süreniz dolmuş, tekrar giriş yapın',
    'validation_error': 'Girilen bilgiler geçersiz',
    'not_found': 'İstenen kaynak bulunamadı',
    'permission_denied': 'Bu işlem için yetkiniz yok',
    'file_too_large': 'Dosya boyutu çok büyük',
    'invalid_file_type': 'Geçersiz dosya türü',
    'upload_failed': 'Dosya yüklenemedi',
    'download_failed': 'Dosya indirilemedi',
  };

  // Success messages
  static const Map<String, String> successMessages = {
    'login_success': 'Başarıyla giriş yapıldı',
    'register_success': 'Hesap başarıyla oluşturuldu',
    'logout_success': 'Çıkış yapıldı',
    'profile_updated': 'Profil güncellendi',
    'password_changed': 'Şifre değiştirildi',
    'file_uploaded': 'Dosya yüklendi',
    'settings_saved': 'Ayarlar kaydedildi',
    'notification_sent': 'Bildirim gönderildi',
    'music_liked': 'Müzik beğenildi',
    'playlist_created': 'Çalma listesi oluşturuldu',
    'playlist_updated': 'Çalma listesi güncellendi',
  };
}