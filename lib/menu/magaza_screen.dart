// lib/menu/magaza_screen.dart - TEMİZ VE DÜZELTİLMİŞ VERSİYON

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
  final Color _accentColor = Color(0xFF4F46E5);
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
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: _buildSearchAndFilters(),
          ),
          _isLoading ? _buildLoadingSliver() : _buildListingsGrid(),
        ],
      ),
      floatingActionButton: _buildMinimalistFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: _backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      floating: true,
      snap: true,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Icon(Icons.store_outlined, color: _primaryText, size: 24),
          SizedBox(width: 12),
          Text(
            'Mağaza',
            style: TextStyle(
              color: _primaryText,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    color: _accentColor, size: 16),
                SizedBox(width: 6),
                Text(
                  '$_userCredits',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Search Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor, width: 1),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: _primaryText, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Ara...',
                hintStyle: TextStyle(color: _tertiaryText),
                prefixIcon: Icon(Icons.search_outlined, color: _tertiaryText),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _filterListings();
              },
            ),
          ),
          SizedBox(height: 16),
          // Filter Row
          Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  _selectedCategory,
                  Icons.category_outlined,
                      () => _showCategoryFilter(),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildFilterChip(
                  _priceSort,
                  Icons.sort_outlined,
                      () => _showSortFilter(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: _tertiaryText, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: _secondaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: _tertiaryText, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSliver() {
    return SliverFillRemaining(
      child: Center(
        child: CircularProgressIndicator(
          color: _accentColor,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildListingsGrid() {
    final filteredListings = _getFilteredListings();

    if (filteredListings.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) => _buildListingCard(filteredListings[index]),
          childCount: filteredListings.length,
        ),
      ),
    );
  }

  Widget _buildListingCard(dynamic listing) {
    // Resim URL'lerini işle
    List<String> imageUrls = [];
    if (listing['images'] is List) {
      for (var image in listing['images']) {
        if (image is Map && image['url'] != null) {
          final url = image['url'].toString();
          imageUrls.add(url.startsWith('http') ? url : '${UrlConstants.apiBaseUrl}$url');
        } else if (image is String) {
          imageUrls.add(image.startsWith('http') ? image : '${UrlConstants.apiBaseUrl}$image');
        }
      }
    }

    return GestureDetector(
      onTap: () => _showListingDetail(listing),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section with Navigation
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                child: imageUrls.isNotEmpty
                    ? _buildImageCarousel(imageUrls)
                    : _buildPlaceholderImage(),
              ),
            ),
            // Content Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing['title']?.toString() ?? 'Başlık Yok',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${listing['price']?.toString() ?? '0'} ₺',
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Spacer(),
                    Text(
                      listing['category']?.toString() ?? 'Kategori Yok',
                      style: TextStyle(
                        color: _tertiaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel(List<String> imageUrls) {
    if (imageUrls.length == 1) {
      return Image.network(
        imageUrls[0],
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          itemCount: imageUrls.length,
          itemBuilder: (context, index) {
            return Image.network(
              imageUrls[index],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
            );
          },
        ),
        // Navigation arrows
        if (imageUrls.length > 1) ...[
          // Left arrow
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_left, color: Colors.white, size: 20),
              ),
            ),
          ),
          // Right arrow
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
        // Dots indicator
        if (imageUrls.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: imageUrls.asMap().entries.map((entry) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.8),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      color: _surfaceColor,
      child: Icon(
        Icons.image_outlined,
        color: _tertiaryText,
        size: 48,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _surfaceColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.store_outlined,
              color: _tertiaryText,
              size: 40,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Henüz ilan bulunamadı',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'İlk ilanınızı oluşturun',
            style: TextStyle(
              color: _tertiaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalistFAB() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _accentColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _showCreateListingDialog(),
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  // Filter and sorting methods
  List<dynamic> _getFilteredListings() {
    List<dynamic> filtered = List.from(_listings);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((listing) {
        final title = listing['title']?.toString().toLowerCase() ?? '';
        final description = listing['description']?.toString().toLowerCase() ?? '';
        final category = listing['category']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return title.contains(query) ||
            description.contains(query) ||
            category.contains(query);
      }).toList();
    }

    if (_selectedCategory != 'Tümü') {
      filtered = filtered.where((listing) =>
      listing['category']?.toString() == _selectedCategory
      ).toList();
    }

    // Sorting
    switch (_priceSort) {
      case 'Artan Fiyat':
        filtered.sort((a, b) =>
            (double.tryParse(a['price']?.toString() ?? '0') ?? 0)
                .compareTo(double.tryParse(b['price']?.toString() ?? '0') ?? 0)
        );
        break;
      case 'Azalan Fiyat':
        filtered.sort((a, b) =>
            (double.tryParse(b['price']?.toString() ?? '0') ?? 0)
                .compareTo(double.tryParse(a['price']?.toString() ?? '0') ?? 0)
        );
        break;
      case 'Eskiden Yeniye':
        filtered.sort((a, b) =>
            DateTime.parse(a['createdAt'] ?? '1970-01-01')
                .compareTo(DateTime.parse(b['createdAt'] ?? '1970-01-01'))
        );
        break;
      default: // Yeniden Eskiye
        filtered.sort((a, b) =>
            DateTime.parse(b['createdAt'] ?? '1970-01-01')
                .compareTo(DateTime.parse(a['createdAt'] ?? '1970-01-01'))
        );
    }

    return filtered;
  }

  void _filterListings() {
    setState(() {});
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kategori Seçin',
              style: TextStyle(
                color: _primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20),
            ..._categories.map((category) => ListTile(
              title: Text(
                category,
                style: TextStyle(color: _primaryText),
              ),
              trailing: _selectedCategory == category
                  ? Icon(Icons.check_circle, color: _accentColor)
                  : null,
              onTap: () {
                setState(() => _selectedCategory = category);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showSortFilter() {
    final sorts = ['Yeniden Eskiye', 'Eskiden Yeniye', 'Artan Fiyat', 'Azalan Fiyat'];

    showModalBottomSheet(
      context: context,
      backgroundColor: _backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sıralama',
              style: TextStyle(
                color: _primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20),
            ...sorts.map((sort) => ListTile(
              title: Text(
                sort,
                style: TextStyle(color: _primaryText),
              ),
              trailing: _priceSort == sort
                  ? Icon(Icons.check_circle, color: _accentColor)
                  : null,
              onTap: () {
                setState(() => _priceSort = sort);
                Navigator.pop(context);
                _filterListings();
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showListingDetail(dynamic listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListingDetailScreen(listing: listing),
      ),
    );
  }

  void _showCreateListingDialog() async {
    await _loadUserCredits();

    if (_userCredits <= 0) {
      _showBuyCreditDialog();
    } else {
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

  void _showBuyCreditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Kredi Gerekli',
          style: TextStyle(
            color: _primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'İlan vermek için krediniz bulunmuyor. Kredi satın almak ister misiniz?',
          style: TextStyle(color: _secondaryText, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(color: _tertiaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _buyCredit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Kredi Satın Al',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // API Methods
  Future<void> _loadListings() async {
    setState(() => _isLoading = true);
    try {
      final response = await _dio.get('${UrlConstants.apiBaseUrl}/api/store/listings');
      if (mounted && response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _listings = response.data['listings'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('İlanlar yüklenirken hata oluştu', isError: true);
      }
    }
  }

  Future<void> _loadUserCredits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) return;

      final response = await _dio.get(
        '${UrlConstants.apiBaseUrl}/api/store/rights',
        options: Options(
          headers: {'Authorization': 'Bearer $authToken'},
        ),
      );

      if (mounted && response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _userCredits = response.data['credits'] ?? 0;
        });
      }
    } catch (e) {
      print('Credits yükleme hatası: $e');
    }
  }

  Future<void> _buyCredit() async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        _showMessage('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.', isError: true);
        return;
      }

      final response = await _dio.post(
        '${UrlConstants.apiBaseUrl}/api/store/rights/purchase',
        data: {'rightsAmount': 1},
        options: Options(
          headers: {'Authorization': 'Bearer $authToken'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _userCredits = response.data['rights']['availableRights'] ?? _userCredits + 1;
        });
        _showMessage('1 Kredi satın alındı!', isError: false);
      } else {
        _showMessage(response.data['message'] ?? 'Satın alma işlemi başarısız', isError: true);
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        _showMessage(e.response?.data['message'] ?? 'Satın alma işlemi başarısız', isError: true);
      } else {
        _showMessage('Bağlantı hatası', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    try {
      final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
      if (scaffoldMessenger != null && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? Colors.red[400] : Colors.green[400],
          ),
        );
      }
    } catch (e) {
      print('SnackBar gösterme hatası: $e');
    }
  }

  List<String> get categories => _categories;
}

// Create Listing Screen
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
  final Color _accentColor = Color(0xFF4F46E5);
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
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(color: _primaryText, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _tertiaryText),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
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
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              dropdownColor: _surfaceColor,
              style: TextStyle(color: _primaryText, fontSize: 16),
              icon: Icon(Icons.keyboard_arrow_down, color: _tertiaryText),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
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
        Row(
          children: [
            Text(
              'Resimler',
              style: TextStyle(
                color: _primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Spacer(),
            Text(
              '${_selectedImages.length}/5',
              style: TextStyle(
                color: _tertiaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),

        // Add Image Button
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _borderColor,
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  color: _tertiaryText,
                  size: 40,
                ),
                SizedBox(height: 8),
                Text(
                  'Resim Ekle',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'En fazla 5 resim',
                  style: TextStyle(
                    color: _tertiaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Selected Images
        if (_selectedImages.isNotEmpty) ...[
          SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImages[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
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
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createListing,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Text(
          'İlan Oluştur',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      _showMessage('Maksimum 5 resim seçebilirsiniz');
      return;
    }

    final List<XFile>? pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        for (final file in pickedFiles) {
          if (_selectedImages.length < 5) {
            _selectedImages.add(File(file.path));
          }
        }
      });
    }
  }

  Future<void> _createListing() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        if (mounted) {
          _showMessage('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.');
        }
        return;
      }

      Response response;

      if (_selectedImages.isNotEmpty) {
        FormData formData = FormData.fromMap({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'category': _selectedCategory,
          'price': _priceController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
        });

        for (int i = 0; i < _selectedImages.length; i++) {
          String fileName = _selectedImages[i].path.split('/').last;
          formData.files.add(MapEntry(
            'images',
            await MultipartFile.fromFile(
              _selectedImages[i].path,
              filename: fileName,
            ),
          ));
        }

        response = await _dio.post(
          '${UrlConstants.apiBaseUrl}/api/store/listings',
          data: formData,
          options: Options(
            headers: {
              'Authorization': 'Bearer $authToken',
              'Content-Type': 'multipart/form-data',
            },
          ),
        );
      } else {
        response = await _dio.post(
          '${UrlConstants.apiBaseUrl}/api/store/listings',
          data: {
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'category': _selectedCategory,
            'price': _priceController.text.trim(),
            'phoneNumber': _phoneController.text.trim(),
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer $authToken',
              'Content-Type': 'application/json',
            },
          ),
        );
      }

      if (mounted && response.statusCode == 201 && response.data['success'] == true) {
        _showMessage('İlan başarıyla oluşturuldu!');
        if (mounted) {
          widget.onListingCreated();
          Navigator.of(context, rootNavigator: false).pop();
        }
      } else if (mounted) {
        _showMessage(response.data['message'] ?? 'İlan oluşturulamadı');
      }

    } catch (e) {
      if (mounted) {
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
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

// Listing Detail Screen
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
  final Color _accentColor = Color(0xFF4F46E5);
  final Color _borderColor = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: _backgroundColor,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrls.isNotEmpty
                  ? _buildImageCarousel(imageUrls)
                  : _buildPlaceholderImage(),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.listing['title']?.toString() ?? 'Başlık Yok',
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '${widget.listing['price']?.toString() ?? '0'} ₺',
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 24),
                  _buildInfoSection(),
                  SizedBox(height: 24),
                  _buildDescriptionSection(),
                  if (widget.listing['phoneNumber'] != null) ...[
                    SizedBox(height: 24),
                    _buildContactSection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(List<String> imageUrls) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: imageUrls.length,
          onPageChanged: (index) {
            setState(() => _currentImageIndex = index);
          },
          itemBuilder: (context, index) {
            return Image.network(
              imageUrls[index],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
            );
          },
        ),

        // Navigation arrows
        if (imageUrls.length > 1) ...[
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (_currentImageIndex > 0) {
                    _pageController.previousPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_left, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),

          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (_currentImageIndex < imageUrls.length - 1) {
                    _pageController.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_right, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],

        // Dots indicator
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

        // Image counter
        if (imageUrls.length > 1)
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
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
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      color: _surfaceColor,
      child: Icon(
        Icons.image_outlined,
        color: _tertiaryText,
        size: 80,
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Column(
        children: [
          _buildInfoRow('Kategori', widget.listing['category']?.toString() ?? 'Kategori Yok'),
          Divider(color: _borderColor, height: 24),
          _buildInfoRow('İlan No', widget.listing['listingNumber']?.toString() ?? 'N/A'),
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
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: Text(
            widget.listing['description']?.toString() ?? 'Açıklama yok',
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
    return Column(
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
        Container(
          padding: EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.phone_outlined, color: _accentColor, size: 24),
              SizedBox(width: 12),
              Text(
                widget.listing['phoneNumber'].toString(),
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}