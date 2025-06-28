import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import '../url_constants.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart'; // MediaType için
class MagazaScreen extends StatefulWidget {
  @override
  _MagazaScreenState createState() => _MagazaScreenState();
}

class _MagazaScreenState extends State<MagazaScreen>
    with TickerProviderStateMixin {
  late Dio _dio;
  late AnimationController _animationController;

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

    // Dio configuration
    _dio = Dio(BaseOptions(
      baseUrl: UrlConstants.apiBaseUrl,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
      sendTimeout: Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors for better debugging
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('🔵 API İsteği: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        print('🟢 API Yanıtı: ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (error, handler) {
        print('🔴 API Hatası: ${error.requestOptions.uri}');
        print('🔴 Hata Detayı: ${error.message}');
        if (error.response != null) {
          print('🔴 Response Data: ${error.response?.data}');
        }
        handler.next(error);
      },
    ));

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
      print('📡 İlanlar yükleniyor...');

      // Doğru endpoint - /api/store/listings
      final response = await _dio.get('/api/store/listings');

      print('📊 Response Status: ${response.statusCode}');
      print('📄 Response Data: ${response.data}');

      if (mounted && response.statusCode == 200) {
        final data = response.data;

        // Backend response format kontrolü
        if (data is Map<String, dynamic>) {
          setState(() {
            // Backend'den dönen format: {success: true, listings: [...]}
            _listings = data['listings'] ?? [];
            _isLoading = false;
          });
          print('✅ ${_listings.length} ilan yüklendi');
        } else {
          throw Exception('Beklenmeyen response formatı');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } catch (e) {
      print('❌ İlan yükleme hatası: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _listings = []; // Boş liste göster
        });

        // Daha detaylı hata mesajı
        String errorMessage = 'İlanlar yüklenirken hata oluştu';

        if (e is DioException) {
          switch (e.type) {
            case DioExceptionType.connectionTimeout:
            case DioExceptionType.sendTimeout:
            case DioExceptionType.receiveTimeout:
              errorMessage = 'Bağlantı zaman aşımına uğradı';
              break;
            case DioExceptionType.badResponse:
              errorMessage = 'Sunucu hatası (${e.response?.statusCode})';
              break;
            case DioExceptionType.connectionError:
              errorMessage = 'İnternet bağlantısını kontrol edin';
              break;
            default:
              errorMessage = 'Bilinmeyen hata: ${e.message}';
          }
        }

        _showMessage(errorMessage, isError: true);
      }
    }
  }

  Future<void> _loadUserCredits() async {
    try {
      // Auth token kontrolü
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        print('⚠️ Auth token bulunamadı, kredi bilgisi yüklenemedi');
        return;
      }

      final response = await _dio.get(
        '/api/store/rights',
        options: Options(
          headers: {'Authorization': 'Bearer $authToken'},
        ),
      );

      if (mounted && response.statusCode == 200) {
        setState(() {
          _userCredits = response.data['credits'] ?? 0;
        });
      }
    } catch (e) {
      print('⚠️ Kredi bilgisi alınamadı: $e');
      // Kredi bilgisi alamazsa varsayılan değer 0 kalsın
    }
  }

  // Pull to refresh
  Future<void> _refreshListings() async {
    setState(() => _isRefreshing = true);
    await _loadListings();
    await _loadUserCredits();
    setState(() => _isRefreshing = false);
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
        filtered.sort((a, b) => DateTime.parse(a['createdAt'] ?? '2020-01-01').compareTo(DateTime.parse(b['createdAt'] ?? '2020-01-01')));
        break;
      default: // Yeniden Eskiye
        filtered.sort((a, b) => DateTime.parse(b['createdAt'] ?? '2020-01-01').compareTo(DateTime.parse(a['createdAt'] ?? '2020-01-01')));
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
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        title: Text(
          'Mağaza',
          style: TextStyle(
            color: _primaryText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Kredi göstergesi
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  '$_userCredits',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshListings,
        color: _accentColor,
        child: Column(
          children: [
            // Search bar
            Container(
              padding: EdgeInsets.all(16),
              child: TextField(
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
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),

            // Filters
            Container(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Category filter
                  Container(
                    margin: EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_selectedCategory),
                      selected: _selectedCategory != 'Tümü',
                      onSelected: (selected) => _showCategoryPicker(),
                      selectedColor: _accentColor,
                      backgroundColor: _surfaceColor,
                      labelStyle: TextStyle(
                        color: _selectedCategory != 'Tümü' ? Colors.white : _secondaryText,
                      ),
                    ),
                  ),

                  // Price sort
                  Container(
                    margin: EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_priceSort),
                      onSelected: (selected) => _showSortPicker(),
                      backgroundColor: _surfaceColor,
                      labelStyle: TextStyle(color: _secondaryText),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 8),

            // Content
            Expanded(
              child: _isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _accentColor),
                    SizedBox(height: 16),
                    Text(
                      'İlanlar yükleniyor...',
                      style: TextStyle(color: _secondaryText),
                    ),
                  ],
                ),
              )
                  : filteredListings.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: _tertiaryText,
                    ),
                    SizedBox(height: 16),
                    Text(
                      _listings.isEmpty
                          ? 'Henüz ilan yok'
                          : 'Filtrelere uygun ilan bulunamadı',
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _refreshListings,
                      icon: Icon(Icons.refresh),
                      label: Text('Yenile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16),
                itemCount: filteredListings.length,
                itemBuilder: (context, index) {
                  final listing = filteredListings[index];
                  return _buildListingCard(listing);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewListing,
        backgroundColor: _accentColor,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'İlan Ver',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildListingCard(dynamic listing) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: InkWell(
        onTap: () => _showListingDetail(listing),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder veya gerçek resim
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Icon(
                  Icons.image,
                  size: 48,
                  color: _tertiaryText,
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing['title'] ?? 'Başlık Yok',
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 8),

                  Text(
                    listing['description'] ?? 'Açıklama yok',
                    style: TextStyle(color: _secondaryText, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${listing['price'] ?? 0} ₺',
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          listing['category'] ?? 'Kategori',
                          style: TextStyle(
                            color: _secondaryText,
                            fontSize: 12,
                          ),
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

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kategori Seç',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ..._categories.map((category) => ListTile(
                title: Text(
                  category,
                  style: TextStyle(color: _primaryText),
                ),
                leading: Radio<String>(
                  value: category,
                  groupValue: _selectedCategory,
                  onChanged: (value) {
                    setState(() => _selectedCategory = value!);
                    Navigator.pop(context);
                  },
                  activeColor: _accentColor,
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  void _showSortPicker() {
    final sortOptions = [
      'Yeniden Eskiye',
      'Eskiden Yeniye',
      'Artan Fiyat',
      'Azalan Fiyat'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sıralama',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ...sortOptions.map((option) => ListTile(
                title: Text(
                  option,
                  style: TextStyle(color: _primaryText),
                ),
                leading: Radio<String>(
                  value: option,
                  groupValue: _priceSort,
                  onChanged: (value) {
                    setState(() => _priceSort = value!);
                    Navigator.pop(context);
                  },
                  activeColor: _accentColor,
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createNewListing() async {
    // Kredi kontrolü
    if (_userCredits <= 0) {
      _showCreditDialog();
      return;
    }

    // İlan oluşturma sayfasına git
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateListingScreen(
          onListingCreated: _loadListings,
        ),
      ),
    );
  }

  void _showCreditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: Text(
          'İlan Hakkı Gerekli',
          style: TextStyle(color: _primaryText),
        ),
        content: Text(
          'İlan vermek için kredi gereklidir. Kredi satın almak ister misiniz?',
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
              _buyCredit();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accentColor),
            child: Text('Satın Al', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _buyCredit() async {
    try {
      // Simulated purchase - gerçek implementasyon için ödeme sistemi gerekli
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
}

// ============ İLAN OLUŞTURMA SAYFASI ============

class CreateListingScreen extends StatefulWidget {
  final VoidCallback onListingCreated;

  CreateListingScreen({required this.onListingCreated});

  @override
  _CreateListingScreenState createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late Dio _dio;
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
  void initState() {
    super.initState();

    _dio = Dio(BaseOptions(
      baseUrl: UrlConstants.apiBaseUrl,
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
      sendTimeout: Duration(seconds: 30),
    ));
  }

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
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Başlık
            _buildInputField(
              label: 'İlan Başlığı',
              controller: _titleController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Başlık gerekli';
                }
                if (value.trim().length < 5) {
                  return 'Başlık en az 5 karakter olmalı';
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            // Kategori
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: _surfaceColor,
                  style: TextStyle(color: _primaryText),
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

            SizedBox(height: 16),

            // Açıklama
            _buildInputField(
              label: 'Açıklama',
              controller: _descriptionController,
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Açıklama gerekli';
                }
                if (value.trim().length < 10) {
                  return 'Açıklama en az 10 karakter olmalı';
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            // Fiyat
            _buildInputField(
              label: 'Fiyat (₺)',
              controller: _priceController,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Fiyat gerekli';
                }
                final price = double.tryParse(value.trim());
                if (price == null || price <= 0) {
                  return 'Geçerli bir fiyat girin';
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            // Telefon
            _buildInputField(
              label: 'Telefon Numarası',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Telefon numarası gerekli';
                }
                if (value.trim().length < 10) {
                  return 'Geçerli bir telefon numarası girin';
                }
                return null;
              },
            ),

            SizedBox(height: 24),

            // Resim seçimi
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Resimler (${_selectedImages.length}/5)',
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _selectedImages.length < 5 ? _pickImages : null,
                        icon: Icon(Icons.add_photo_alternate),
                        label: Text('Resim Ekle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                        ),
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
                        itemBuilder: (context, index) {
                          return Container(
                            margin: EdgeInsets.only(right: 8),
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
                ],
              ),
            ),

            SizedBox(height: 32),

            // İlan Oluştur Butonu
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
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
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: _primaryText),
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: _surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _accentColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _errorColor),
            ),
            hintStyle: TextStyle(color: _tertiaryText),
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

    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage(
        imageQuality: 70, // Resim kalitesini düşür (dosya boyutunu azaltır)
        maxWidth: 1920,   // Maksimum genişlik
        maxHeight: 1920,  // Maksimum yükseklik
      );

      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        List<File> newImages = [];

        for (final pickedFile in pickedFiles) {
          if (_selectedImages.length + newImages.length >= 5) {
            _showMessage('Maksimum 5 resim seçilebilir');
            break;
          }

          final file = File(pickedFile.path);

          // Dosya boyutu kontrolü (5MB)
          final fileSize = await file.length();
          if (fileSize > 5 * 1024 * 1024) {
            _showMessage('${pickedFile.name} çok büyük (maksimum 5MB)');
            continue;
          }

          // Dosya formatı kontrolü - TÜM RESIM FORMATLARI DESTEKLENİYOR
          final extension = pickedFile.path.split('.').last.toLowerCase();
          final supportedFormats = [
            'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
            'tiff', 'tif', 'svg', 'ico', 'heic', 'heif'
          ];

          if (!supportedFormats.contains(extension)) {
            _showMessage('${pickedFile.name} desteklenmeyen format. Desteklenen: ${supportedFormats.join(', ')}');
            continue;
          }

          newImages.add(file);
          print('✅ Resim seçildi: ${pickedFile.name} (${fileSize} bytes)');
        }

        if (newImages.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(newImages);
          });
          _showMessage('${newImages.length} resim eklendi');
        }
      }
    } catch (e) {
      print('❌ Resim seçme hatası: $e');
      _showMessage('Resim seçerken hata oluştu: $e');
    }
  }
  String _getImageContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'tiff':
      case 'tif':
        return 'image/tiff';
      case 'svg':
        return 'image/svg+xml';
      case 'ico':
        return 'image/x-icon';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg'; // Default olarak JPEG
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
      print('🚀 İlan oluşturma başlıyor...');

      // SharedPreferences'dan auth token al
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        _showMessage('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.');
        return;
      }

      print('🔑 Auth token bulundu');

      // ✅ DÜZELTİLMİŞ: FormData oluşturma
      FormData formData = FormData();

      // Text alanlarını ekle
      formData.fields.addAll([
        MapEntry('title', _titleController.text.trim()),
        MapEntry('description', _descriptionController.text.trim()),
        MapEntry('category', _selectedCategory),
        MapEntry('price', _priceController.text.trim()),
        MapEntry('phoneNumber', _phoneController.text.trim()),
      ]);

      print('📋 Form verileri eklendi: ${formData.fields.length} alan');

      // ✅ DÜZELTİLMİŞ: Resimleri ekle
      if (_selectedImages.isNotEmpty) {
        for (int i = 0; i < _selectedImages.length; i++) {
          String fileName = _selectedImages[i].path.split('/').last;

          // Dosya var mı kontrol et
          if (!await _selectedImages[i].exists()) {
            throw Exception('Resim dosyası bulunamadı: $fileName');
          }

          print('📸 Resim ekleniyor: $fileName (${await _selectedImages[i].length()} bytes)');

          // Dosya uzantısına göre content type belirle
          String contentType = _getImageContentType(fileName);

          formData.files.add(MapEntry(
            'images', // Backend'de beklenen field name
            await MultipartFile.fromFile(
              _selectedImages[i].path,
              filename: fileName,
              contentType: DioMediaType.parse(contentType), // Dio'nun MediaType'ını kullan
            ),
          ));
        }
        print('✅ ${_selectedImages.length} resim FormData\'ya eklendi');
      } else {
        print('⚠️ Hiç resim seçilmedi');
      }

      // ✅ DÜZELTİLMİŞ: Dio options
      final options = Options(
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'multipart/form-data',
          'Accept': 'application/json',
        },
        sendTimeout: Duration(seconds: 60), // 60 saniye timeout
        receiveTimeout: Duration(seconds: 60),
      );

      print('🌐 API isteği gönderiliyor...');
      print('📍 URL: ${UrlConstants.apiBaseUrl}/api/store/listings');

      // API çağrısı yap
      final response = await _dio.post(
        '/api/store/listings',
        data: formData,
        options: options,
      );

      print('📊 Response alındı: ${response.statusCode}');
      print('📄 Response data: ${response.data}');

      if (response.statusCode == 201) {
        final responseData = response.data;

        if (responseData is Map<String, dynamic> && responseData['success'] == true) {
          _showMessage('İlan başarıyla oluşturuldu!');
          widget.onListingCreated(); // Sayfa yenilemesi için
          Navigator.pop(context);
        } else {
          _showMessage(responseData['message'] ?? 'İlan oluşturulamadı');
        }
      } else {
        _showMessage('Sunucu hatası: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ İlan oluşturma hatası: $e');

      String errorMessage = 'İlan oluşturulurken hata oluştu';

      if (e is DioException) {
        print('🔍 DioException detayları:');
        print('  Type: ${e.type}');
        print('  Message: ${e.message}');
        print('  Response: ${e.response?.data}');

        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            errorMessage = 'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.';
            break;
          case DioExceptionType.badResponse:
            if (e.response?.statusCode == 400) {
              // Backend'den gelen spesifik hata mesajı
              final responseData = e.response?.data;
              if (responseData is Map<String, dynamic>) {
                errorMessage = responseData['message'] ?? 'Geçersiz veri gönderildi';
              } else {
                errorMessage = 'Dosya upload hatası. Dosya boyutunu ve formatını kontrol edin.';
              }
            } else if (e.response?.statusCode == 401) {
              errorMessage = 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.';
            } else if (e.response?.statusCode == 403) {
              errorMessage = 'İlan hakkınız bulunmuyor. Lütfen ilan hakkı satın alın.';
            } else {
              errorMessage = 'Sunucu hatası (${e.response?.statusCode})';
            }
            break;
          case DioExceptionType.connectionError:
            errorMessage = 'İnternet bağlantınızı kontrol edin';
            break;
          default:
            errorMessage = 'Bilinmeyen hata oluştu';
        }
      } else {
        errorMessage = 'Beklenmeyen hata: $e';
      }

      _showMessage(errorMessage);

    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ============ İLAN DETAY SAYFASI ============

class ListingDetailScreen extends StatelessWidget {
  final dynamic listing;

  ListingDetailScreen({required this.listing});

  @override
  Widget build(BuildContext context) {
    final Color _backgroundColor = Color(0xFF0A0A0B);
    final Color _surfaceColor = Color(0xFF1A1A1C);
    final Color _cardColor = Color(0xFF1E1E21);
    final Color _primaryText = Color(0xFFFFFFFF);
    final Color _secondaryText = Color(0xFFB3B3B3);
    final Color _tertiaryText = Color(0xFF666666);
    final Color _accentColor = Color(0xFF3B82F6);
    final Color _borderColor = Color(0xFF2A2A2E);
    final Color _successColor = Color(0xFF10B981);

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
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: _primaryText),
            onPressed: () {
              // Paylaşma özelliği eklenebilir
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resim alanı
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: _surfaceColor,
              ),
              child: Center(
                child: Icon(
                  Icons.image,
                  size: 64,
                  color: _tertiaryText,
                ),
              ),
            ),

            // İlan bilgileri
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık ve fiyat
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          listing['title'] ?? 'Başlık Yok',
                          style: TextStyle(
                            color: _primaryText,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _accentColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${listing['price'] ?? 0} ₺',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Kategori ve tarih
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Text(
                          listing['category'] ?? 'Kategori',
                          style: TextStyle(
                            color: _secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Bugün',
                        style: TextStyle(
                          color: _tertiaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Açıklama
                  Text(
                    'Açıklama',
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Text(
                      listing['description'] ?? 'Açıklama yok',
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // İletişim bilgileri
                  Text(
                    'İletişim',
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone, color: _accentColor),
                        SizedBox(width: 12),
                        Text(
                          listing['phoneNumber'] ?? 'Telefon bilgisi yok',
                          style: TextStyle(
                            color: _primaryText,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surfaceColor,
          border: Border(top: BorderSide(color: _borderColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Telefon arama özelliği eklenebilir
                },
                icon: Icon(Icons.phone, color: Colors.white),
                label: Text(
                  'Ara',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _successColor,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Mesaj gönderme özelliği eklenebilir
                },
                icon: Icon(Icons.message, color: Colors.white),
                label: Text(
                  'Mesaj',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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