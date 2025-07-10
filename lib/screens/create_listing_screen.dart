// lib/screens/create_listing_screen.dart - GÜNCELLENMİŞ - Turkey Cities Helper ile

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../url_constants.dart';
import '../helpers/turkey_cities_helper.dart';
import 'purchase_rights_screen.dart';

class CreateListingScreen extends StatefulWidget {
  final VoidCallback onListingCreated;

  CreateListingScreen({required this.onListingCreated});

  @override
  _CreateListingScreenState createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dio = Dio();
  final _picker = ImagePicker();

  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Form state
  String _selectedCategory = 'ses-kartlari'; // Slug olarak başlat
  String _selectedProvince = '';
  String _selectedDistrict = '';
  List<File> _selectedImages = [];
  bool _isLoading = false;
  bool _isCheckingRights = true;
  int _availableRights = 0;

  // Kategori mappings - Slug ve display name
  final Map<String, String> _categoryMappings = {
    'ses-kartlari': 'Ses Kartları',
    'monitorler': 'Monitörler',
    'midi-klavyeler': 'Midi Klavyeler',
    'kayit-setleri': 'Kayıt Setleri',
    'produksiyon-bilgisayarlari': 'Prodüksiyon Bilgisayarları',
    'dj-ekipmanlari': 'DJ Ekipmanları',
    'produksiyon-kontrol-cihazlari': 'Prodüksiyon Kontrol Cihazları',
    'gaming-podcast-ekipmanlari': 'Gaming ve Podcast Ekipmanları',
    'mikrofonlar': 'Mikrofonlar',
    'kulakliklar': 'Kulaklıklar',
    'studyo-dj-ekipmanlari': 'Stüdyo/DJ Ekipmanları',
    'kablolar': 'Kablolar',
    'arabirimler': 'Arabirimler',
    'kayit-cihazlari': 'Kayıt Cihazları',
    'pre-amfiler-efektler': 'Pre-Amfiler/Efektler',
    'yazilimlar': 'Yazılımlar',
  };

  // Helper methods for categories
  List<String> get _categoryDisplayNames => _categoryMappings.values.toList();

  List<String> get _categorySlugs => _categoryMappings.keys.toList();

  String _getSlugFromDisplayName(String displayName) {
    return _categoryMappings.entries
        .firstWhere((entry) => entry.value == displayName,
        orElse: () => MapEntry('ses-kartlari', 'Ses Kartları'))
        .key;
  }

  String _getDisplayNameFromSlug(String slug) {
    return _categoryMappings[slug] ?? 'Ses Kartları';
  }

  // Turkey Cities Helper kullanımı
  List<String> get _availableProvinces => TurkeyCitiesHelper.allProvinces;

