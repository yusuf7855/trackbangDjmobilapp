// lib/menu/magaza_screen.dart - İlan Sistemi
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
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

  Future<void> _buyCredits() async {
    try {
      final response = await _dio.post('${UrlConstants.apiBaseUrl}/api/user/buy-credits');
      if (response.statusCode == 200) {
        setState(() {
          _userCredits += 1;
        });
        _showMessage('1 İlan hakkı satın alındı!', isError: false);
      }
    } catch (e) {
      _showMessage('Satın alma işlemi başarısız', isError: true);
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
                  hintStyle: TextStyle(color: _tertiaryText, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: _secondaryText, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
          ),
          SizedBox(width: 12),
          GestureDetector(
            onTap: _buyCredits,
            child: Container(
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    '4€',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 60,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Category filter
            GestureDetector(
              onTap: () => _showCategoryFilter(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
            SizedBox(width: 12),

            // Price filter
            GestureDetector(
              onTap: () => _showPriceFilter(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, color: _secondaryText, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Fiyat',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),

            // Sort filter
            GestureDetector(
              onTap: () => _showSortFilter(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _priceSort,
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
          ],
        ),
      ),
    );
  }

  Widget _buildResultsInfo(int count) {
    if (_isLoading) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            '$count ilan bulundu',
            style: TextStyle(
              color: _tertiaryText,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingsGrid(List<dynamic> listings) {
    return RefreshIndicator(
      onRefresh: _loadListings,
      color: _accentColor,
      backgroundColor: _surfaceColor,
      child: GridView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: listings.length,
        itemBuilder: (context, index) => _buildListingCard(listings[index]),
      ),
    );
  }

  Widget _buildListingCard(dynamic listing) {
    final String title = listing['title']?.toString() ?? 'Başlık Yok';
    final String category = listing['category']?.toString() ?? '';
    final double price = (listing['price'] ?? 0).toDouble();
    final String listingNumber = listing['listingNumber']?.toString() ?? '';
    final List<dynamic> images = listing['images'] ?? [];
    final bool isActive = listing['isActive'] ?? false;
    final String status = isActive ? 'Aktif' : 'Pasif';

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
            // Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: images.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    images[0],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderImage(),
                  ),
                )
                    : _buildPlaceholderImage(),
              ),
            ),

            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),

                    // Category & Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category,
                            style: TextStyle(
                              color: _secondaryText,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive ? _successColor.withOpacity(0.2) : _warningColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: isActive ? _successColor : _warningColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),

                    // Price & Listing Number
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₺${price.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: _accentColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '#$listingNumber',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
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

  // Dialog Methods
  void _showCategoryFilter() {
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
              'Kategori Seç',
              style: TextStyle(
                color: _primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            ...categories.map((category) => ListTile(
              title: Text(category, style: TextStyle(color: _primaryText)),
              trailing: _selectedCategory == category
                  ? Icon(Icons.check, color: _accentColor)
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

  void _showPriceFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
              SizedBox(height: 16),
              RangeSlider(
                values: _priceRange,
                min: _minPrice,
                max: _maxPrice,
                divisions: 100,
                activeColor: _accentColor,
                inactiveColor: _borderColor,
                labels: RangeLabels(
                  '₺${_priceRange.start.round()}',
                  '₺${_priceRange.end.round()}',
                ),
                onChanged: (values) {
                  setModalState(() => _priceRange = values);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('₺${_priceRange.start.round()}', style: TextStyle(color: _secondaryText)),
                  Text('₺${_priceRange.end.round()}', style: TextStyle(color: _secondaryText)),
                ],
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Uygula', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
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

  void _showCreateListingDialog() {
    if (_userCredits <= 0) {
      _showMessage('İlan vermek için kredi satın almanız gerekiyor!', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateListingScreen(
          onListingCreated: _loadListings,
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

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      _showMessage('Maksimum 5 resim seçebilirsiniz');
      return;
    }

    final List<XFile>? images = await _picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (images != null) {
      setState(() {
        for (final image in images) {
          if (_selectedImages.length < 5) {
            _selectedImages.add(File(image.path));
          }
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _createListing() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      _showMessage('En az 1 resim seçmelisiniz');
      return;
    }

    setState(() => _isLoading = true);

    try {
      FormData formData = FormData.fromMap({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'category': _selectedCategory,
      });

      // Add images
      for (int i = 0; i < _selectedImages.length; i++) {
        formData.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(_selectedImages[i].path),
        ));
      }

      final response = await _dio.post(
        '${UrlConstants.apiBaseUrl}/api/listings',
        data: formData,
      );

      if (response.statusCode == 201) {
        _showMessage('İlan başarıyla oluşturuldu!');
        widget.onListingCreated();
        Navigator.pop(context);
      }
    } catch (e) {
      _showMessage('İlan oluşturulurken hata oluştu');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _accentColor,
      ),
    );
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
          style: TextStyle(
            color: _primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Resimler (Maksimum 5)'),
              _buildImageSection(),
              SizedBox(height: 24),

              _buildSectionTitle('Kategori'),
              _buildCategoryDropdown(),
              SizedBox(height: 24),

              _buildSectionTitle('İlan Başlığı'),
              _buildTextFormField(
                controller: _titleController,
                hintText: 'İlan başlığınızı girin',
                validator: (value) => value?.isEmpty == true ? 'Başlık gerekli' : null,
              ),
              SizedBox(height: 16),

              _buildSectionTitle('Telefon Numarası'),
              _buildTextFormField(
                controller: _phoneController,
                hintText: '+90 555 123 45 67',
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty == true ? 'Telefon numarası gerekli' : null,
              ),
              SizedBox(height: 16),

              _buildSectionTitle('Fiyat (₺)'),
              _buildTextFormField(
                controller: _priceController,
                hintText: '0',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty == true) return 'Fiyat gerekli';
                  if (double.tryParse(value!) == null) return 'Geçerli bir fiyat girin';
                  return null;
                },
              ),
              SizedBox(height: 16),

              _buildSectionTitle('Açıklama'),
              _buildTextFormField(
                controller: _descriptionController,
                hintText: 'İlanınızın detaylarını yazın...',
                maxLines: 5,
                validator: (value) => value?.isEmpty == true ? 'Açıklama gerekli' : null,
              ),
              SizedBox(height: 32),

              _buildCreateButton(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: _primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      children: [
        if (_selectedImages.isNotEmpty) ...[
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImages[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _errorColor,
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
          SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor, style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, color: _secondaryText, size: 32),
                SizedBox(height: 8),
                Text(
                  _selectedImages.isEmpty ? 'Resim Ekle' : 'Daha Fazla Resim Ekle',
                  style: TextStyle(color: _secondaryText, fontSize: 14),
                ),
                Text(
                  '${_selectedImages.length}/5',
                  style: TextStyle(color: _tertiaryText, fontSize: 12),
                ),
              ],
            ),
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
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 2,
          ),
        )
            : Text(
          'İlanı Oluştur',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
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
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  // Colors
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

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final String title = listing['title']?.toString() ?? '';
    final String description = listing['description']?.toString() ?? '';
    final String category = listing['category']?.toString() ?? '';
    final String phone = listing['phone']?.toString() ?? '';
    final double price = (listing['price'] ?? 0).toDouble();
    final String listingNumber = listing['listingNumber']?.toString() ?? '';
    final List<dynamic> images = listing['images'] ?? [];
    final bool isActive = listing['isActive'] ?? false;
    final String createdAt = listing['createdAt']?.toString() ?? '';

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: _backgroundColor,
            expandedHeight: 300,
            pinned: true,
            leading: Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: images.isNotEmpty
                  ? Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setState(() => _currentImageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              color: _surfaceColor,
                              child: Icon(
                                Icons.image_not_supported,
                                color: _secondaryText,
                                size: 64,
                              ),
                            ),
                      );
                    },
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: images.asMap().entries.map((entry) {
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
              )
                  : Container(
                color: _surfaceColor,
                child: Icon(
                  Icons.image_not_supported,
                  color: _secondaryText,
                  size: 64,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status and Category
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? _successColor.withOpacity(0.2) : _warningColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isActive ? 'Aktif' : 'Pasif',
                          style: TextStyle(
                            color: isActive ? _successColor : _warningColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: _secondaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Spacer(),
                      Text(
                        '#$listingNumber',
                        style: TextStyle(
                          color: _tertiaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 12),

                  // Price
                  Text(
                    '₺${price.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Description
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Açıklama',
                          style: TextStyle(
                            color: _primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            color: _secondaryText,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Contact Info
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İletişim',
                          style: TextStyle(
                            color: _primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.phone, color: _accentColor, size: 18),
                            SizedBox(width: 8),
                            Text(
                              phone,
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
                  SizedBox(height: 16),

                  // Date
                  if (createdAt.isNotEmpty)
                    Text(
                      'İlan Tarihi: ${_formatDate(createdAt)}',
                      style: TextStyle(
                        color: _tertiaryText,
                        fontSize: 12,
                      ),
                    ),
                  SizedBox(height: 32),

                  // Contact Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _callPhone(phone),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(Icons.phone, color: Colors.white),
                      label: Text(
                        'Ara',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _callPhone(String phone) {
    // Phone call functionality would be implemented here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aranıyor: $phone'),
        backgroundColor: _accentColor,
      ),
    );
  }
}
