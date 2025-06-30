// lib/menu/magaza_screen.dart - TAM VE HATASIZ VERSİYON

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/create_listing_screen.dart';
import '../screens/listing_detail_screen.dart';
import '../screens/purchase_rights_screen.dart';
import '../url_constants.dart';

class MagazaScreen extends StatefulWidget {
  @override
  _MagazaScreenState createState() => _MagazaScreenState();
}

class _MagazaScreenState extends State<MagazaScreen> with TickerProviderStateMixin {
  final Dio _dio = Dio();
  final TextEditingController _searchController = TextEditingController();

  // State variables
  List<dynamic> _listings = [];
  int _userCredits = 0;
  bool _isLoading = false;
  bool _isLoadingCredits = false;
  String _searchQuery = '';
  String _selectedCategory = 'Tümü';
  String _priceSort = 'Yeniden Eskiye';
  String _selectedProvince = 'Tüm İller';
  String _selectedDistrict = 'Tüm İlçeler';

  final List<String> _categories = [
    'Tümü', 'Elektronik', 'Giyim', 'Ev & Yaşam',
    'Spor', 'Kitap', 'Oyun', 'Müzik Aleti', 'Diğer'
  ];

  final List<String> _sortOptions = [
    'Yeniden Eskiye',
    'Eskiden Yeniye',
    'Fiyat (Düşük-Yüksek)',
    'Fiyat (Yüksek-Düşük)'
  ];

