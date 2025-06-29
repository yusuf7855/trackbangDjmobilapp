// lib/menu/magaza_screen.dart - FINAL VERSION

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
              SizedBox(width: 12),
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
              child: Text(item, style: TextStyle(color: _primaryText)),
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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _openListingDetail(listing),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOL TARAF - GÖRSEL
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _cardColor,
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
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  // Kategori
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Text(
                      listing['category']?.toString() ?? 'Kategori',
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(listing['createdAt']),
                        style: TextStyle(
                          color: _tertiaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Telefon numarası
                  if (listing['phoneNumber'] != null)
                    Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: _secondaryText),
                        SizedBox(width: 4),
                        Text(
                          listing['phoneNumber'].toString(),
                          style: TextStyle(
                            color: _secondaryText,
                            fontSize: 14,
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
      color: _cardColor,
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

      return matchesCategory && matchesSearch;
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

class ListingDetailScreen extends StatefulWidget {
  final dynamic listing;

  ListingDetailScreen({required this.listing});

  @override
  _ListingDetailScreenState createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  PageController _pageController = PageController();
  int _currentImageIndex = 0;

  final Color _backgroundColor = Color(0xFF0F0F0F);
  final Color _surfaceColor = Color(0xFF1A1A1A);
  final Color _cardColor = Color(0xFF262626);
  final Color _primaryText = Color(0xFFFFFFFF);
  final Color _secondaryText = Color(0xFFBBBBBB);
  final Color _tertiaryText = Color(0xFF888888);
  final Color _accentColor = Color(0xFF6B7280);
  final Color _borderColor = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('İlan Detayı', style: TextStyle(color: _primaryText)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryText),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageCarousel(),
                  SizedBox(height: 24),
                  _buildTitleAndPrice(),
                  SizedBox(height: 20),
                  _buildInfoSection(),
                  SizedBox(height: 20),
                  _buildDescriptionSection(),
                  SizedBox(height: 20),
                  _buildContactSection(),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    List<String> imageUrls = _getImageUrls();

    if (imageUrls.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            color: _tertiaryText,
            size: 64,
          ),
        ),
      );
    }

    return Container(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: _cardColor,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: _tertiaryText,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (imageUrls.length > 1)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${imageUrls.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (imageUrls.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: imageUrls.asMap().entries.map((entry) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentImageIndex == entry.key
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _getImageUrls() {
    List<String> imageUrls = [];

    if (widget.listing['images'] is List) {
      for (var image in widget.listing['images']) {
        if (image is Map && image['url'] != null) {
          final url = image['url'].toString();
          imageUrls.add(url.startsWith('http') ? url : '${UrlConstants.apiBaseUrl}$url');
        } else if (image is String) {
          imageUrls.add(image.startsWith('http') ? image : '${UrlConstants.apiBaseUrl}$image');
        }
      }
    }

    return imageUrls;
  }

  Widget _buildTitleAndPrice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.listing['title']?.toString() ?? 'Başlık yok',
          style: TextStyle(
            color: _primaryText,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Text(
          '₺${widget.listing['price']?.toString() ?? '0'}',
          style: TextStyle(
            color: _primaryText,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          _buildInfoRow('Kategori', widget.listing['category']?.toString() ?? 'Kategori Yok'),
          Divider(color: _borderColor, height: 24),
          _buildInfoRow('İlan No', widget.listing['listingNumber']?.toString() ?? 'N/A'),
          Divider(color: _borderColor, height: 24),
          _buildInfoRow('Yayın Tarihi', _formatDate(widget.listing['createdAt'])),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _secondaryText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: _primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Açıklama',
          style: TextStyle(
            color: _primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Text(
            widget.listing['description']?.toString() ?? 'Açıklama bulunmuyor.',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İletişim',
            style: TextStyle(
              color: _primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12),
          if (widget.listing['phoneNumber'] != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, color: _accentColor, size: 20),
                  SizedBox(width: 12),
                  Text(
                    widget.listing['phoneNumber'].toString(),
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return 'Tarih yok';
    try {
      final date = DateTime.parse(dateString.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Tarih yok';
    }
  }
}

class CreateListingScreen extends StatefulWidget {
  final VoidCallback onListingCreated;

  CreateListingScreen({required this.onListingCreated});

  @override
  _CreateListingScreenState createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final Dio _dio = Dio();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String _selectedCategory = 'Elektronik';
  List<File> _selectedImages = [];
  bool _isLoading = false;

  final List<String> _categories = [
    'Elektronik', 'Giyim', 'Ev & Yaşam', 'Spor',
    'Kitap', 'Oyun', 'Müzik Aleti', 'Diğer'
  ];

  // Dark Theme Colors
  final Color _backgroundColor = Color(0xFF0F0F0F);
  final Color _surfaceColor = Color(0xFF1A1A1A);
  final Color _cardColor = Color(0xFF262626);
  final Color _primaryText = Color(0xFFFFFFFF);
  final Color _secondaryText = Color(0xFFBBBBBB);
  final Color _tertiaryText = Color(0xFF888888);
  final Color _accentColor = Color(0xFF6B7280);
  final Color _borderColor = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'İlan Oluştur',
          style: TextStyle(
            color: _primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: _primaryText),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormField('Başlık', _titleController, 'İlan başlığını yazın'),
              SizedBox(height: 24),
              _buildCategoryDropdown(),
              SizedBox(height: 24),
              _buildFormField('Açıklama', _descriptionController, 'İlan açıklamasını yazın', maxLines: 4),
              SizedBox(height: 24),
              _buildFormField('Fiyat (₺)', _priceController, '0', keyboardType: TextInputType.number),
              SizedBox(height: 24),
              _buildFormField('Telefon', _phoneController, 'İletişim numaranız'),
              SizedBox(height: 24),
              _buildImageSection(),
              SizedBox(height: 32),
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, String hint,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(color: _primaryText),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _tertiaryText),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '$label gereklidir';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori',
          style: TextStyle(
            color: _primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              dropdownColor: _cardColor,
              style: TextStyle(color: _primaryText),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Görseller',
          style: TextStyle(
            color: _primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, style: BorderStyle.solid),
          ),
          child: Column(
            children: [
              if (_selectedImages.isEmpty)
                Column(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: _tertiaryText,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Görsel eklemek için tıklayın',
                      style: TextStyle(
                        color: _tertiaryText,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedImages.asMap().entries.map((entry) {
                    int index = entry.key;
                    File image = entry.value;
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _borderColor),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              image,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              if (_selectedImages.isNotEmpty) SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: Icon(Icons.add, color: _primaryText),
                label: Text(
                  _selectedImages.isEmpty ? 'Görsel Ekle' : 'Daha Fazla Ekle',
                  style: TextStyle(color: _primaryText),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: _primaryText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createListing,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: _primaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primaryText),
          strokeWidth: 2,
        )
            : Text(
          'İlan Oluştur',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage();
      if (images != null) {
        setState(() {
          _selectedImages.addAll(images.map((image) => File(image.path)));
        });
      }
    } catch (e) {
      _showMessage('Görsel seçme hatası: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _createListing() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('authToken');

      if (authToken == null) {
        _showMessage('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.');
        return;
      }

      FormData formData = FormData.fromMap({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category': _selectedCategory,
        'price': _priceController.text,
        'phoneNumber': _phoneController.text,
      });

      // Görselleri ekle
      for (int i = 0; i < _selectedImages.length; i++) {
        formData.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(
              _selectedImages[i].path,
              filename: 'image_$i.jpg',
            ),
          ),
        );
      }

      final response = await _dio.post(
        '${UrlConstants.apiBaseUrl}/api/store/listings',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $authToken'},
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('İlan başarıyla oluşturuldu!');
        widget.onListingCreated();
        Navigator.pop(context);
      } else {
        _showMessage(response.data['message'] ?? 'İlan oluşturulamadı');
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          _showMessage('İlan hakkınız bulunmuyor. Lütfen ilan hakkı satın alın.');
        } else if (e.response?.statusCode == 401) {
          _showMessage('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.');
        } else {
          _showMessage(e.response?.data['message'] ?? 'İlan oluşturulurken hata oluştu');
        }
      } else {
        _showMessage('Bağlantı hatası: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    try {
      final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
      if (scaffoldMessenger != null && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _surfaceColor,
          ),
        );
      }
    } catch (e) {
      print('SnackBar gösterme hatası: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}