// lib/utils/constants.dart
class Constants {
  // API Base URL - backend URL'nizi buraya yazın
  static const String apiBaseUrl = 'http://localhost:3000'; // Kendi backend URL'nizi yazın

  // Notification API endpoints
  static const String notificationRegisterToken = '/api/notifications/register-token';
  static const String notificationUserEndpoint = '/api/notifications/user';
  static const String notificationSettingsEndpoint = '/api/notifications/settings';
  static const String notificationSendEndpoint = '/api/notifications/send';
  static const String notificationHistoryEndpoint = '/api/notifications/history';
  static const String notificationStatsEndpoint = '/api/notifications/stats';

  // Notification types
  static const List<String> notificationTypes = [
    'general',
    'music',
    'playlist',
    'user',
    'promotion',
  ];

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  // Cache keys
  static const String authTokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String fcmTokenKey = 'fcm_token';
  static const String notificationSettingsKey = 'notification_settings';

  // Default values
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

  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 300);
  static const Duration mediumAnimation = Duration(milliseconds: 500);
  static const Duration longAnimation = Duration(milliseconds: 800);

  // Colors
  static const Map<String, int> brandColors = {
    'primary': 0xFF1976D2,
    'secondary': 0xFF424242,
    'accent': 0xFFFF9800,
    'error': 0xFFD32F2F,
    'success': 0xFF388E3C,
    'warning': 0xFFF57C00,
  };

  // Text sizes
  static const Map<String, double> textSizes = {
    'small': 12.0,
    'medium': 14.0,
    'large': 16.0,
    'xlarge': 18.0,
    'xxlarge': 20.0,
    'title': 24.0,
  };

  // Spacing
  static const Map<String, double> spacing = {
    'xs': 4.0,
    'sm': 8.0,
    'md': 16.0,
    'lg': 24.0,
    'xl': 32.0,
    'xxl': 48.0,
  };

  // Border radius
  static const double borderRadius = 8.0;
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 25.0;
}