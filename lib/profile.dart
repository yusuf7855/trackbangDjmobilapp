import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_playlist_card.dart'; // YENİ IMPORT
import './url_constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  // State variables
  Map<String, dynamic>? userData;
  List<dynamic> playlists = [];
  bool isLoading = true;
  bool isFollowing = false;
  int followerCount = 0;
  int followingCount = 0;
  String? authToken;
  String? currentUserId;
  File? _imageFile;
  bool _isUpdatingImage = false;
  final ImagePicker _picker = ImagePicker();

  // Düzenleme modu için yeni değişkenler
  bool isEditing = false;
  List<File> _additionalImages = [];
  List<Map<String, dynamic>> _currentAdditionalImages = [];

  // Tab kontrolü için
  int selectedTabIndex = 0; // 0: Etkinlikler, 1: Playlists
  late TabController _tabController;

  // Form kontrolcüleri
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // Linkler için
  List<Map<String, String>> _profileLinks = [];
  final TextEditingController _linkTitleController = TextEditingController();
  final TextEditingController _linkUrlController = TextEditingController();

  // Etkinlik formu için
  List<Map<String, dynamic>> _events = [];
  final TextEditingController _eventCityController = TextEditingController();
  final TextEditingController _eventVenueController = TextEditingController();
  final TextEditingController _eventTimeController = TextEditingController();
  DateTime? _selectedEventDate;

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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _linkTitleController.dispose();
    _linkUrlController.dispose();
    _eventCityController.dispose();
    _eventVenueController.dispose();
    _eventTimeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadToken();
    if (mounted && authToken != null && authToken!.isNotEmpty) {
      await fetchCurrentUser();
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        authToken = prefs.getString('auth_token');
        currentUserId = prefs.getString('userId') ?? prefs.getString('user_id');
      });
    }
  }

  // YENİ: Current user kontrolü
  bool get isCurrentUser {
    return currentUserId == userData?['_id'];
  }

  void _populateFormFields() {
    if (userData != null) {
      _firstNameController.text = userData!['firstName'] ?? '';
      _lastNameController.text = userData!['lastName'] ?? '';
      _bioController.text = userData!['bio'] ?? '';

      if (userData!['profileLinks'] != null) {
        _profileLinks = List<Map<String, String>>.from(
            userData!['profileLinks'].map((link) => {
              'title': link['title']?.toString() ?? '',
              'url': link['url']?.toString() ?? '',
            })
        );
      }

      if (userData!['events'] != null) {
        _events = List<Map<String, dynamic>>.from(userData!['events']);
      }

      if (userData!['additionalImages'] != null) {
        _currentAdditionalImages = List<Map<String, dynamic>>.from(
            userData!['additionalImages'].map((img) => {
              'filename': img['filename'],
              'url': '${UrlConstants.apiBaseUrl}/uploads/${img['filename']}',
              'uploadDate': img['uploadDate']
            })
        );
      }
    }
  }

  Future<void> fetchCurrentUser() async {
    if (!mounted || authToken == null) return;

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/me'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            userData = data;
            currentUserId = data['_id'];
            followerCount = data['followers']?.length ?? 0;
            followingCount = data['following']?.length ?? 0;
            isLoading = false;
            isFollowing = data['followers']?.contains(currentUserId) ?? false;
          });
          _populateFormFields();
        }
        await fetchPlaylists();
      } else {
        _handleFetchError("Profile could not be loaded");
      }
    } catch (e) {
      _handleFetchError("An error occurred: $e");
    }
  }

  void _handleFetchError(String message) {
    if (mounted) {
      setState(() => isLoading = false);
      _showErrorSnackbar(message);
    }
  }

  Future<void> fetchPlaylists() async {
    if (currentUserId == null || !mounted) return;

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/$currentUserId'),
        headers: {'Authorization': 'Bearer $authToken'},
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
      _showErrorSnackbar("Error loading playlists: $e");
    }
  }

  List<dynamic> _parsePlaylistData(List<dynamic>? playlists) {
    return (playlists ?? []).map((playlist) {
      return {
        '_id': playlist['_id']?.toString(),
        'name': playlist['name']?.toString() ?? 'Untitled Playlist',
        'description': playlist['description']?.toString() ?? '',
        'musicCount': playlist['musicCount'] ?? 0,
        'genre': playlist['genre']?.toString() ?? 'unknown',
        'isPublic': playlist['isPublic'] ?? false,
        'musics': (playlist['musics'] as List<dynamic>?)?.map((music) {
          return {
            '_id': music['_id']?.toString(),
            'title': music['title']?.toString(),
            'artist': music['artist']?.toString(),
            'spotifyId': music['spotifyId']?.toString(),
            'category': music['category']?.toString(),
            'likes': music['likes'] ?? 0,
            'userLikes': music['userLikes'] ?? [],
            'beatportUrl': music['beatportUrl']?.toString() ?? '',
          };
        }).toList() ?? [],
      };
    }).toList();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null || !mounted) return;

      final file = File(pickedFile.path);
      setState(() => _imageFile = file);

      await _uploadProfileImage();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar("Hata: ${e.toString()}");
    }
  }

  Future<void> _pickAdditionalImages() async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFiles == null || !mounted) return;

      final totalImages = _currentAdditionalImages.length + _additionalImages.length + pickedFiles.length;
      if (totalImages > 3) {
        _showErrorSnackbar("Maksimum 3 ek resim yükleyebilirsiniz");
        return;
      }

      setState(() {
        _additionalImages.addAll(pickedFiles.map((file) => File(file.path)));
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar("Hata: ${e.toString()}");
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_imageFile == null || authToken == null || !mounted) return;

    setState(() => _isUpdatingImage = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${UrlConstants.apiBaseUrl}/api/upload-profile-image'),
      )..headers['Authorization'] = 'Bearer $authToken'
        ..files.add(await http.MultipartFile.fromPath('profileImage', _imageFile!.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 200) {
        await fetchCurrentUser();
        _showSuccessSnackbar("Resim yüklendi");
      } else {
        _showErrorSnackbar(jsonDecode(responseData)['message'] ?? 'Yükleme başarısız');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar("Sunucu hatası: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isUpdatingImage = false);
      }
    }
  }

  Future<void> _uploadAdditionalImages() async {
    if (_additionalImages.isEmpty || authToken == null) return;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${UrlConstants.apiBaseUrl}/api/upload-additional-images'),
      )..headers['Authorization'] = 'Bearer $authToken';

      for (var image in _additionalImages) {
        request.files.add(await http.MultipartFile.fromPath('additionalImages', image.path));
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        setState(() => _additionalImages.clear());
        return;
      }
    } catch (e) {
      _showErrorSnackbar("Resim yükleme hatası: $e");
    }
  }

  Future<void> _saveProfile() async {
    if (authToken == null || !mounted) return;

    // Bio karakter sınırı kontrolü
    if (_bioController.text.length > 300) {
      _showErrorSnackbar("Biyografi 300 karakterden uzun olamaz");
      return;
    }

    try {
      setState(() => isLoading = true);

      if (_additionalImages.isNotEmpty) {
        await _uploadAdditionalImages();
      }

      final response = await http.put(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'bio': _bioController.text,
          'profileLinks': _profileLinks,
          'events': _events,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        setState(() => isEditing = false);
        await fetchCurrentUser();
        _showSuccessSnackbar("Profil güncellendi");
      } else {
        _showErrorSnackbar("Güncelleme başarısız");
      }
    } catch (e) {
      _showErrorSnackbar("Hata: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _addLink() {
    if (_linkTitleController.text.isNotEmpty && _linkUrlController.text.isNotEmpty) {
      if (_profileLinks.length >= 5) {
        _showErrorSnackbar("Maksimum 5 link ekleyebilirsiniz");
        return;
      }

      setState(() {
        _profileLinks.add({
          'title': _linkTitleController.text,
          'url': _linkUrlController.text,
        });
      });

      _linkTitleController.clear();
      _linkUrlController.clear();
    } else {
      _showErrorSnackbar("Lütfen başlık ve URL alanlarını doldurun");
    }
  }

  void _removeLink(int index) {
    setState(() {
      _profileLinks.removeAt(index);
    });
  }

  Future<void> _launchURL(String url) async {
    try {
      // URL'in başında http:// veya https:// yoksa ekle
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
    showDialog(
      context: context,
      builder: (context) => ImageGalleryDialog(
        images: _currentAdditionalImages,
        initialIndex: initialIndex,
      ),
    );
  }

  Future<void> _selectEventDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedEventDate = picked);
    }
  }

  Future<void> _selectEventTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _eventTimeController.text = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  void _addEvent() {
    if (_selectedEventDate != null &&
        _eventTimeController.text.isNotEmpty &&
        _eventCityController.text.isNotEmpty &&
        _eventVenueController.text.isNotEmpty) {
      setState(() {
        _events.add({
          'date': _selectedEventDate!.toIso8601String(),
          'time': _eventTimeController.text,
          'city': _eventCityController.text,
          'venue': _eventVenueController.text,
        });
      });

      _eventTimeController.clear();
      _eventCityController.clear();
      _eventVenueController.clear();
      _selectedEventDate = null;
    } else {
      _showErrorSnackbar("Lütfen tüm etkinlik bilgilerini doldurun");
    }
  }

  void _removeEvent(int index) {
    setState(() {
      _events.removeAt(index);
    });
  }

  Future<void> _deleteAdditionalImage(String filename) async {
    if (authToken == null) return;

    try {
      final response = await http.delete(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/additional-image/$filename'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _currentAdditionalImages.removeWhere((img) => img['filename'] == filename);
        });
        _showSuccessSnackbar("Resim silindi");
      }
    } catch (e) {
      _showErrorSnackbar("Silme hatası: $e");
    }
  }

  // YENİ: Playlist değişiklikleri için güncellenen handler
  void _handleExpansionChanged(int index, bool expanded) {
    if (!mounted) return;

    // Eğer -1 index gelirse (playlist silindi), sayfayı yenile
    if (index == -1) {
      fetchPlaylists();
      return;
    }

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
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (userData?['profileImage'] != null &&
        userData!['profileImage'].isNotEmpty &&
        userData!['profileImage'] != 'image.jpg') {
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

  // Ana profil header
  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst kısım: profil fotoğrafı ve bilgiler
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profil Fotoğrafı
              Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundImage: _getProfileImage(),
                        ),
                      ),
                      if (isCurrentUser && !isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: IconButton(
                              icon: _isUpdatingImage
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Icon(Icons.camera_alt, size: 18),
                              onPressed: _isUpdatingImage ? null : _pickImage,
                              color: Colors.black,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),

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
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // İstatistikler
                    Row(
                      children: [
                        _buildCompactStat(followerCount, "Takipçi"),
                        const SizedBox(width: 50),
                        _buildCompactStat(followingCount, "Takip"),
                        const SizedBox(width: 50),
                        _buildCompactStat(playlists.length, "Bangs"),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Biyografi
                    if (userData?['bio'] != null && userData!['bio'].isNotEmpty)
                      Text(
                        userData!['bio'],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Linkler
          if (_profileLinks.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _profileLinks.map((link) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: InkWell(
                    onTap: () => _launchURL(link['url']!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              link['title']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

          // Buton: Takip / Profili Düzenle
          Center(
            child: isCurrentUser
                ? _buildEditButton()
                : _buildFollowButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(int count, String label) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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

  Widget _buildEditButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            isEditing = !isEditing;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          isEditing ? "İptal" : "Profili Düzenle",
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Fotoğraf galerisi
  Widget _buildPhotoGallery() {
    if (_currentAdditionalImages.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(9),
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
            children: _currentAdditionalImages.asMap().entries.map((entry) {
              final index = entry.key;
              final image = entry.value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _showImageGallery(index),
                  child: Container(
                    height: 90,
                    margin: EdgeInsets.only(
                      right: index < _currentAdditionalImages.length - 1 ? 8 : 0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        image['url'] as String,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isEditing) _buildEventForm(),
        const SizedBox(height: 16),
        if (_events.isNotEmpty) ...[
          ..._events.asMap().entries.map((entry) {
            final index = entry.key;
            final event = entry.value;
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
                  // Artı butonu veya silme butonu
                  if (isEditing)
                    IconButton(
                      onPressed: () => _removeEvent(index),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      padding: const EdgeInsets.all(16),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[600]!),
                      ),
                      child: IconButton(
                        onPressed: () {
                          // Etkinlik detaylarını göster veya takvime ekle
                        },
                        icon: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ] else ...[
          Container(
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
          ),
        ],
      ],
    );
  }

  Widget _buildEventForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
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
              Icon(Icons.add_box, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                "Yeni Etkinlik Ekle",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _selectEventDate,
                    icon: const Icon(Icons.calendar_today, color: Colors.black),
                    label: Text(
                      _selectedEventDate == null
                          ? "Tarih Seç"
                          : "${_selectedEventDate!.day}/${_selectedEventDate!.month}/${_selectedEventDate!.year}",
                      style: const TextStyle(color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: TextField(
                    controller: _eventTimeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Saat',
                      labelStyle: TextStyle(color: Colors.grey),
                      suffixIcon: Icon(Icons.access_time, color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    onTap: _selectEventTime,
                    readOnly: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: TextField(
              controller: _eventCityController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'İl',
                labelStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.location_city, color: Colors.white70),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: TextField(
              controller: _eventVenueController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Mekan',
                labelStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.place, color: Colors.white70),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ElevatedButton.icon(
              onPressed: _addEvent,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                "Etkinlik Ekle",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Düzenleme formu
  Widget _buildEditingForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.edit, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                "Profili Düzenle",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Ad Soyad
          _buildModernTextField(_firstNameController, 'Ad', Icons.person),
          const SizedBox(height: 16),
          _buildModernTextField(_lastNameController, 'Soyad', Icons.person_outline),
          const SizedBox(height: 16),

          // Biyografi
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _bioController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: 'Biyografi',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.info_outline, color: Colors.white70),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    counterStyle: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Link ekleme bölümü
          _buildLinkEditingSection(),
          const SizedBox(height: 20),

          // Fotoğraf yükleme
          _buildImageUploadSection(),
          const SizedBox(height: 20),

          // Kaydet buton
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Kaydet",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkEditingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Linkler",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),

        // Mevcut linkler
        if (_profileLinks.isNotEmpty) ...[
          ..._profileLinks.asMap().entries.map((entry) {
            final index = entry.key;
            final link = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[600]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          link['title']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          link['url']!,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeLink(index),
                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
        ],

        // Yeni link ekleme formu
        if (_profileLinks.length < 5) ...[
          _buildModernTextField(_linkTitleController, 'Link Başlığı', Icons.title),
          const SizedBox(height: 12),
          _buildModernTextField(_linkUrlController, 'URL (https://...)', Icons.language),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ElevatedButton.icon(
              onPressed: _addLink,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                "Link Ekle",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Ek Fotoğraflar (Maksimum 3)",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Slot 1
            _buildImageSlot(0),
            const SizedBox(width: 12),
            // Slot 2
            _buildImageSlot(1),
            const SizedBox(width: 12),
            // Slot 3
            _buildImageSlot(2),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ElevatedButton.icon(
            onPressed: _pickAdditionalImages,
            icon: const Icon(Icons.add_photo_alternate, color: Colors.black),
            label: const Text(
              "Fotoğraf Ekle",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSlot(int index) {
    final allImages = [..._currentAdditionalImages, ..._additionalImages.map((file) => {'file': file})];

    if (index < allImages.length) {
      final imageData = allImages[index];

      return Expanded(
        child: Stack(
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageData.containsKey('file')
                    ? Image.file(
                  imageData['file'] as File,
                  width: double.infinity,
                  height: 100,
                  fit: BoxFit.cover,
                )
                    : Image.network(
                  imageData['url'] as String,
                  width: double.infinity,
                  height: 100,
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
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  if (imageData.containsKey('file')) {
                    setState(() {
                      _additionalImages.removeWhere((file) => file == imageData['file']);
                    });
                  } else {
                    _deleteAdditionalImage(imageData['filename'] as String);
                  }
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Boş slot
    return Expanded(
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: Center(
          child: Icon(
            Icons.add_photo_alternate,
            color: Colors.grey[600],
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField(TextEditingController controller, String label, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
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

  // YENİ: Güncellenmiş playlist section - ProfilePlaylistCard kullanımı
  Widget _buildPlaylistsSection() {
    return Column(
      children: [
        if (playlists.isEmpty)
          _buildEmptyPlaylistMessage()
        else
          ...playlists.asMap().entries.map((entry) =>
              ProfilePlaylistCard(
                playlist: entry.value,
                index: entry.key,
                currentlyExpandedIndex: currentlyExpandedIndex,
                onExpansionChanged: _handleExpansionChanged,
                activeWebViews: activeWebViews,
                cachedWebViews: {},
                isCurrentUser: isCurrentUser, // Mevcut kullanıcı kontrolü
                onPlaylistUpdated: fetchPlaylists, // Playlist güncellendiğinde yenile
              ),
          ),
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
            "Henüz playlist oluşturulmamış",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingScreen();
    }

    if (userData == null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
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

                    // Düzenleme formu
                    if (isEditing) ...[
                      _buildEditingForm(),
                      const SizedBox(height: 16),
                    ],

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

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
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

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
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
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  icon: const Icon(Icons.login, color: Colors.black),
                  label: const Text(
                    "Giriş Yap",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  ),
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