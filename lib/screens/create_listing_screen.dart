// lib/screens/create_listing_screen.dart - İlan Oluşturma Sayfası İl/İlçe ile

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../url_constants.dart';

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
  final Color _errorColor = Color(0xFFEF4444);

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
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Temel Bilgiler'),
                    SizedBox(height: 16),
                    _buildBasicInfoSection(),
                    SizedBox(height: 24),

                    _buildSectionTitle('Konum Bilgileri'),
                    SizedBox(height: 16),
                    _buildLocationSection(),
                    SizedBox(height: 24),

                    _buildSectionTitle('Görseller'),
                    SizedBox(height: 16),
                    _buildImageSection(),
                    SizedBox(height: 24),

                    _buildSectionTitle('İletişim'),
                    SizedBox(height: 16),
                    _buildContactSection(),
                    SizedBox(height: 32),

                    _buildCreateButton(),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _primaryText,
        fontSize: 20,
        fontWeight: FontWeight.bold,
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
                  label: 'Fiyat (₺)',
                  hint: '0',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
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
            maxLines: 5,
            maxLength: 2000,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Açıklama gereklidir';
              }
              if (value.trim().length < 20) {
                return 'Açıklama en az 20 karakter olmalıdır';
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
        children: [
          // İl ve İlçe
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'İl',
                  value: _selectedProvince.isEmpty ? null : _selectedProvince,
                  hint: 'İl seçin',
                  items: _availableProvinces,
                  onChanged: (value) {
                    setState(() {
                      _selectedProvince = value!;
                      _selectedDistrict = ''; // İl değiştiğinde ilçeyi sıfırla
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'İl seçimi gereklidir';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _selectedProvince.isEmpty,
                  child: _buildDropdownField(
                    label: 'İlçe',
                    value: _selectedDistrict.isEmpty ? null : _selectedDistrict,
                    hint: 'İlçe seçin',
                    items: _availableDistricts,
                    onChanged: (value) {
                      setState(() {
                        _selectedDistrict = value ?? '';
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'İlçe seçimi gereklidir';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Detaylı adres (opsiyonel)
          _buildTextFormField(
            controller: _addressController,
            label: 'Detaylı Adres (Opsiyonel)',
            hint: 'Mahalle, sokak, bina no vb.',
            maxLines: 2,
            maxLength: 200,
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          if (_selectedImages.isEmpty) ...[
            // Görsel yok durumu
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor, style: BorderStyle.solid),
              ),
              child: InkWell(
                onTap: _pickImages,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 32, color: _tertiaryText),
                      SizedBox(height: 8),
                      Text(
                        'Görsel Ekle',
                        style: TextStyle(color: _tertiaryText, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // Seçilen görseller
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _selectedImages.length + 1,
              itemBuilder: (context, index) {
                if (index == _selectedImages.length) {
                  // Yeni görsel ekleme butonu
                  return Container(
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: InkWell(
                      onTap: _pickImages,
                      child: Icon(Icons.add, color: _tertiaryText, size: 24),
                    ),
                  );
                }

                // Seçilen görsel
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImages[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                    // Silme butonu
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _errorColor,
                            shape: BoxShape.circle,
                          ),
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
          ],
          SizedBox(height: 12),
          Text(
            'En fazla 5 görsel ekleyebilirsiniz',
            style: TextStyle(color: _tertiaryText, fontSize: 12),
          ),
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
        hint: '0500 000 00 00',
        keyboardType: TextInputType.phone,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Telefon numarası gereklidir';
          }
          // Basit telefon numarası validasyonu
          final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
          if (cleaned.length < 10) {
            return 'Geçerli bir telefon numarası girin';
          }
          return null;
        },
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
            fontSize: 14,
            fontWeight: FontWeight.w500,
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
              borderSide: BorderSide(color: _accentColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _errorColor),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    String? value,
    String? hint,
    required List<String> items,
    required Function(String?) onChanged,
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
        DropdownButtonFormField<String>(
          value: value,
          hint: hint != null ? Text(hint, style: TextStyle(color: _tertiaryText)) : null,
          validator: validator,
          dropdownColor: _cardColor,
          style: TextStyle(color: _primaryText),
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
              borderSide: BorderSide(color: _accentColor),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, style: TextStyle(color: _primaryText)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createListing,
        style: ElevatedButton.styleFrom(
          backgroundColor: _greenColor,
          disabledBackgroundColor: _accentColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        print(authToken);
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
        _showMessage('İlan başarıyla oluşturuldu!', isSuccess: true);
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