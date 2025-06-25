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

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  final Dio _dio = Dio();
  final ScrollController _scrollController = ScrollController();

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _selectedType = 'all';

  // Settings
  bool _showSettings = false;
  Map<String, dynamic> _notificationSettings = {
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _settingsAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreNotifications();
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
        _notifications.clear();
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await _dio.get(
        '${Constants.apiBaseUrl}/api/notifications/user',
        queryParameters: {
          'page': _currentPage,
          'limit': 20,
          if (_selectedType != 'all') 'type': _selectedType,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data['success']) {
        final data = response.data['data'];
        final notifications = (data['notifications'] as List)
            .map((json) => NotificationModel.fromJson(json))
            .toList();

        setState(() {
          if (refresh || _currentPage == 1) {
            _notifications = notifications;
          } else {
            _notifications.addAll(notifications);
          }

          _hasMore = _currentPage < data['pagination']['totalPages'];
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Bildirim yükleme hatası: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirimler yüklenirken hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _loadNotifications();
  }

  void _onTypeFilterChanged(String type) {
    if (_selectedType != type) {
      setState(() {
        _selectedType = type;
      });
      _loadNotifications(refresh: true);
    }
  }

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

  Future<void> _updateNotificationSettings(String key, dynamic value) async {
    setState(() {
      if (key.contains('.')) {
        final parts = key.split('.');
        _notificationSettings[parts[0]][parts[1]] = value;
      } else {
        _notificationSettings[key] = value;
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      await _dio.put(
        '${Constants.apiBaseUrl}/api/notifications/settings',
        data: {
          'settings': _notificationSettings,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim ayarları güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Ayar güncelleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ayarlar güncellenirken hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onNotificationTap(NotificationModel notification) {
    final data = notification.data ?? {};

    try {
      switch (notification.type) {
        case 'music':
          if (data['musicId'] != null) {
            Navigator.pushNamed(context, '/music-detail',
                arguments: data['musicId']);
          }
          break;
        case 'playlist':
          if (data['playlistId'] != null) {
            Navigator.pushNamed(context, '/playlist-detail',
                arguments: data['playlistId']);
          }
          break;
        case 'user':
          if (data['userId'] != null) {
            Navigator.pushNamed(context, '/user-profile',
                arguments: data['userId']);
          }
          break;
        default:
        // Show detail dialog
          _showNotificationDetail(notification);
          break;
      }
    } catch (e) {
      print('Navigation hatası: $e');
      _showNotificationDetail(notification);
    }
  }

  void _showNotificationDetail(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(notification.body),
              const SizedBox(height: 16),
              if (notification.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: notification.imageUrl!,
                    width: double.infinity,
                    height: 200,
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
                const SizedBox(height: 16),
              ],
              Text(
                'Gönderilme: ${DateFormat('dd/MM/yyyy HH:mm').format(notification.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Bildirimler'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _toggleSettings,
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
                    ? const LoadingWidget()
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
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _onNotificationTap(notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notification icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getTypeColor(notification.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _getTypeIcon(notification.type),
                      color: _getTypeColor(notification.type),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatTimestamp(notification.createdAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notification.body,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Image preview
                        if (notification.imageUrl != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: notification.imageUrl!,
                              width: double.infinity,
                              height: 120,
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

                        const SizedBox(height: 12),

                        // Footer
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getTypeColor(notification.type).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getTypeText(notification.type),
                                style: TextStyle(
                                  color: _getTypeColor(notification.type),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (notification.actions != null &&
                                notification.actions!.isNotEmpty)
                              Icon(
                                Icons.touch_app,
                                color: Colors.blue[600],
                                size: 16,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bildirim Ayarları',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _toggleSettings,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Main settings
          _buildSettingTile(
            'Bildirimleri Etkinleştir',
            _notificationSettings['enabled'],
                (value) => _updateNotificationSettings('enabled', value),
          ),
          _buildSettingTile(
            'Ses',
            _notificationSettings['sound'],
                (value) => _updateNotificationSettings('sound', value),
            enabled: _notificationSettings['enabled'],
          ),
          _buildSettingTile(
            'Titreşim',
            _notificationSettings['vibration'],
                (value) => _updateNotificationSettings('vibration', value),
            enabled: _notificationSettings['enabled'],
          ),
          _buildSettingTile(
            'Badge',
            _notificationSettings['badge'],
                (value) => _updateNotificationSettings('badge', value),
            enabled: _notificationSettings['enabled'],
          ),

          const SizedBox(height: 16),
          const Text(
            'Bildirim Türleri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Type settings
          ..._notificationSettings['types'].entries.map<Widget>((entry) =>
              _buildSettingTile(
                _getTypeText(entry.key),
                entry.value,
                    (value) => _updateNotificationSettings('types.${entry.key}', value),
                enabled: _notificationSettings['enabled'],
              ),
          ).toList(),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
      String title,
      bool value,
      Function(bool) onChanged, {
        bool enabled = true,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: enabled ? Colors.black : Colors.grey,
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: Colors.blue[600],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Şimdi';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}dk önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}s önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}g önce';
    } else {
      return DateFormat('dd/MM/yyyy').format(timestamp);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'music':
        return Icons.music_note;
      case 'playlist':
        return Icons.playlist_play;
      case 'user':
        return Icons.person;
      case 'promotion':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'music':
        return Colors.purple;
      case 'playlist':
        return Colors.green;
      case 'user':
        return Colors.blue;
      case 'promotion':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'music':
        return 'Müzik';
      case 'playlist':
        return 'Playlist';
      case 'user':
        return 'Kullanıcı';
      case 'promotion':
        return 'Promosyon';
      case 'general':
        return 'Genel';
      default:
        return 'Genel';
    }
  }
}