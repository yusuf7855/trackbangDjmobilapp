// lib/screens/create_listing_screen.dart - GÜNCELLENMİŞ - İlan Hakkı Kontrolü ile

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../url_constants.dart';
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
  String _selectedCategory = 'Elektronik';
  String _selectedProvince = '';
  String _selectedDistrict = '';
  List<File> _selectedImages = [];
  bool _isLoading = false;
  bool _isCheckingRights = true;
  int _availableRights = 0;

  // Dropdown options
  final List<String> _categories = [
    'Elektronik', 'Giyim', 'Ev & Yaşam', 'Spor',
    'Kitap', 'Oyun', 'Müzik Aleti', 'Diğer'
  ];

  final Map<String, List<String>> _provincesAndDistricts = {
    'İstanbul': ['Ataşehir', 'Kadıköy', 'Beşiktaş', 'Şişli', 'Bakırköy', 'Beyoğlu', 'Fatih', 'Üsküdar'],
    'Ankara': ['Çankaya', 'Keçiören', 'Yenimahalle', 'Mamak', 'Sincan', 'Etimesgut', 'Altındağ'],
    'İzmir': ['Konak', 'Bornova', 'Karşıyaka', 'Buca', 'Bayraklı', 'Gaziemir', 'Balçova'],
    'Bursa': ['Osmangazi', 'Nilüfer', 'Yıldırım', 'Gemlik', 'İnegöl', 'Mudanya'],
    'Antalya': ['Muratpaşa', 'Kepez', 'Konyaaltı', 'Aksu', 'Döşemealtı', 'Manavgat', 'Alanya'],
    'Adana': ['Seyhan', 'Yüreğir', 'Çukurova', 'Sarıçam', 'Karaisalı'],
    'Konya': ['Meram', 'Karatay', 'Selçuklu', 'Ereğli', 'Akşehir'],
    'Samsun': ['İlkadım', 'Atakum', 'Canik', 'Tekkeköy', 'Bafra', 'Çarşamba', 'Vezirköprü'],
  };

  List<String> get _availableProvinces => _provincesAndDistricts.keys.toList();
  List<String> get _availableDistricts =>
      _selectedProvince.isEmpty ? [] : _provincesAndDistricts[_selectedProvince] ?? [];

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
    _checkUserRights();
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
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('İlan Oluştur', style: TextStyle(color: _primaryText)),
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
                  '$_availableRights',
                  style: TextStyle(
                    color: _availableRights > 0 ? _greenColor : _errorColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isCheckingRights
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_blueColor),
        ),
      )
          : _availableRights <= 0
          ? _buildNoRightsView()
          : _buildCreateListingForm(),
    );
  }

  Widget _buildNoRightsView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 80,
              color: _errorColor,
            ),
            SizedBox(height: 24),
            Text(
              'İlan Hakkınız Bulunmuyor',
              style: TextStyle(
                color: _primaryText,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'İlan verebilmek için önce ilan hakkı satın almanız gerekiyor.',
              style: TextStyle(
                color: _secondaryText,
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goToPurchaseRights,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blueColor,
                  foregroundColor: _primaryText,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'İlan Hakkı Satın Al',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Geri Dön',
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateListingForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRightsInfoCard(),
            SizedBox(height: 20),
            _buildBasicInfoSection(),
            SizedBox(height: 20),
            _buildLocationSection(),
            SizedBox(height: 20),
            _buildImagesSection(),
            SizedBox(height: 32),
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRightsInfoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _greenColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _greenColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: _greenColor, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İlan hakkınız mevcut',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Kalan hak: $_availableRights ilan',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _goToPurchaseRights,
            child: Text(
              'Daha Fazla Al',
              style: TextStyle(color: _greenColor),
            ),
          ),
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
              if (value == null || value.trim().isEmpty) {
                return 'Başlık gereklidir';
              }
              if (value.trim().length < 5) {
                return 'Başlık en az 5 karakter olmalıdır';
              }
              return null;
            },
          ),
          SizedBox(height: 16),

          // Kategori ve Fiyat
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Kategori',
                  value: _selectedCategory,
                  items: _categories,
                  onChanged: (value) => setState(() => _selectedCategory = value!),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildTextFormField(
                  controller: _priceController,
                  label: 'Fiyat (EUR)',
                  hint: '0.00',
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Fiyat gereklidir';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price < 0) {
                      return 'Geçerli bir fiyat girin';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Açıklama
          _buildTextFormField(
            controller: _descriptionController,
            label: 'Açıklama',
            hint: 'Ürününüz hakkında detaylı bilgi verin',
            maxLines: 4,
            maxLength: 1000,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Açıklama gereklidir';
              }
              if (value.trim().length < 10) {
                return 'Açıklama en az 10 karakter olmalıdır';
              }
              return null;
            },
          ),
          SizedBox(height: 16),

          // Telefon
          _buildTextFormField(
            controller: _phoneController,
            label: 'Telefon Numarası',
            hint: '+90 5XX XXX XX XX',
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Telefon numarası gereklidir';
              }
              if (value.trim().length < 10) {
                return 'Geçerli bir telefon numarası girin';
              }
              return null;
            },
          ),
        ],
      ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Konum Bilgileri',
            style: TextStyle(
              color: _primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          // İl ve İlçe
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
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
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  label: 'İlçe',
                  value: _selectedDistrict.isEmpty ? null : _selectedDistrict,
                  items: _availableDistricts,
                  hint: 'İlçe seçin',
                  onChanged: _selectedProvince.isEmpty
                      ? null
                      : (value) => setState(() => _selectedDistrict = value!),
                ),
              ),
            ],
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
                icon: Icon(Icons.add_photo_alternate, color: _blueColor),
                style: IconButton.styleFrom(
                  backgroundColor: _blueColor.withOpacity(0.1),
                  shape: CircleBorder(),
                ),
              ),
            ],
          ),

          if (_selectedImages.isEmpty) ...[
            SizedBox(height: 16),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 48, color: _tertiaryText),
                  SizedBox(height: 8),
                  Text(
                    'Görsel eklemek için + butonuna basın',
                    style: TextStyle(color: _tertiaryText),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
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
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: _primaryText,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    int? maxLength,
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
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(color: _primaryText),
          decoration: InputDecoration(
            hintText: hint,
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
              borderSide: BorderSide(color: _blueColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _errorColor),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            counterStyle: TextStyle(color: _tertiaryText),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required List<String> items,
    String? value,
    String? hint,
    ValueChanged<String?>? onChanged,
  }) {

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
        DropdownButtonFormField<String>(
          value: value,
          hint: Text(
            hint ?? 'Seçin',
            style: TextStyle(color: _tertiaryText),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(color: _primaryText),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          style: TextStyle(color: _primaryText),
          dropdownColor: _surfaceColor,
          decoration: InputDecoration(
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
              borderSide: BorderSide(color: _blueColor),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '$label seçimi gereklidir';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createListing,
        style: ElevatedButton.styleFrom(
          backgroundColor: _greenColor,
          foregroundColor: _primaryText,
          padding: EdgeInsets.symmetric(vertical: 16),
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
            color: _primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _checkUserRights() async {
    try {
      setState(() => _isCheckingRights = true);

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        _showMessage('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.');
        Navigator.pop(context);
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
          _availableRights = response.data['rights']['availableRights'] ?? 0;
        });
      } else {
        _showMessage('İlan hakları kontrol edilemedi');
      }
    } catch (e) {
      print('Rights kontrol hatası: $e');
      _showMessage('İlan hakları kontrol edilirken hata oluştu');
    } finally {
      setState(() => _isCheckingRights = false);
    }
  }

  Future<void> _goToPurchaseRights() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseRightsScreen(
          onPurchaseCompleted: () {
            // Satın alma tamamlandığında hakları yeniden kontrol et
            _checkUserRights();
          },
        ),
      ),
    );

    // Eğer satın alma başarılıysa hakları yeniden kontrol et
    if (result == true) {
      _checkUserRights();
    }
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      _showMessage('En fazla 5 görsel ekleyebilirsiniz');
      return;
    }

    try {
      final List<XFile>? images = await _picker.pickMultiImage();
      if (images != null) {
        final remainingSlots = 5 - _selectedImages.length;
        final imagesToAdd = images.take(remainingSlots);

        setState(() {
          _selectedImages.addAll(imagesToAdd.map((image) => File(image.path)));
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

    // Province ve district kontrolü
    if (_selectedProvince.isEmpty || _selectedDistrict.isEmpty) {
      _showMessage('Lütfen il ve ilçe seçin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        _showMessage('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.');
        return;
      }

      FormData formData = FormData.fromMap({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'price': _priceController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'province': _selectedProvince,
        'district': _selectedDistrict,
        'fullAddress': _addressController.text.trim(),
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
        // İlan başarıyla oluşturuldu
        final remainingRights = response.data['remainingRights'] ?? 0;

        setState(() {
          _availableRights = remainingRights;
        });

        _showMessage('İlan başarıyla oluşturuldu!', isSuccess: true);
        widget.onListingCreated();
        Navigator.pop(context);
      } else {
        _showMessage(response.data['message'] ?? 'İlan oluşturulamadı');
      }
    } catch (e) {
      if (e is DioException) {
        final responseData = e.response?.data;

        if (e.response?.statusCode == 403 && responseData?['needToPurchase'] == true) {
          // İlan hakkı yok - satın alma sayfasına yönlendir
          _showMessage('İlan hakkınız bulunmuyor. Lütfen ilan hakkı satın alın.');
          _goToPurchaseRights();
        } else if (e.response?.statusCode == 401) {
          _showMessage('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.');
        } else {
          _showMessage(responseData?['message'] ?? 'İlan oluşturulurken hata oluştu');
        }
      } else {
        _showMessage('İlan oluşturulurken hata oluştu: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message, {bool isSuccess = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: _primaryText),
        ),
        backgroundColor: isSuccess ? _greenColor : _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }
}