  List<String> get _availableDistricts =>
      _selectedProvince.isEmpty ? [] : TurkeyCitiesHelper.getDistricts(
          _selectedProvince);

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
    _checkListingRights();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingRights) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_blueColor),
              ),
              SizedBox(height: 16),
              Text(
                'İlan hakları kontrol ediliyor...',
                style: TextStyle(color: _secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('İlan Oluştur', style: TextStyle(color: _primaryText)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryText),
        actions: [
          // İlan hakkı göstergesi
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _availableRights > 0
                  ? _greenColor.withOpacity(0.1)
                  : _errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _availableRights > 0
                    ? _greenColor.withOpacity(0.3)
                    : _errorColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    Icons.account_balance_wallet,
                    color: _availableRights > 0 ? _greenColor : _errorColor,
                    size: 16
                ),
                SizedBox(width: 6),
                Text(
                  '$_availableRights hak',
                  style: TextStyle(
                    color: _availableRights > 0 ? _greenColor : _errorColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            physics: ClampingScrollPhysics(),
            child: Column(
              children: [
                _buildRightsCard(),
                SizedBox(height: 16),
                _buildBasicInfoSection(),
                SizedBox(height: 16),
                _buildLocationSection(),
                SizedBox(height: 16),
                _buildImagesSection(),
                SizedBox(height: 16),
                _buildContactSection(),
                SizedBox(height: 24),
                _buildSubmitButton(),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightsCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: _availableRights > 0 ? _greenColor : _orangeColor,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _availableRights > 0
                      ? 'İlan Hakkınız Mevcut'
                      : 'İlan Hakkı Gerekli',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _availableRights > 0
                      ? 'Kalan hakkınız: $_availableRights'
                      : 'İlan verebilmek için hak satın almalısınız',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (_availableRights == 0) ...[
            TextButton(
              onPressed: _goToPurchaseRights,
              child: Text(
                'Satın Al',
                style: TextStyle(color: _greenColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          // Başlık
          _buildTextFormField(
            controller: _titleController,
            label: 'İlan Başlığı',
            hint: 'Ürününüzün başlığını yazın',
            maxLength: 200,
            validator: (value) {
              if (value == null || value
                  .trim()
                  .isEmpty) {
                return 'Başlık gereklidir';
              }
              if (value
                  .trim()
                  .length < 5) {
                return 'Başlık en az 5 karakter olmalıdır';
              }
              return null;
            },
          ),
          SizedBox(height: 16),

          // Kategori
          _buildCategoryDropdown(),
          SizedBox(height: 16),

          // Fiyat
          _buildTextFormField(
            controller: _priceController,
            label: 'Fiyat (TL)',
            hint: '0',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value
                  .trim()
                  .isEmpty) {
                return 'Fiyat gereklidir';
              }
              final price = double.tryParse(value.trim());
              if (price == null || price < 0) {
                return 'Geçerli bir fiyat girin';
              }
              return null;
            },
          ),
          SizedBox(height: 16),

          // Açıklama
          _buildTextFormField(
            controller: _descriptionController,
            label: 'Açıklama',
            hint: 'Ürününüzü detaylı olarak anlatın',
            maxLines: 5,
            maxLength: 2000,
            validator: (value) {
              if (value == null || value
                  .trim()
                  .isEmpty) {
                return 'Açıklama gereklidir';
              }
              if (value
                  .trim()
                  .length < 20) {
                return 'Açıklama en az 20 karakter olmalıdır';
              }
              return null;
            },
          ),
        ],
      ),
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
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(
            // Dropdown hint text color fix
            inputDecorationTheme: InputDecorationTheme(
              hintStyle: TextStyle(color: _primaryText.withOpacity(0.7)),
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              hintText: 'Kategori seçin',
              hintStyle: TextStyle(color: _primaryText.withOpacity(0.7)),
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
                borderSide: BorderSide(color: _blueColor),
              ),
              filled: true,
              fillColor: _surfaceColor,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
            dropdownColor: _cardColor,
            style: TextStyle(color: _primaryText),
            menuMaxHeight: MediaQuery
                .of(context)
                .size
                .height * 0.3,
            icon: Icon(Icons.keyboard_arrow_down, color: _primaryText),
            items: _categorySlugs.map((slug) {
              final displayName = _getDisplayNameFromSlug(slug);
              return DropdownMenuItem(
                value: slug,
                child: Text(
                  displayName,
                  style: TextStyle(fontSize: 14, color: _primaryText),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Kategori seçimi gereklidir';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          // İl Dropdown
          _buildDropdownField(
            label: 'İl',
            value: _selectedProvince.isEmpty ? null : _selectedProvince,
            items: _availableProvinces,
            hint: 'İl seçin',
            onChanged: (value) {
              setState(() {
                _selectedProvince = value!;
                _selectedDistrict = '';
              });
            },
          ),
          SizedBox(height: 16),

          // İlçe Dropdown
          _buildDropdownField(
            label: 'İlçe',
            value: _selectedDistrict.isEmpty ? null : _selectedDistrict,
            items: _availableDistricts,
            hint: 'İlçe seçin',
            onChanged: _selectedProvince.isEmpty
                ? null
                : (value) => setState(() => _selectedDistrict = value!),
          ),
          SizedBox(height: 16),

          // Tam Adres
          _buildTextFormField(
            controller: _addressController,
            label: 'Tam Adres (Opsiyonel)',
            hint: 'Mahalle, sokak, no...',
            maxLines: 3,
            maxLength: 300,
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Görseller (${_selectedImages.length}/5)',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _pickImages,
                icon: Icon(Icons.add_photo_alternate, color: _primaryText),
                style: IconButton.styleFrom(
                  backgroundColor: Color(0xFF6B7280), // Gri ton
                  shape: CircleBorder(),
                ),
              ),
            ],
          ),

          if (_selectedImages.isNotEmpty) ...[
            SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImages[index],
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
                          decoration: BoxDecoration(
                            color: _errorColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            color: _primaryText,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ] else
            ...[
              SizedBox(height: 16),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _borderColor, style: BorderStyle.solid),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, color: _tertiaryText, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Fotoğraf ekleyin',
                        style: TextStyle(color: _tertiaryText),
                      ),
                    ],
                  ),
                ),
              ),
            ],
        ],
      ),
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
      child: _buildTextFormField(
        controller: _phoneController,
        label: 'Telefon Numarası',
        hint: '05xx xxx xx xx',
        keyboardType: TextInputType.phone,
        validator: (value) {
          if (value == null || value
              .trim()
              .isEmpty) {
            return 'Telefon numarası gereklidir';
          }
          if (value
              .trim()
              .length < 10) {
            return 'Geçerli bir telefon numarası girin';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (_isLoading || _availableRights <= 0)
            ? null
            : _submitListing,
        style: ElevatedButton.styleFrom(
          backgroundColor: _availableRights > 0 ? _greenColor : _accentColor,
          foregroundColor: _primaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_primaryText),
              ),
            ),
            SizedBox(width: 12),
            Text('İlan Oluşturuluyor...'),
          ],
        )
            : Text(
          _availableRights > 0 ? 'İlanı Yayınla' : 'İlan Hakkı Gerekli',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: TextStyle(color: _primaryText),
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _tertiaryText),
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
              borderSide: BorderSide(color: _blueColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _errorColor),
            ),
            filled: true,
            fillColor: _surfaceColor,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required String hint,
    required void Function(String?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(
            // Dropdown hint text color fix
            inputDecorationTheme: InputDecorationTheme(
              hintStyle: TextStyle(color: _primaryText.withOpacity(0.7)),
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _primaryText.withOpacity(0.7)),
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
                borderSide: BorderSide(color: _blueColor),
              ),
              filled: true,
              fillColor: _surfaceColor,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
            dropdownColor: _cardColor,
            style: TextStyle(color: _primaryText),
            menuMaxHeight: MediaQuery
                .of(context)
                .size
                .height * 0.25,
            icon: Icon(Icons.keyboard_arrow_down, color: _primaryText),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(fontSize: 14, color: _primaryText),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '$label seçimi gereklidir';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Future<void> _checkListingRights() async {
    setState(() => _isCheckingRights = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        print('⚠️ Auth token bulunamadı');
        setState(() {
          _availableRights = 0;
          _isCheckingRights = false;
        });
        _showMessage('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
        return;
      }

      print('🔍 İlan hakları kontrol ediliyor...');

      final response = await _dio.get(
        '${UrlConstants.apiBaseUrl}/api/store/rights',
        options: Options(
          headers: {'Authorization': 'Bearer $authToken'},
          receiveTimeout: Duration(seconds: 10),
        ),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response data: ${response.data}');

      if (response.statusCode == 200) {
        if (response.data != null && response.data['success'] == true) {
          final rights = response.data['rights'];
          setState(() {
            _availableRights =
            rights != null ? (rights['availableRights'] ?? 0) : 0;
            _isCheckingRights = false;
          });
          print('✅ İlan hakları başarıyla yüklendi: $_availableRights');
        } else {
          throw Exception('API yanıtı başarısız: ${response.data?['message'] ??
              'Bilinmeyen hata'}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Rights check error: $e');
      setState(() {
        _availableRights = 0;
        _isCheckingRights = false;
      });

      String errorMessage = 'İlan hakları kontrol edilirken hata oluştu.';
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        errorMessage = 'İnternet bağlantınızı kontrol edin.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Oturum süresi dolmuş. Lütfen tekrar giriş yapın.';
      }

      _showMessage(errorMessage);
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    // Widget'ın hala aktif olup olmadığını kontrol et
    if (!mounted || !context.mounted) return;

    try {
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
          duration: Duration(seconds: 3), // Kısa süre
        ),
      );
    } catch (e) {
      // Eğer ScaffoldMessenger bulunamazsa sessizce hata ver
      print('⚠️ Cannot show snackbar: $e');
    }
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      _showMessage('Maksimum 5 fotoğraf ekleyebilirsiniz.');
      return;
    }

    final remainingSlots = 5 - _selectedImages.length;
    final List<XFile>? images = await _picker.pickMultiImage();

    if (images != null) {
      final imagesToAdd = images.take(remainingSlots).toList();

      setState(() {
        _selectedImages.addAll(imagesToAdd.map((xfile) => File(xfile.path)));
      });

      if (images.length > remainingSlots) {
        _showMessage('Sadece $remainingSlots fotoğraf daha ekleyebilirsiniz.');
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_availableRights <= 0) {
      _showMessage('İlan verebilmek için önce hak satın almanız gerekiyor.');
      return;
    }

    if (_selectedProvince.isEmpty) {
      _showMessage('Lütfen il seçin.');
      return;
    }

    if (_selectedDistrict.isEmpty) {
      _showMessage('Lütfen ilçe seçin.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        throw Exception('Oturum bulunamadı');
      }

      // FormData oluştur
      final formData = FormData.fromMap({
        'title': _titleController.text.trim(),
        'category': _selectedCategory, // Slug gönder
        'price': double.parse(_priceController.text.trim()),
        'description': _descriptionController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'province': _selectedProvince,
        'district': _selectedDistrict,
        'fullAddress': _addressController.text.trim(),
      });

      // Resimleri ekle
      for (int i = 0; i < _selectedImages.length; i++) {
        formData.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(
              _selectedImages[i].path,
              filename: 'listing_image_$i.jpg',
            ),
          ),
        );
      }

      print('🚀 Submitting to: ${UrlConstants
          .apiBaseUrl}/api/store/listings'); // Debug için
      print('📦 FormData: ${formData.fields}'); // Debug için

      final response = await _dio.post(
        '${UrlConstants.apiBaseUrl}/api/store/listings',
        // /create yerine /listings
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response data: ${response.data}');

      if (response.statusCode == 201 && response.data['success']) {
        if (mounted) { // Widget hala aktif mi kontrol et
          _showMessage('İlan başarıyla oluşturuldu!', isError: false);
          widget.onListingCreated(); // Parent widget'ı bilgilendir
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(response.data['message'] ?? 'İlan oluşturulamadı');
      }
    } catch (e) {
      print('❌ Create listing error: $e');
      if (mounted) { // Widget hala aktif mi kontrol et
        if (e.toString().contains('404')) {
          _showMessage(
              'API endpoint bulunamadı. Lütfen geliştirici ile iletişime geçin.');
        } else if (e.toString().contains('401')) {
          _showMessage('Oturum süresi dolmuş. Lütfen tekrar giriş yapın.');
        } else if (e.toString().contains('403')) {
          _showMessage('Bu işlem için yetkiniz yok.');
        } else {
          _showMessage('İlan oluşturulurken hata oluştu: ${e.toString()}');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _goToPurchaseRights() async {
    Future<void> _goToPurchaseRights() async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PurchaseRightsScreen(
                onPurchaseCompleted: () {
                  _checkListingRights(); // Hakları yeniden kontrol et
                },
              ),
        ),
      );

      // Eğer satın alma başarılıysa hakları yeniden kontrol et
      if (result == true) {
        await _checkListingRights();
      }
    }
  }
}