  // Modern Dark Theme Colors
  final Color _backgroundColor = Color(0xFF0F0F0F);
  final Color _surfaceColor = Color(0xFF1A1A1A);
  final Color _cardColor = Color(0xFF262626);
  final Color _primaryText = Color(0xFFFFFFFF);
  final Color _secondaryText = Color(0xFFBBBBBB);
  final Color _tertiaryText = Color(0xFF888888);
  final Color _accentColor = Color(0xFF6B7280);
  final Color _borderColor = Color(0xFF333333);
  final Color _greenColor = Color(0xFF10B981);
  final Color _blueColor = Color(0xFF3B82F6);
  final Color _errorColor = Color(0xFFEF4444);
  final Color _orangeColor = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _loadListings();
    _loadUserCredits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Mağaza', style: TextStyle(color: _primaryText)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryText),
        actions: [
          // İlan hakkı göstergesi
          GestureDetector(
            onTap: _goToPurchaseRights,
            child: Container(
              margin: EdgeInsets.only(right: 16),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _userCredits > 0 ? _greenColor.withOpacity(0.1) : _errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _userCredits > 0 ? _greenColor.withOpacity(0.3) : _errorColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      Icons.account_balance_wallet,
                      color: _userCredits > 0 ? _greenColor : _errorColor,
                      size: 18
                  ),
                  SizedBox(width: 6),
                  _isLoadingCredits
                      ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                    ),
                  )
                      : Text(
                    '$_userCredits',
                    style: TextStyle(
                      color: _userCredits > 0 ? _greenColor : _errorColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: _blueColor,
        backgroundColor: _cardColor,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildSearchAndFilters(),
            ),
            _isLoading
                ? SliverToBoxAdapter(
              child: Container(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_blueColor),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'İlanlar yükleniyor...',
                        style: TextStyle(
                          color: _secondaryText,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
                : _buildListingsGrid(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _checkRightsAndCreateListing,
        backgroundColor: _blueColor,
        foregroundColor: _primaryText,
        icon: Icon(Icons.add, size: 24),
        label: Text(
          'İlan Ver',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: _primaryText),
              decoration: InputDecoration(
                hintText: 'İlan ara...',
                hintStyle: TextStyle(color: _tertiaryText),
                prefixIcon: Icon(Icons.search, color: _accentColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: _accentColor),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _loadListings();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _debounceSearch();
              },
            ),
          ),
          SizedBox(height: 16),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                    'Kategori',
                    _selectedCategory,
                    _categories,
                        (value) {
                      setState(() => _selectedCategory = value);
                      _loadListings();
                    }
                ),
                SizedBox(width: 8),
                _buildFilterChip(
                    'Sıralama',
                    _priceSort,
                    _sortOptions,
                        (value) {
                      setState(() => _priceSort = value);
                      _loadListings();
                    }
                ),
                SizedBox(width: 8),
                _buildActionChip(
                  'Filtrele',
                  Icons.filter_list,
                      () => _showFilterDialog(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, List<String> options, Function(String) onSelected) {
    return Container(
      height: 36,
      child: PopupMenuButton<String>(
        onSelected: onSelected,
        color: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$label: ${value.length > 10 ? value.substring(0, 10) + '...' : value}',
                style: TextStyle(color: _primaryText, fontSize: 12),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: _accentColor, size: 16),
            ],
          ),
        ),
        itemBuilder: (context) {
          return options.map((option) {
            return PopupMenuItem<String>(
              value: option,
              child: Text(
                option,
                style: TextStyle(color: _primaryText),
              ),
            );
          }).toList();
        },
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _accentColor, size: 16),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: _primaryText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingsGrid() {
    final filteredListings = _getFilteredListings();

    if (filteredListings.isEmpty && !_isLoading) {
      return SliverToBoxAdapter(
        child: Container(
          height: 400,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  _searchQuery.isNotEmpty ? Icons.search_off : Icons.inventory_2_outlined,
                  size: 80,
                  color: _tertiaryText
              ),
              SizedBox(height: 24),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Arama sonucu bulunamadı'
                    : 'Henüz ilan bulunmuyor',
                style: TextStyle(
                  color: _secondaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Farklı kelimelerle tekrar deneyin'
                    : 'İlk ilanı siz verin!',
                style: TextStyle(
                  color: _tertiaryText,
                  fontSize: 14,
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _loadListings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blueColor,
                    foregroundColor: _primaryText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Tüm İlanları Göster'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final listing = filteredListings[index];
          return _buildListingCard(listing);
        },
        childCount: filteredListings.length,
      ),
    );
  }

  Widget _buildListingCard(dynamic listing) {
    final user = listing['userId'];
    final location = listing['location'];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openListingDetail(listing),
          child: Stack(
            children: [
              // Ana içerik
              Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SOL TARAF - GÖRSEL
                    Container(
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _getFirstImage(listing),
                      ),
                    ),
                    SizedBox(width: 12),

                    // SAĞ TARAF - BİLGİLER
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Başlık (üst kısımda yer bırak)
                          Padding(
                            padding: EdgeInsets.only(right: 60), // Profil için yer bırak
                            child: Text(
                              listing['title']?.toString() ?? 'Başlık yok',
                              style: TextStyle(
                                color: _primaryText,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(height: 8),

                          // Kategori
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              listing['category']?.toString() ?? 'Kategori',
                              style: TextStyle(
                                color: _accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),

                          // Fiyat
                          Text(
                            '${listing['price']?.toString() ?? '0'} EUR',
                            style: TextStyle(
                              color: _greenColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),

                          // Konum ve tarih
                          Row(
                            children: [
                              if (location != null) ...[
                                Icon(Icons.location_on,
                                    color: _tertiaryText, size: 12),
                                SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    '${location['district'] ?? ''}, ${location['province'] ?? ''}',
                                    style: TextStyle(
                                      color: _tertiaryText,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              SizedBox(width: 8),
                              Text(
                                _formatDate(listing['createdAt']),
                                style: TextStyle(
                                  color: _tertiaryText,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // SAĞ ALT - İSTATİSTİKLER (Çok küçük)
              if (listing['viewCount'] != null && listing['viewCount'] > 0) ...[
                Positioned(
                  bottom: 8,
                  right: 12,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility, color: _tertiaryText, size: 10),
                        SizedBox(width: 2),
                        Text(
                          '${listing['viewCount']}',
                          style: TextStyle(
                            color: _tertiaryText,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _getFirstImage(dynamic listing) {
    final images = listing['images'] as List?;
    if (images != null && images.isNotEmpty) {
      final imageUrl = images[0]['url'] ?? '';
      if (imageUrl.isNotEmpty) {
        return Image.network(
          '${UrlConstants.apiBaseUrl}$imageUrl',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: _surfaceColor,
              child: Icon(Icons.image_not_supported, color: _tertiaryText, size: 32),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: _surfaceColor,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                  valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                  strokeWidth: 2,
                ),
              ),
            );
          },
        );
      }
    }

    return Container(
      color: _surfaceColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, color: _tertiaryText, size: 32),
          SizedBox(height: 4),
          Text(
            'Fotoğraf Yok',
            style: TextStyle(
              color: _tertiaryText,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getUserProfileImage(dynamic user, {double size = 24}) {
    final profileImage = user['profileImage'] ?? user['profileImageUrl'];
    if (profileImage != null && profileImage.isNotEmpty) {
      String imageUrl = profileImage;
      if (!imageUrl.startsWith('http') && !imageUrl.startsWith('/')) {
        imageUrl = '/uploads/$imageUrl';
      }

      return Image.network(
        '${UrlConstants.apiBaseUrl}$imageUrl',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            color: _accentColor.withOpacity(0.3),
            child: Icon(Icons.person, color: _accentColor, size: size * 0.6),
          );
        },
      );
    }

    return Container(
      width: size,
      height: size,
      color: _accentColor.withOpacity(0.3),
      child: Icon(Icons.person, color: _accentColor, size: size * 0.6),
    );
  }

  List<dynamic> _getFilteredListings() {
    List<dynamic> filtered = List.from(_listings);

    // Kategori filtresi
    if (_selectedCategory != 'Tümü') {
      filtered = filtered.where((listing) =>
      listing['category'] == _selectedCategory).toList();
    }

    // Arama filtresi
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((listing) {
        final title = listing['title']?.toString().toLowerCase() ?? '';
        final description = listing['description']?.toString().toLowerCase() ?? '';
        final category = listing['category']?.toString().toLowerCase() ?? '';
        final listingNumber = listing['listingNumber']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return title.contains(query) ||
            description.contains(query) ||
            category.contains(query) ||
            listingNumber.contains(query);
      }).toList();
    }

    // Sıralama
    switch (_priceSort) {
      case 'Yeniden Eskiye':
        filtered.sort((a, b) => DateTime.parse(b['createdAt'])
            .compareTo(DateTime.parse(a['createdAt'])));
        break;
      case 'Eskiden Yeniye':
        filtered.sort((a, b) => DateTime.parse(a['createdAt'])
            .compareTo(DateTime.parse(b['createdAt'])));
        break;
      case 'Fiyat (Düşük-Yüksek)':
        filtered.sort((a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0));
        break;
      case 'Fiyat (Yüksek-Düşük)':
        filtered.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
        break;
    }

    return filtered;
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return '';

    try {
      final date = DateTime.parse(dateString.toString());
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${difference.inDays} gün önce';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} gün önce';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} saat önce';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} dakika önce';
      } else {
        return 'Şimdi';
      }
    } catch (e) {
      return '';
    }
  }

  void _debounceSearch() {
    Future.delayed(Duration(milliseconds: 800), () {
      if (mounted && _searchController.text == _searchQuery) {
        _loadListings();
      }
    });
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadListings(),
      _loadUserCredits(),
    ]);
  }

  Future<void> _loadListings() async {
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> queryParams = {};

      if (_selectedCategory != 'Tümü') {
        queryParams['category'] = _selectedCategory;
      }

      if (_searchQuery.isNotEmpty) {
        queryParams['search'] = _searchQuery;
      }

      // Sıralama parametresi
      switch (_priceSort) {
        case 'Yeniden Eskiye':
          queryParams['sortBy'] = 'createdAt';
          queryParams['sortOrder'] = 'desc';
          break;
        case 'Eskiden Yeniye':
          queryParams['sortBy'] = 'createdAt';
          queryParams['sortOrder'] = 'asc';
          break;
        case 'Fiyat (Düşük-Yüksek)':
          queryParams['sortBy'] = 'price';
          queryParams['sortOrder'] = 'asc';
          break;
        case 'Fiyat (Yüksek-Düşük)':
          queryParams['sortBy'] = 'price';
          queryParams['sortOrder'] = 'desc';
          break;
      }

      print('🔍 Loading listings with params: $queryParams');

      final response = await _dio.get(
        '${UrlConstants.apiBaseUrl}/api/store/listings',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success']) {
        setState(() {
          _listings = response.data['listings'] ?? [];
        });
        print('✅ Loaded ${_listings.length} listings');
      } else {
        _showMessage('İlanlar yüklenirken hata oluştu: ${response.data['message'] ?? 'Bilinmeyen hata'}');
      }
    } catch (e) {
      print('❌ Listings yükleme hatası: $e');
      _showMessage('İlanlar yüklenirken hata oluştu. İnternet bağlantınızı kontrol edin.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserCredits() async {
    setState(() => _isLoadingCredits = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        print('⚠️ Auth token bulunamadı');
        return;
      }

      final response = await _dio.get(
        '${UrlConstants.apiBaseUrl}/api/store/rights',
        options: Options(
          headers: {'Authorization': 'Bearer $authToken'},
        ),
      );

      if (response.statusCode == 200 && response.data['success']) {
        setState(() {
          _userCredits = response.data['rights']['availableRights'] ?? 0;
        });
        print('✅ User credits loaded: $_userCredits');
      }
    } catch (e) {
      print('❌ Credits yükleme hatası: $e');
      // Sessizce hata ver, kullanıcıyı rahatsız etme
    } finally {
      if (mounted) {
        setState(() => _isLoadingCredits = false);
      }
    }
  }

  Future<void> _checkRightsAndCreateListing() async {
    // Önce mevcut hakları kontrol et
    await _loadUserCredits();

    if (_userCredits <= 0) {
      // İlan hakkı yok - önce satın alma sayfasını göster
      _showNoRightsDialog();
    } else {
      // İlan hakkı var - direkt ilan oluşturma sayfasına git
      _openCreateListing();
    }
  }

  void _showNoRightsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: _orangeColor, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'İlan Hakkı Gerekli',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'İlan verebilmek için önce ilan hakkı satın almanız gerekiyor. Satın alma sayfasına gitmek ister misiniz?',
            style: TextStyle(
              color: _secondaryText,
              height: 1.4,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: TextStyle(color: _accentColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _goToPurchaseRights();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _blueColor,
                foregroundColor: _primaryText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'Satın Al',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFilterDialog() {
    // Gelecekte daha detaylı filtre seçenekleri için
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Gelişmiş Filtreler',
            style: TextStyle(color: _primaryText),
          ),
          content: Text(
            'Fiyat aralığı, konum ve diğer filtre seçenekleri yakında eklenecek.',
            style: TextStyle(color: _secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Tamam',
                style: TextStyle(color: _blueColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _goToPurchaseRights() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseRightsScreen(
          onPurchaseCompleted: () {
            // Satın alma tamamlandığında hakları yeniden kontrol et
            _loadUserCredits();
          },
        ),
      ),
    );

    // Eğer satın alma başarılıysa hakları yeniden kontrol et
    if (result == true) {
      await _loadUserCredits();
      // Otomatik olarak ilan oluşturma sayfasına git
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && _userCredits > 0) {
          _openCreateListing();
        }
      });
    }
  }

  void _openCreateListing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateListingScreen(
          onListingCreated: () {
            _refreshData(); // Hem ilanları hem hakları güncelle
          },
        ),
      ),
    );
  }

  void _openListingDetail(dynamic listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListingDetailScreen(listing: listing),
      ),
    ).then((_) {
      // Detay sayfasından döndüğünde listeyi yenile (görüntülenme sayısı artmış olabilir)
      _loadListings();
    });
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: _primaryText),
        ),
        backgroundColor: isError ? _errorColor : _greenColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.all(16),
        action: isError
            ? SnackBarAction(
          label: 'Tekrar Dene',
          textColor: _primaryText,
          onPressed: () {
            _refreshData();
          },
        )
            : null,
      ),
    );
  }
}