// lib/menu/magaza_screen.dart - GÜNCELLENMİŞ VERSİYON - İlan sahibi bilgileri ve konum

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/create_listing_screen.dart';
import '../screens/listing_detail_screen.dart';
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
  String _searchQuery = '';
  String _selectedCategory = 'Tümü';
  String _priceSort = 'Yeniden Eskiye';
  String _selectedProvince = 'Tüm İller';
  String _selectedDistrict = 'Tüm İlçeler';

  final List<String> _categories = [
    'Tümü', 'Elektronik', 'Giyim', 'Ev & Yaşam',
    'Spor', 'Kitap', 'Oyun', 'Müzik Aleti', 'Diğer'
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
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet, color: _accentColor, size: 20),
                SizedBox(width: 4),
                Text(
                  '$_userCredits',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildSearchAndFilters(),
          ),
          _isLoading
              ? SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(50),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                ),
              ),
            ),
          )
              : _buildListingsGrid(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateListingScreen(),
        backgroundColor: _accentColor,
        child: Icon(Icons.add, color: _primaryText),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Arama kutusu
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
                prefixIcon: Icon(Icons.search, color: _tertiaryText),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          SizedBox(height: 12),
          // Filtreler
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Kategori',
                  _selectedCategory,
                  _categories,
                      (value) => setState(() => _selectedCategory = value!),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildFilterDropdown(
                  'Sıralama',
                  _priceSort,
                  ['Yeniden Eskiye', 'Eskiden Yeniye', 'Fiyat Artan', 'Fiyat Azalan'],
                      (value) => setState(() => _priceSort = value!),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Konum filtreleri
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'İl',
                  _selectedProvince,
                  ['Tüm İller', 'İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Antalya', 'Adana', 'Konya', 'Samsun'],
                      (value) => setState(() => _selectedProvince = value!),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildFilterDropdown(
                  'İlçe',
                  _selectedDistrict,
                  ['Tüm İlçeler', 'Merkez', 'Ataşehir', 'Kadıköy', 'Beşiktaş', 'Şişli'],
                      (value) => setState(() => _selectedDistrict = value!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String hint, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: _tertiaryText)),
          dropdownColor: _cardColor,
          style: TextStyle(color: _primaryText),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, style: TextStyle(color: _primaryText, fontSize: 12)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildListingsGrid() {
    final filteredListings = _getFilteredListings();

    if (filteredListings.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(50),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: _tertiaryText),
                SizedBox(height: 16),
                Text(
                  'Henüz ilan bulunmuyor',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
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
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: InkWell(
        onTap: () => _openListingDetail(listing),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SOL TARAF - GÖRSEL
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _getFirstImage(listing),
                  ),
                ),
                SizedBox(width: 16),
                // SAĞ TARAF - BİLGİLER
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık
                      Text(
                        listing['title']?.toString() ?? 'Başlık yok',
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      // Kategori
                      Text(
                        listing['category']?.toString() ?? 'Kategori',
                        style: TextStyle(
                          color: _secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      // Konum
                      if (location != null)
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: _accentColor),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${location['district'] ?? ''}, ${location['province'] ?? ''}',
                                style: TextStyle(
                                  color: _secondaryText,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: 8),
                      // Fiyat ve tarih
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₺${listing['price']?.toString() ?? '0'}',
                            style: TextStyle(
                              color: _primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
            // ALT KISIM - KULLANICI BİLGİLERİ
            if (user != null) ...[
              SizedBox(height: 12),
              Divider(color: _borderColor, height: 1),
              SizedBox(height: 8),
              Row(
                children: [
                  // Profil resmi
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _borderColor),
                    ),
                    child: ClipOval(
                      child: _getUserProfileImage(user),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Kullanıcı adı
                  Expanded(
                    child: Text(
                      user['username']?.toString() ?? 'Kullanıcı',
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Görüntülenme sayısı
                  Icon(Icons.visibility, size: 12, color: _tertiaryText),
                  SizedBox(width: 2),
                  Text(
                    '${listing['viewCount'] ?? 0}',
                    style: TextStyle(
                      color: _tertiaryText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _getUserProfileImage(dynamic user) {
    String? imageUrl = user['profileImageUrl']?.toString();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final fullUrl = imageUrl.startsWith('http')
          ? imageUrl
          : '${UrlConstants.apiBaseUrl}$imageUrl';

      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildUserPlaceholder(),
      );
    }

    return _buildUserPlaceholder();
  }

  Widget _buildUserPlaceholder() {
    return Container(
      color: _accentColor,
      child: Icon(
        Icons.person,
        color: _primaryText,
        size: 16,
      ),
    );
  }

  Widget _getFirstImage(dynamic listing) {
    if (listing['images'] != null && listing['images'].isNotEmpty) {
      var firstImage = listing['images'][0];
      String imageUrl = '';

      if (firstImage is Map && firstImage['url'] != null) {
        imageUrl = firstImage['url'].toString();
      } else if (firstImage is String) {
        imageUrl = firstImage;
      }

      if (imageUrl.isNotEmpty) {
        final fullUrl = imageUrl.startsWith('http')
            ? imageUrl
            : '${UrlConstants.apiBaseUrl}$imageUrl';

        return Image.network(
          fullUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
        );
      }
    }

    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: _surfaceColor,
      child: Icon(
        Icons.image_outlined,
        color: _tertiaryText,
        size: 32,
      ),
    );
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }

  void _openListingDetail(dynamic listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListingDetailScreen(listing: listing),
      ),
    );
  }

  List<dynamic> _getFilteredListings() {
    return _listings.where((listing) {
      final matchesCategory = _selectedCategory == 'Tümü' ||
          listing['category']?.toString() == _selectedCategory;

      final matchesSearch = _searchQuery.isEmpty ||
          listing['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
          listing['description']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true;

      // Konum filtreleri
      bool matchesLocation = true;
      if (_selectedProvince != 'Tüm İller') {
        matchesLocation = listing['location']?['province']?.toString() == _selectedProvince;
      }
      if (_selectedDistrict != 'Tüm İlçeler' && matchesLocation) {
        matchesLocation = listing['location']?['district']?.toString() == _selectedDistrict;
      }

      return matchesCategory && matchesSearch && matchesLocation;
    }).toList();
  }

  Future<void> _loadListings() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final response = await _dio.get('${UrlConstants.apiBaseUrl}/api/store/listings');

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (mounted) {
          setState(() {
            _listings = response.data['listings'] ?? [];
          });
        }
      }
    } catch (e) {
      print('Listeleri yükleme hatası: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserCredits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('authToken');

      if (authToken == null) return;

      final response = await _dio.get(
        '${UrlConstants.apiBaseUrl}/api/store/rights',
        options: Options(
          headers: {'Authorization': 'Bearer $authToken'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (mounted) {
          setState(() {
            _userCredits = response.data['rights']['availableRights'] ?? 0;
          });
        }
      }
    } catch (e) {
      print('Kredi yükleme hatası: $e');
    }
  }

  void _showCreateListingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateListingScreen(
          onListingCreated: () {
            _loadListings();
            _loadUserCredits();
          },
        ),
      ),
    );
  }
}