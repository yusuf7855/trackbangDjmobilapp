// lib/utils/constants.dart
class Constants {
  // API Configuration
  static const String apiBaseUrl = 'http://YOUR_API_URL:5000'; // API URL'inizi buraya yazın

  // Firebase Configuration (google-services.json/plist'ten alınır)
  static const String firebaseProjectId = 'your-firebase-project-id';

  // SharedPreferences Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyFcmToken = 'fcm_token';
  static const String keyNotificationSettings = 'notification_settings';

  // Notification Types
  static const String notificationTypeGeneral = 'general';
  static const String notificationTypeMusic = 'music';
  static const String notificationTypePlaylist = 'playlist';
  static const String notificationTypeUser = 'user';
  static const String notificationTypePromotion = 'promotion';

  // Notification Actions
  static const String actionViewDetail = 'view_detail';
  static const String actionClose = 'close';
  static const String actionOpenUrl = 'open_url';

  // Routes
  static const String routeHome = '/';
  static const String routeNotifications = '/notifications';
  static const String routeMusicDetail = '/music-detail';
  static const String routePlaylistDetail = '/playlist-detail';
  static const String routeUserProfile = '/user-profile';
  static const String routeLogin = '/login';

  // Default notification settings
  static const Map<String, dynamic> defaultNotificationSettings = {
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
  };

  // Colors
  static const int primaryColor = 0xFF2196F3;
  static const int successColor = 0xFF4CAF50;
  static const int errorColor = 0xFFF44336;
  static const int warningColor = 0xFFFF9800;

  // Text Sizes
  static const double textSizeSmall = 12.0;
  static const double textSizeMedium = 14.0;
  static const double textSizeLarge = 16.0;
  static const double textSizeXLarge = 18.0;

  // Spacing
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Animation Durations
  static const int animationDurationShort = 200;
  static const int animationDurationMedium = 300;
  static const int animationDurationLong = 500;
}