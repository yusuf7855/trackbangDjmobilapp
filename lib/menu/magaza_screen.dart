// lib/menu/magaza_screen.dart - İlan Sistemi (Düzeltilmiş)
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import '../url_constants.dart';

class MagazaScreen extends StatefulWidget {
  @override
  _MagazaScreenState createState() => _MagazaScreenState();
}

class _MagazaScreenState extends State<MagazaScreen>
    with TickerProviderStateMixin {
  final Dio _dio = Dio();
  late AnimationController _animationController;

  // Colors - Sample Bank'tan alınan renk paleti
  final Color _backgroundColor = Color(0xFF0A0A0B);
  final Color _surfaceColor = Color(0xFF1A1A1C);
  final Color _cardColor = Color(0xFF1E1E21);
  final Color _primaryText = Color(0xFFFFFFFF);
  final Color _secondaryText = Color(0xFFB3B3B3);
  final Color _tertiaryText = Color(0xFF666666);
  final Color _accentColor = Color(0xFF3B82F6);
  final Color _borderColor = Color(0xFF2A2A2E);
  final Color _successColor = Color(0xFF10B981);
  final Color _warningColor = Color(0xFFF59E0B);
  final Color _errorColor = Color(0xFFEF4444);

  // State variables
  List<dynamic> _listings = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();

  // Filter states
  String _selectedCategory = 'Tümü';
  String _priceSort = 'Yeniden Eskiye';
  List<String> _categories = ['Tümü', 'Elektronik', 'Giyim', 'Ev & Yaşam', 'Spor', 'Kitap', 'Oyun', 'Müzik Aleti', 'Diğer'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Price filter
  double _minPrice = 0;
  double _maxPrice = 10000;
  RangeValues _priceRange = RangeValues(0, 10000);

  // User credits
  int _userCredits = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _loadListings();
    _loadUserCredits();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // API Methods
  Future<void> _loadListings() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final response = await _dio.get('${UrlConstants.apiBaseUrl}/api/listings');
      if (mounted && response.statusCode == 200) {
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
      final response = await _dio.get('${UrlConstants.apiBaseUrl}/api/user/credits');
      if (mounted && response.statusCode == 200) {
        setState(() {
          _userCredits = response.data['credits'] ?? 0;
        });
      }
    } catch (e) {
      // Hata durumunda varsayılan değer
    }
  }

  // Filter methods
  List<dynamic> get filteredListings {
    List<dynamic> filtered = List.from(_listings);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((listing) {
        final title = listing['title']?.toString().toLowerCase() ?? '';
        final description = listing['description']?.toString().toLowerCase() ?? '';
        final listingNumber = listing['listingNumber']?.toString().toLowerCase() ?? '';
        final searchLower = _searchQuery.toLowerCase();

        return title.contains(searchLower) ||
            description.contains(searchLower) ||
            listingNumber.contains(searchLower);
      }).toList();
    }

    // Category filter
    if (_selectedCategory != 'Tümü') {
      filtered = filtered.where((listing) =>
      listing['category']?.toString() == _selectedCategory).toList();
    }

    // Price filter
    filtered = filtered.where((listing) {
      final price = (listing['price'] ?? 0).toDouble();
      return price >= _priceRange.start && price <= _priceRange.end;
    }).toList();

    // Sort
    switch (_priceSort) {
      case 'Artan Fiyat':
        filtered.sort((a, b) => ((a['price'] ?? 0).toDouble()).compareTo((b['price'] ?? 0).toDouble()));
        break;
      case 'Azalan Fiyat':
        filtered.sort((a, b) => ((b['price'] ?? 0).toDouble()).compareTo((a['price'] ?? 0).toDouble()));
        break;
      case 'Eskiden Yeniye':
        filtered.sort((a, b) => DateTime.parse(a['createdAt'] ?? '').compareTo(DateTime.parse(b['createdAt'] ?? '')));
        break;
      default: // Yeniden Eskiye
        filtered.sort((a, b) => DateTime.parse(b['createdAt'] ?? '').compareTo(DateTime.parse(a['createdAt'] ?? '')));
    }

    return filtered;
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _errorColor : _successColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = filteredListings;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          _buildResultsInfo(filteredItems.length),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : filteredItems.isEmpty
                ? _buildEmptyState()
                : _buildListingsGrid(filteredItems),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _backgroundColor,
      elevation: 0,
      title: Text(
        'Mağaza',
        style: TextStyle(
          color: _primaryText,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        Container(
          margin: EdgeInsets.only(right: 16),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.credit_card, color: _accentColor, size: 16),
              SizedBox(width: 4),
              Text(
                '$_userCredits',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor.withOpacity(0.3)),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: _primaryText, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'İlan ara (başlık, açıklama, numara)',
                  hintStyle: TextStyle(color: _tertiaryText),
                  prefixIcon: Icon(Icons.search, color: _secondaryText),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: _secondaryText, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                      : null,
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 48,
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Kategori Filtresi
          Expanded(
            child: GestureDetector(
              onTap: _showCategoryFilter,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.category, color: _secondaryText, size: 16),
                    SizedBox(width: 6),
                    Text(
                      _selectedCategory,
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, color: _secondaryText, size: 16),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(width: 10),

          // Fiyat Filtresi
          Expanded(
            child: GestureDetector(
              onTap: _showPriceFilter,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tune, color: _secondaryText, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Fiyat',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, color: _secondaryText, size: 16),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(width: 10),

          // Sıralama Filtresi
          Expanded(
            child: GestureDetector(
              onTap: _showSortFilter,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sort, color: _secondaryText, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Sırala',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, color: _secondaryText, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsInfo(int count) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            '$count ilan bulundu',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingsGrid(List<dynamic> listings) {
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final listing = listings[index];
        return _buildListingCard(listing);
      },
    );
  }

  Widget _buildListingCard(dynamic listing) {
    final images = listing['images'] as List<dynamic>? ?? [];
    final firstImage = images.isNotEmpty ? images[0] : null;

    return GestureDetector(
      onTap: () => _showListingDetail(listing),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  color: _surfaceColor,
                ),
                child: firstImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    firstImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildNoImagePlaceholder(),
                  ),
                )
                    : _buildNoImagePlaceholder(),
              ),
            ),

            // Content section
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing['title'] ?? 'Başlık Yok',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${listing['price']} ₺',
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    Text(
                      listing['category'] ?? 'Kategori Yok',
                      style: TextStyle(
                        color: _tertiaryText,
                        fontSize: 12,
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

  Widget _buildNoImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: _secondaryText, size: 32),
          SizedBox(height: 8),
          Text(
            'Resim Yok',
            style: TextStyle(color: _tertiaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
          ),
          SizedBox(height: 16),
          Text(
            'İlanlar yükleniyor...',
            style: TextStyle(color: _secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, color: _tertiaryText, size: 64),
          SizedBox(height: 16),
          Text(
            'Henüz ilan bulunamadı',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'İlk ilanınızı oluşturun',
            style: TextStyle(color: _tertiaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _showCreateListingDialog(),
      backgroundColor: _accentColor,
      label: Text(
        'İlan Ver',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: Icon(Icons.add, color: Colors.white),
    );
  }

  // Dialog Methods - Kategori filter'ını kaydırılabilir yaptık
  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7, // Max yükseklik
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kategori Seç',
              style: TextStyle(
                color: _primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            // Kaydırılabilir kategori listesi
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: _categories.map((category) => ListTile(
                    title: Text(category, style: TextStyle(color: _primaryText)),
                    trailing: _selectedCategory == category
                        ? Icon(Icons.check, color: _accentColor)
                        : null,
                    onTap: () {
                      setState(() => _selectedCategory = category);
                      Navigator.pop(context);
                    },
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fiyat Aralığı',
              style: TextStyle(
                color: _primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20),
            RangeSlider(
              values: _priceRange,
              min: 0,
              max: 10000,
              divisions: 100,
              activeColor: _accentColor,
              inactiveColor: _borderColor,
              labels: RangeLabels(
                '${_priceRange.start.round()} ₺',
                '${_priceRange.end.round()} ₺',
              ),
              onChanged: (values) {
                setState(() => _priceRange = values);
              },
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Min: ${_priceRange.start.round()} ₺',
                  style: TextStyle(color: _secondaryText),
                ),
                Text(
                  'Max: ${_priceRange.end.round()} ₺',
                  style: TextStyle(color: _secondaryText),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _priceRange = RangeValues(0, 10000));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _borderColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Sıfırla', style: TextStyle(color: _primaryText)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Uygula', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSortFilter() {
    final sorts = ['Yeniden Eskiye', 'Eskiden Yeniye', 'Artan Fiyat', 'Azalan Fiyat'];

    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sıralama',
              style: TextStyle(
                color: _primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            ...sorts.map((sort) => ListTile(
              title: Text(sort, style: TextStyle(color: _primaryText)),
              trailing: _priceSort == sort
                  ? Icon(Icons.check, color: _accentColor)
                  : null,
              onTap: () {
                setState(() => _priceSort = sort);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  // İlan Ver Dialog'u - Kredi sistemi düzeltildi
  void _showCreateListingDialog() {
    if (_userCredits <= 0) {
      // Kredi yoksa satın alma önerisi
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _surfaceColor,
          title: Text(
            'İlan Vermek İçin Kredi Gerekli',
            style: TextStyle(color: _primaryText),
          ),
          content: Text(
            'İlan vermek için krediniz bulunmuyor. Kredi satın almak ister misiniz?',
            style: TextStyle(color: _secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal', style: TextStyle(color: _tertiaryText)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _buyCredit(); // Kredi satın al
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accentColor),
              child: Text('Satın Al', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    // Kredi varsa direkt ilan oluşturma sayfasına git
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateListingScreen(
          onListingCreated: _loadListings,
        ),
      ),
    );
  }

  // Basitleştirilmiş kredi satın alma
  Future<void> _buyCredit() async {
    try {
      // Simulated purchase - backend olmadan direkt ekliyoruz
      setState(() {
        _userCredits += 1;
      });
      _showMessage('1 İlan hakkı satın alındı!', isError: false);

      // Şimdi ilan verme sayfasına git
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateListingScreen(
            onListingCreated: _loadListings,
          ),
        ),
      );
    } catch (e) {
      _showMessage('Satın alma işlemi başarısız', isError: true);
    }
  }

  void _showListingDetail(dynamic listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListingDetailScreen(listing: listing),
      ),
    );
  }

  List<String> get categories => _categories;
}

// Create Listing Screen - Aynı kalacak
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

  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String _selectedCategory = 'Elektronik';
  List<File> _selectedImages = [];
  bool _isLoading = false;

  final List<String> _categories = ['Elektronik', 'Giyim', 'Ev & Yaşam', 'Spor', 'Kitap', 'Oyun', 'Müzik Aleti', 'Diğer'];

  // Colors
  final Color _backgroundColor = Color(0xFF0A0A0B);
  final Color _surfaceColor = Color(0xFF1A1A1C);
  final Color _cardColor = Color(0xFF1E1E21);
  final Color _primaryText = Color(0xFFFFFFFF);
  final Color _secondaryText = Color(0xFFB3B3B3);
  final Color _tertiaryText = Color(0xFF666666);
  final Color _accentColor = Color(0xFF3B82F6);
  final Color _borderColor = Color(0xFF2A2A2E);
  final Color _errorColor = Color(0xFFEF4444);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        title: Text(
          'İlan Oluştur',
          style: TextStyle(color: _primaryText),
        ),
        iconTheme: IconThemeData(color: _primaryText),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextFormField(
                controller: _titleController,
                hintText: 'İlan Başlığı',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Başlık gerekli';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: _descriptionController,
                hintText: 'Açıklama',
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Açıklama gerekli';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _buildCategoryDropdown(),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: _priceController,
                hintText: 'Fiyat (₺)',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Fiyat gerekli';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Geçerli bir fiyat girin';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: _phoneController,
                hintText: 'Telefon Numarası',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Telefon numarası gerekli';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              _buildImagePicker(),
              SizedBox(height: 32),
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resimler (Maksimum 5)',
          style: TextStyle(
            color: _primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor, style: BorderStyle.solid),
            ),
            child: _selectedImages.isEmpty
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate, color: _secondaryText, size: 32),
                SizedBox(height: 8),
                Text(
                  'Resim Ekle',
                  style: TextStyle(color: _secondaryText, fontSize: 14),
                ),
              ],
            )
                : GridView.builder(
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _selectedImages.length + (_selectedImages.length < 5 ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _selectedImages.length) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImages[index],
                          width: double.infinity,
                          height: double.infinity,
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
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: _errorColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: _secondaryText, size: 24),
                          SizedBox(height: 4),
                          Text(
                            'Ekle',
                            style: TextStyle(color: _secondaryText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ),
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Text(
                  _selectedImages.isEmpty ? 'Resim Ekle' : 'Daha Fazla Resim Ekle',
                  style: TextStyle(color: _secondaryText, fontSize: 14),
                ),
                Spacer(),
                Text(
                  '${_selectedImages.length}/5',
                  style: TextStyle(color: _tertiaryText, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          dropdownColor: _surfaceColor,
          icon: Icon(Icons.keyboard_arrow_down, color: _secondaryText),
          style: TextStyle(color: _primaryText, fontSize: 16),
          items: _categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCategory = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: _primaryText, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: _tertiaryText),
        filled: true,
        fillColor: _surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _errorColor),
        ),
        contentPadding: EdgeInsets.all(16),
      ),
      validator: validator,
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
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
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
      // SharedPreferences'dan auth token al
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        _showMessage('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.');
        return;
      }

      // FormData oluştur (resimler için)
      FormData formData = FormData.fromMap({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'price': _priceController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
      });

      // Resimleri ekle
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

      // API çağrısı yap
      final response = await _dio.post(
        'http://localhost:5000/api/store/listings', // Backend URL'ini ayarla
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        _showMessage('İlan başarıyla oluşturuldu!');
        widget.onListingCreated(); // Sayfa yenilemesi için
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// Listing Detail Screen - Basit görüntüleme
class ListingDetailScreen extends StatelessWidget {
  final dynamic listing;

  ListingDetailScreen({required this.listing});

  @override
  Widget build(BuildContext context) {
    final Color _backgroundColor = Color(0xFF0A0A0B);
    final Color _primaryText = Color(0xFFFFFFFF);
    final Color _secondaryText = Color(0xFFB3B3B3);
    final Color _accentColor = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        title: Text(
          'İlan Detayı',
          style: TextStyle(color: _primaryText),
        ),
        iconTheme: IconThemeData(color: _primaryText),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              listing['title'] ?? 'Başlık Yok',
              style: TextStyle(
                color: _primaryText,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '${listing['price']} ₺',
              style: TextStyle(
                color: _accentColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Açıklama',
              style: TextStyle(
                color: _primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              listing['description'] ?? 'Açıklama yok',
              style: TextStyle(color: _secondaryText, fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Kategori: ${listing['category'] ?? 'Belirtilmemiş'}',
              style: TextStyle(color: _secondaryText, fontSize: 16),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // İletişim fonksiyonu
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'İletişime Geç',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}