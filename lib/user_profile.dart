import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'playlist_card.dart';
import './url_constants.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with TickerProviderStateMixin {
  // State variables
  Map<String, dynamic>? userData;
  List<dynamic> playlists = [];
  bool isLoading = true;
  bool isFollowing = false;
  int followerCount = 0;
  int followingCount = 0;
  String? authToken;
  String? currentUserId;
  bool isCurrentUser = false;

  // Tab kontrolü için
  late TabController _tabController;

  // WebView management
  int? currentlyExpandedIndex;
  final Map<String, WebViewController> activeWebViews = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadToken();
    await fetchUserProfile();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        authToken = prefs.getString('auth_token');
        // Hem userId hem de user_id'yi kontrol et (tutarlılık için)
        currentUserId = prefs.getString('userId') ?? prefs.getString('user_id');
        isCurrentUser = currentUserId == widget.userId;
      });
      print('Auth token loaded: ${authToken != null}'); // Debug log
      print('Current user ID: $currentUserId'); // Debug log
      print('Viewing user ID: ${widget.userId}'); // Debug log
      print('Is current user: $isCurrentUser'); // Debug log
    }
  }

  Future<void> fetchUserProfile() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/user/${widget.userId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            userData = data;
            followerCount = data['followers']?.length ?? 0;
            followingCount = data['following']?.length ?? 0;
            isLoading = false;

            // Check if current user is following this user
            if (currentUserId != null && data['followers'] != null) {
              isFollowing = data['followers'].any((follower) =>
              follower['_id'] == currentUserId || follower == currentUserId);
            }
          });
        }
        await fetchPlaylists();
      } else {
        _handleFetchError("Profil yüklenemedi");
      }
    } catch (e) {
      _handleFetchError("Bir hata oluştu: $e");
    }
  }

  void _handleFetchError(String message) {
    if (mounted) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> fetchPlaylists() async {
    if (!mounted) return;

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/${widget.userId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted && data['success'] == true) {
          setState(() {
            playlists = _parsePlaylistData(data['playlists']);
          });
        }
      }
    } catch (e) {
      // Playlist yükleme hatası - sessizce göz ardı et
    }
  }

  List<dynamic> _parsePlaylistData(List<dynamic>? playlists) {
    return (playlists ?? []).where((playlist) => playlist['isPublic'] == true).map((playlist) {
      return {
        '_id': playlist['_id']?.toString(),
        'name': playlist['name']?.toString() ?? 'Untitled Playlist',
        'description': playlist['description']?.toString() ?? '',
        'musicCount': playlist['musicCount'] ?? 0,
        'musics': (playlist['musics'] as List<dynamic>?)?.map((music) {
          return {
            'title': music['title']?.toString(),
            'artist': music['artist']?.toString(),
            'spotifyId': music['spotifyId']?.toString(),
          };
        }).toList() ?? [],
      };
    }).toList();
  }

  Future<void> toggleFollow() async {
    if (authToken == null || userData == null || !mounted) return;

    try {
      final endpoint = isFollowing ? 'unfollow' : 'follow';
      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/$endpoint/${userData!['_id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          isFollowing = !isFollowing;
          followerCount += isFollowing ? 1 : -1;
        });
        _showSuccessSnackbar(isFollowing ? "Takip edildi" : "Takip bırakıldı");
      }
    } catch (e) {
      _showErrorSnackbar("Bir hata oluştu: $e");
    }
  }

  void _handleExpansionChanged(int index, bool expanded) {
    if (!mounted) return;

    if (expanded) {
      _cleanupPreviousWebViews(index);
      setState(() => currentlyExpandedIndex = index);
    } else if (currentlyExpandedIndex == index) {
      _cleanupWebViewsForIndex(index);
      setState(() => currentlyExpandedIndex = null);
    }
  }

  void _cleanupPreviousWebViews(int currentIndex) {
    if (currentlyExpandedIndex != null && currentlyExpandedIndex != currentIndex) {
      final keysToRemove = activeWebViews.keys
          .where((key) => key.startsWith('${currentlyExpandedIndex}-'))
          .toList();
      for (var key in keysToRemove) {
        activeWebViews.remove(key);
      }
    }
  }

  void _cleanupWebViewsForIndex(int index) {
    final keysToRemove = activeWebViews.keys
        .where((key) => key.startsWith('$index-'))
        .toList();
    for (var key in keysToRemove) {
      activeWebViews.remove(key);
    }
  }

  ImageProvider _getProfileImage() {
    if (userData?['profileImage'] != null &&
        userData!['profileImage'].isNotEmpty) {
      return NetworkImage('${UrlConstants.apiBaseUrl}${userData!['profileImage']}');
    }
    return const AssetImage('assets/default_profile.png');
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Future<void> _launchURL(String url) async {
    try {
      String formattedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        formattedUrl = 'https://$url';
      }

      final Uri uri = Uri.parse(formattedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackbar("Link açılamadı");
      }
    } catch (e) {
      _showErrorSnackbar("Geçersiz link: $e");
    }
  }

  void _showImageGallery(int initialIndex) {
    final additionalImages = userData?['additionalImages'] as List<dynamic>? ?? [];
    if (additionalImages.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => ImageGalleryDialog(
        images: additionalImages.map((img) => {
          'url': '${UrlConstants.apiBaseUrl}${img['url']}',
          'filename': img['filename']
        }).toList(),
        initialIndex: initialIndex,
      ),
    );
  }

  // Ana profil header
  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profil Fotoğrafı
              CircleAvatar(
                radius: 45,
                backgroundImage: _getProfileImage(),
              ),
              const SizedBox(width: 20),

              // Profil bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // İsim ve kullanıcı adı
                    Text(
                      '${userData?['firstName']} ${userData?['lastName']}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '@${userData?['username']}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Biyografi - compact hali
                    if (userData?['bio'] != null && userData!['bio'].isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        userData!['bio'],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 16),

                    // İstatistikler
                    Row(
                      children: [
                        _buildCompactStat(followerCount, "Takipçi"),
                        const SizedBox(width: 20),
                        _buildCompactStat(followingCount, "Takip"),
                        const SizedBox(width: 20),
                        _buildCompactStat(playlists.length, "Playlist"),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Linkler - daha compact
          if (userData?['profileLinks'] != null && (userData!['profileLinks'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (userData!['profileLinks'] as List).take(3).map((link) {
                return InkWell(
                  onTap: () => _launchURL(link['url']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[600]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          link['title'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Takip butonu (sadece başka kullanıcılar için)
          if (!isCurrentUser && authToken != null) ...[
            const SizedBox(height: 20),
            _buildFollowButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactStat(int count, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[700]!),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton() {
    print('Building follow button - isCurrentUser: $isCurrentUser, authToken: ${authToken != null}'); // Debug log

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isFollowing ? Colors.grey[700] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: ElevatedButton(
        onPressed: toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          isFollowing ? "Takibi Bırak" : "Takip Et",
          style: TextStyle(
            fontSize: 16,
            color: isFollowing ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Fotoğraf galerisi
  Widget _buildPhotoGallery() {
    final additionalImages = userData?['additionalImages'] as List<dynamic>? ?? [];
    if (additionalImages.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.photo_library, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                "Fotoğraflar",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: additionalImages.asMap().entries.map((entry) {
              final index = entry.key;
              final image = entry.value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _showImageGallery(index),
                  child: Container(
                    height: 90,
                    margin: EdgeInsets.only(
                      right: index < additionalImages.length - 1 ? 8 : 0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '${UrlConstants.apiBaseUrl}${image['url']}',
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(
            icon: Icon(Icons.event),
            text: "Etkinlikler",
          ),
          Tab(
            icon: Icon(Icons.library_music),
            text: "Playlists",
          ),
        ],
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey[400],
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildEventsSection() {
    final events = userData?['events'] as List<dynamic>? ?? [];

    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!, width: 1),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_busy,
              color: Colors.grey[600],
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              "Henüz etkinlik eklenmemiş",
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: events.map((event) {
        final eventDate = DateTime.parse(event['date']);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!, width: 1),
          ),
          child: Row(
            children: [
              // Sol taraf - Takvim
              Container(
                width: 70,
                height: 70,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getMonthName(eventDate.month),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      eventDate.day.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Sağ taraf - Etkinlik detayları
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['city'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.grey[400],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event['time'],
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.grey[400],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event['venue'],
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlaylistsSection() {
    return Column(
      children: [
        if (playlists.isEmpty)
          _buildEmptyPlaylistMessage()
        else
          ...playlists.asMap().entries.map((entry) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: PlaylistCard(
              playlist: entry.value,
              index: entry.key,
              currentlyExpandedIndex: currentlyExpandedIndex,
              onExpansionChanged: _handleExpansionChanged,
              activeWebViews: activeWebViews,
              cachedWebViews: {},
            ),
          )),
      ],
    );
  }

  Widget _buildEmptyPlaylistMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.library_music_outlined,
            color: Colors.grey[600],
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            "Henüz public playlist yok",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                "Profil yükleniyor...",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (userData == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_off,
                  color: Colors.grey[600],
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Kullanıcı bulunamadı",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Bu profil mevcut değil",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          '${userData!['firstName']} ${userData!['lastName']}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Ana profil header
                    _buildProfileHeader(),
                    const SizedBox(height: 16),

                    // Fotoğraf galerisi
                    _buildPhotoGallery(),
                    const SizedBox(height: 16),

                    // Tab bar
                    _buildTabBar(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // Etkinlikler sekmesi
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildEventsSection(),
                    const SizedBox(height: 100), // Alt padding
                  ],
                ),
              ),
              // Playlists sekmesi
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildPlaylistsSection(),
                    const SizedBox(height: 100), // Alt padding
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Fotoğraf galerisi için dialog widget
class ImageGalleryDialog extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;

  const ImageGalleryDialog({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<ImageGalleryDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Colors.black87,
        child: Stack(
          children: [
            // Fotoğraflar
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      widget.images[index]['url'] as String,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.grey[600],
                            size: 64,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),

            // Üst bar - kapat butonu ve sayaç
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sol ok
            if (widget.images.length > 1)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      if (_currentIndex > 0) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios,
                        color: _currentIndex > 0 ? Colors.white : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

            // Sağ ok
            if (widget.images.length > 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      if (_currentIndex < widget.images.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        color: _currentIndex < widget.images.length - 1 ? Colors.white : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

            // Alt göstergeler
            if (widget.images.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 32,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.images.asMap().entries.map((entry) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == entry.key
                            ? Colors.white
                            : Colors.white38,
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}