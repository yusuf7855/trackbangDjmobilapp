// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';
import '../widgets/loading_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  final Dio _dio = Dio();
  final ScrollController _scrollController = ScrollController();
  final NotificationService _notificationService = NotificationService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _selectedType = 'all';

  // Settings
  bool _showSettings = false;
  Map<String, dynamic> _notificationSettings = Constants.defaultNotificationSettings;

  late AnimationController _settingsAnimationController;
  late Animation<double> _settingsAnimation;

  @override
  void initState() {
    super.initState();
    _settingsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _settingsAnimation = CurvedAnimation(
      parent: _settingsAnimationController,
      curve: Curves.easeInOut,
    );

    _scrollController.addListener(_onScroll);
    _loadNotifications();
    _loadNotificationSettings();

    // Notification service callback
    _notificationService.setOnNotificationTapped((notification) {
      _handleNotificationTapped(notification);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _settingsAnimationController.dispose();
    super.dispose();
  }

  // Load notifications from backend
  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _notifications.clear();
        _currentPage = 1;
        _hasMore = true;
        _isLoading = true;
      });
    }

    if (!_hasMore || _isLoadingMore) return;

    setState(() {
      if (_currentPage == 1) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) {
        throw Exception('Kullanıcı girişi gerekli');
      }

      final queryParams = {
        'page': _currentPage.toString(),
        'limit': Constants.defaultPageSize.toString(),
        if (_selectedType != 'all') 'type': _selectedType,
      };

      final response = await _dio.get(
        '${Constants.apiBaseUrl}${Constants.notificationUserEndpoint}',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final notificationsJson = data['notifications'] as List;
        final pagination = data['pagination'];

        final newNotifications = notificationsJson
            .map((json) => NotificationModel.fromJson(json))
            .toList();

        setState(() {
          if (refresh || _currentPage == 1) {
            _notifications = newNotifications;
          } else {
            _notifications.addAll(newNotifications);
          }

          _currentPage = pagination['currentPage'] + 1;
          _hasMore = pagination['currentPage'] < pagination['totalPages'];
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        throw Exception(response.data['message'] ?? 'Bildirimler yüklenemedi');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bildirimler yüklenirken hata: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: () => _loadNotifications(refresh: true),
            ),
          ),
        );
      }
    }
  }

  // Load notification settings
  Future<void> _loadNotificationSettings() async {
    final settings = await _notificationService.getNotificationSettings();
    setState(() {
      _notificationSettings = settings;
    });
  }

  // Handle notification tapped
  void _handleNotificationTapped(NotificationModel notification) {
    _showNotificationDetail(notification);
  }

  // Scroll listener for pagination
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadNotifications();
    }
  }

  // Filter notifications by type
  void _onTypeFilterChanged(String type) {
    if (_selectedType != type) {
      setState(() {
        _selectedType = type;
      });
      _loadNotifications(refresh: true);
    }
  }

  // Toggle settings panel
  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
    });

    if (_showSettings) {
      _settingsAnimationController.forward();
    } else {
      _settingsAnimationController.reverse();
    }
  }

  // Update notification settings
  Future<void> _updateNotificationSettings() async {
    final success = await _notificationService.updateNotificationSettings(_notificationSettings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Bildirim ayarları güncellendi'
                : 'Ayarlar güncellenirken hata oluştu',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // Show notification detail dialog
  void _showNotificationDetail(NotificationModel notification) {
    // Mark as read if not already
    if (!notification.isRead) {
      _markNotificationAsRead(notification);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              notification.typeIcon,
              color: notification.typeColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notification.title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            IconButton(
              onPressed: () => _showDeleteConfirmation(notification),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Sil',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Body text
              Text(
                notification.body,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),

              // Image if available
              if (notification.imageUrl != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: notification.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Time and type info
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(notification.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: notification.typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: notification.typeColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _getTypeDisplayName(notification.type),
                      style: TextStyle(
                        fontSize: 12,
                        color: notification.typeColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  // Mark single notification as read
  Future<void> _markNotificationAsRead(NotificationModel notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return;

      await _dio.put(
        '${Constants.apiBaseUrl}/api/notifications/${notification.id}/read',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      // Update local state
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notification.copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        }
      });
    } catch (e) {
      print('Bildirim okundu işaretleme hatası: $e');
    }
  }

  // Build filter chip
  Widget _buildFilterChip(String type, String label) {
    final isSelected = _selectedType == type;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => _onTypeFilterChanged(type),
        selectedColor: Colors.blue[100],
        checkmarkColor: Colors.blue[800],
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue[800] : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.grey[200],
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey[400]!,
          width: 1,
        ),
      ),
    );
  }

  // Build notification card
  Widget _buildNotificationCard(NotificationModel notification) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: notification.isRead ? 1 : 3,
      child: InkWell(
        onTap: () => _showNotificationDetail(notification),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: notification.isRead ? null : Colors.blue[50],
            border: notification.isRead
                ? null
                : Border.all(color: Colors.blue[200]!, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: notification.typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  notification.typeIcon,
                  color: notification.typeColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and time
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          notification.timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Body
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Image preview
                    if (notification.imageUrl != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: notification.imageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 120,
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build settings panel
  Widget _buildSettingsPanel() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.settings, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Bildirim Ayarları',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _toggleSettings,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // General settings
            SwitchListTile(
              title: const Text('Bildirimler'),
              subtitle: const Text('Tüm bildirimleri aç/kapat'),
              value: _notificationSettings['enabled'] ?? true,
              onChanged: (value) {
                setState(() {
                  _notificationSettings['enabled'] = value;
                });
                _updateNotificationSettings();
              },
            ),

            SwitchListTile(
              title: const Text('Ses'),
              subtitle: const Text('Bildirim sesi'),
              value: _notificationSettings['sound'] ?? true,
              onChanged: _notificationSettings['enabled']
                  ? (value) {
                setState(() {
                  _notificationSettings['sound'] = value;
                });
                _updateNotificationSettings();
              }
                  : null,
            ),

            SwitchListTile(
              title: const Text('Titreşim'),
              subtitle: const Text('Bildirim titreşimi'),
              value: _notificationSettings['vibration'] ?? true,
              onChanged: _notificationSettings['enabled']
                  ? (value) {
                setState(() {
                  _notificationSettings['vibration'] = value;
                });
                _updateNotificationSettings();
              }
                  : null,
            ),

            const Divider(height: 32),

            // Type settings
            const Text(
              'Bildirim Türleri',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            ...Constants.notificationTypes.map((type) {
              final typeSettings = _notificationSettings['types'] ?? {};
              final isEnabled = typeSettings[type] ?? true;

              return SwitchListTile(
                title: Text(_getTypeDisplayName(type)),
                subtitle: Text(_getTypeDescription(type)),
                value: isEnabled && (_notificationSettings['enabled'] ?? true),
                onChanged: _notificationSettings['enabled']
                    ? (value) {
                  setState(() {
                    if (_notificationSettings['types'] == null) {
                      _notificationSettings['types'] = {};
                    }
                    _notificationSettings['types'][type] = value;
                  });
                  _updateNotificationSettings();
                }
                    : null,
              );
            }).toList(),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _toggleSettings,
                  child: const Text('İptal'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _updateNotificationSettings();
                    _toggleSettings();
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Get type display name
  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'general':
        return 'Genel';
      case 'music':
        return 'Müzik';
      case 'playlist':
        return 'Playlist';
      case 'user':
        return 'Kullanıcı';
      case 'promotion':
        return 'Promosyon';
      default:
        return type;
    }
  }

  // Get type description
  String _getTypeDescription(String type) {
    switch (type) {
      case 'general':
        return 'Genel uygulama bildirimleri';
      case 'music':
        return 'Yeni müzik ve çalma listesi bildirimleri';
      case 'playlist':
        return 'Playlist güncellemeleri';
      case 'user':
        return 'Kullanıcı etkileşimleri';
      case 'promotion':
        return 'Promosyon ve kampanyalar';
      default:
        return '';
    }
  }

  // Get unread count
  int get _unreadCount {
    return _notifications.where((notification) => !notification.isRead).length;
  }

  // Mark all notifications as read
  Future<void> _markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return;

      await _dio.put(
        '${Constants.apiBaseUrl}/api/notifications/mark-all-read',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      // Update local state
      setState(() {
        _notifications = _notifications.map((notification) {
          return notification.copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        }).toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm bildirimler okundu olarak işaretlendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Delete notification
  Future<void> _deleteNotification(NotificationModel notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(Constants.authTokenKey);

      if (authToken == null) return;

      await _dio.delete(
        '${Constants.apiBaseUrl}/api/notifications/${notification.id}',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      // Remove from local state
      setState(() {
        _notifications.removeWhere((n) => n.id == notification.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim silindi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silme işlemi başarısız: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show delete confirmation
  void _showDeleteConfirmation(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bildirimi Sil'),
        content: const Text('Bu bildirimi silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteNotification(notification);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // Show more options bottom sheet
  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // Title
            const Text(
              'Bildirim Seçenekleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // Mark all as read
            if (_unreadCount > 0)
              ListTile(
                leading: const Icon(Icons.mark_email_read),
                title: Text('Tümünü Okundu İşaretle ($_unreadCount)'),
                onTap: () {
                  Navigator.of(context).pop();
                  _markAllAsRead();
                },
              ),

            // Settings
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Bildirim Ayarları'),
              onTap: () {
                Navigator.of(context).pop();
                _toggleSettings();
              },
            ),

            // Refresh
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Yenile'),
              onTap: () {
                Navigator.of(context).pop();
                _loadNotifications(refresh: true);
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Bildirimler'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              onPressed: _markAllAsRead,
              tooltip: 'Tümünü Okundu İşaretle',
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Filter tabs
              Container(
                height: 50,
                margin: const EdgeInsets.all(16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('all', 'Tümü'),
                    _buildFilterChip('general', 'Genel'),
                    _buildFilterChip('music', 'Müzik'),
                    _buildFilterChip('playlist', 'Playlist'),
                    _buildFilterChip('user', 'Kullanıcı'),
                    _buildFilterChip('promotion', 'Promosyon'),
                  ],
                ),
              ),

              // Notifications list
              Expanded(
                child: _isLoading
                    ? const LoadingWidget(message: 'Bildirimler yükleniyor...')
                    : _notifications.isEmpty
                    ? EmptyStateWidget(
                  icon: Icons.notifications_none,
                  title: 'Henüz bildirim yok',
                  subtitle: 'Yeni bildirimler burada görünecek',
                  onRefresh: () => _loadNotifications(refresh: true),
                )
                    : RefreshIndicator(
                  onRefresh: () => _loadNotifications(refresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      return _buildNotificationCard(_notifications[index]);
                    },
                  ),
                ),
              ),
            ],
          ),

          // Settings overlay
          if (_showSettings)
            AnimatedBuilder(
              animation: _settingsAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _settingsAnimation.value,
                  child: Container(
                    color: Colors.black.withOpacity(0.5 * _settingsAnimation.value),
                    child: Center(
                      child: Transform.scale(
                        scale: 0.8 + (0.2 * _settingsAnimation.value),
                        child: _buildSettingsPanel(),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}