// lib/menu/magaza_screen.dart - DÜZELTİLMİŞ VERSİYON

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

class _MagazaScreenState extends State<MagazaScreen> {
  final Dio _dio = Dio();
  final TextEditingController _searchController = TextEditingController();

  // State variables
  List<dynamic> _listings = [];
  int _userCredits = 0;
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'Tümü';
  String _priceSort = 'Yeniden Eskiye';
  RangeValues _priceRange = RangeValues(0, 10000);

  final List<String> _categories = ['Tümü', 'Elektronik', 'Giyim', 'Ev & Yaşam', 'Spor', 'Kitap', 'Oyun', 'Müzik Aleti', 'Diğer'];

  // Colors
  final Color _backgroundColor = Color(0xFF0A0A0B);
  final Color _surfaceColor = Color(0xFF1A1A1C);
  final Color _cardColor = Color(0xFF1E1E21);
  final Color _primaryText = Color(0xFFFFFFFF);
  final Color _secondaryText = Color(0xFFB3B3B3);
  final Color _tertiaryText = Color(0xFF6B7280);
  final Color _accentColor = Color(0xFF3B82F6);

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
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          _buildUserCreditsCard(),
          Expanded(child: _buildListingsContent()),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _backgroundColor,
      elevation: 0,
      title: Text(
        'Mağaza',
        style: TextStyle(
          color: _primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _loadListings(),
          icon: Icon(Icons.refresh, color: _primaryText),
        ),
      ],
    );
  }

  Widget _buildUserCreditsCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: _accentColor),
          SizedBox(width: 12),
          Text(
            'İlan Hakkı: $_userCredits',
            style: TextStyle(
              color: _primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Spacer(),
          ElevatedButton(
            onPressed: _buyCredit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Satın Al',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            style: TextStyle(color: _primaryText),
            decoration: InputDecoration(
              hintText: 'İlan ara...',
              hintStyle: TextStyle(color: _tertiaryText),
              prefixIcon: Icon(Icons.search, color: _tertiaryText),
              filled: true,
              fillColor: _surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          SizedBox(height: 12),
          // Filter buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCategoryFilter,
                  icon: Icon(Icons.category, size: 16),
                  label: Text(_selectedCategory),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _surfaceColor,
                    foregroundColor: _primaryText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showSortFilter,
                  icon: Icon(Icons.sort, size: 16),
                  label: Text(_priceSort),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _surfaceColor,
                    foregroundColor: _primaryText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListingsContent() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _accentColor));
    }

    final filtered = filteredListings;
    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadListings,
      color: _accentColor,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) => _buildListingCard(filtered[index]),
      ),
    );
  }

  Widget _buildListingCard(dynamic listing) {
    return Card(
      color: _cardColor,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showListingDetail(listing),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.image, color: _tertiaryText, size: 32),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing['title'] ?? 'Başlık Yok',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${listing['price']} ₺',
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      listing['category'] ?? 'Kategori Yok',
                      style: TextStyle(color: _tertiaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  // DÜZELTİLMİŞ kredi satın alma - gerçek API çağrısı
  Future<void> _buyCredit() async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        _showMessage('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.', isError: true);
        return;
      }

      // Backend'e gerçek API çağrısı yap
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
        _showMessage('1 İlan hakkı satın alındı!', isError: false);
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

  // İlan Ver Dialog'u - DÜZELTİLMİŞ kredi kontrolü
  void _showCreateListingDialog() async {
    // Önce güncel kredi durumunu kontrol et
    await _loadUserCredits();

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
              onPressed: () async {
                Navigator.pop(context);
                await _buyCredit();
                // Satın alma başarılıysa ilan verme sayfasına git
                if (mounted && _userCredits > 0) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateListingScreen(
                        onListingCreated: _loadListings,
                      ),
                    ),
                  );
                }
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
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateListingScreen(
            onListingCreated: _loadListings,
          ),
        ),
      );
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

  // Dialog methods
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
          maxHeight: MediaQuery.of(context).size.height * 0.7,
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

  void _showListingDetail(dynamic listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListingDetailScreen(listing: listing),
      ),
    );
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

// Create Listing Screen - DÜZELTİLMİŞ
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
  final Color _tertiaryText = Color(0xFF6B7280);
  final Color _accentColor = Color(0xFF3B82F6);

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
              _buildFormField('Başlık', _titleController, 'İlan başlığını yazın'),
              SizedBox(height: 20),
              _buildCategoryDropdown(),
              SizedBox(height: 20),
              _buildFormField('Fiyat', _priceController, 'Fiyat (₺)', isNumber: true),
              SizedBox(height: 20),
              _buildFormField('Telefon', _phoneController, 'Telefon numaranız'),
              SizedBox(height: 20),
              _buildFormField('Açıklama', _descriptionController, 'İlan açıklaması', maxLines: 4),
              SizedBox(height: 20),
              _buildImageSection(),
              SizedBox(height: 30),
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, String hint, {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: TextStyle(color: _primaryText),
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _tertiaryText),
            filled: true,
            fillColor: _surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label gereklidir';
            }
            if (isNumber) {
              final price = double.tryParse(value);
              if (price == null || price <= 0) {
                return 'Geçerli bir fiyat girin';
              }
            }
            return null;
          },
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
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          dropdownColor: _surfaceColor,
          style: TextStyle(color: _primaryText),
          decoration: InputDecoration(
            filled: true,
            fillColor: _surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: _categories.map((category) => DropdownMenuItem(
            value: category,
            child: Text(category),
          )).toList(),
          onChanged: (value) => setState(() => _selectedCategory = value!),
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
                fontWeight: FontWeight.w500,
              ),
            ),
            Spacer(),
            Text(
              '${_selectedImages.length}/5',
              style: TextStyle(color: _tertiaryText),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (_selectedImages.isNotEmpty)
          Container(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) => Container(
                width: 100,
                margin: EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(_selectedImages[index]),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImages.removeAt(index)),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _selectedImages.length < 5 ? _pickImages : null,
          icon: Icon(Icons.add_photo_alternate),
          label: Text('Resim Ekle'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _surfaceColor,
            foregroundColor: _primaryText,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
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
        // Resimli upload - FormData kullan
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
              // contentType belirtmek yerine backend'in otomatik algılamasına bırakıyoruz
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
        // Resimsiz upload - JSON kullan (FormData değil!)
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

        // Widget hala mounted ise işlemleri yap
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
    // Güvenli widget kontrolleri
    if (!mounted) return;

    try {
      final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
      if (scaffoldMessenger != null && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      // Hata durumunda sessizce geç
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
              'Kategori: ${listing['category'] ?? 'Kategori Yok'}',
              style: TextStyle(color: _secondaryText, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'İlan No: ${listing['listingNumber'] ?? 'N/A'}',
              style: TextStyle(color: _secondaryText, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}