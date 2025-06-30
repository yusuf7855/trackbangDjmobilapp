// lib/screens/listing_detail_screen.dart - TAM VE EKSİKSİZ VERSİYON

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../url_constants.dart';

class ListingDetailScreen extends StatefulWidget {
  final dynamic listing;

  ListingDetailScreen({required this.listing});

  @override
  _ListingDetailScreenState createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  PageController _pageController = PageController();
  int _currentImageIndex = 0;
  GoogleMapController? _mapController;
  late CameraPosition _initialCameraPosition;
  Set<Marker> _markers = {};
  MapType _currentMapType = MapType.hybrid; // Karma modda sabit
  final Dio _dio = Dio();

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
  final Color _orangeColor = Color(0xFFF59E0B);
  final Color _errorColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _setupLocationAndMap();
  }

  void _setupLocationAndMap() {
    final location = widget.listing['location'];
    final province = location?['province']?.toString() ?? '';
    final district = location?['district']?.toString() ?? '';

    // Türkiye'deki başlıca şehirlerin koordinatları
    Map<String, LatLng> cityCoordinates = {
      'İstanbul': LatLng(41.0082, 28.9784),
      'Ankara': LatLng(39.9334, 32.8597),
      'İzmir': LatLng(38.4192, 27.1287),
      'Bursa': LatLng(40.1826, 29.0665),
      'Antalya': LatLng(36.8969, 30.7133),
      'Adana': LatLng(37.0000, 35.3213),
      'Konya': LatLng(37.8667, 32.4833),
      'Samsun': LatLng(41.2928, 36.3313),
      'Gaziantep': LatLng(37.0662, 37.3833),
      'Mersin': LatLng(36.8000, 34.6333),
      'Eskişehir': LatLng(39.7767, 30.5206),
      'Diyarbakır': LatLng(37.9144, 40.2306),
      'Kayseri': LatLng(38.7312, 35.4787),
      'Trabzon': LatLng(41.0015, 39.7178),
    };

    // Samsun ilçeleri için özel koordinatlar
    Map<String, LatLng> samsunDistricts = {
      'Atakum': LatLng(41.3151, 36.2348),
      'İlkadım': LatLng(41.2867, 36.3300),
      'Canik': LatLng(41.2667, 36.3500),
      'Tekkeköy': LatLng(41.2167, 36.4500),
      'Bafra': LatLng(41.5667, 35.9000),
      'Çarşamba': LatLng(41.1975, 36.7233),
      'Vezirköprü': LatLng(41.1436, 35.4531),
    };

    // İstanbul ilçeleri için özel koordinatlar
    Map<String, LatLng> istanbulDistricts = {
      'Kadıköy': LatLng(40.9833, 29.0833),
      'Beşiktaş': LatLng(41.0422, 29.0061),
      'Şişli': LatLng(41.0602, 28.9847),
      'Bakırköy': LatLng(40.9833, 28.8667),
      'Beyoğlu': LatLng(41.0361, 28.9778),
      'Fatih': LatLng(41.0186, 28.9497),
      'Üsküdar': LatLng(41.0214, 29.0456),
      'Ataşehir': LatLng(40.9833, 29.1167),
    };

    LatLng defaultPosition;
    String markerTitle = 'Konum';

    // Önce özel ilçe koordinatlarına bak
    if (province.toLowerCase().contains('samsun') && samsunDistricts.containsKey(district)) {
      defaultPosition = samsunDistricts[district]!;
      markerTitle = '$district, $province';
    } else if (province.toLowerCase().contains('istanbul') && istanbulDistricts.containsKey(district)) {
      defaultPosition = istanbulDistricts[district]!;
      markerTitle = '$district, $province';
    }
    // Sonra il koordinatlarına bak
    else if (cityCoordinates.containsKey(province)) {
      defaultPosition = cityCoordinates[province]!;
      markerTitle = '$district, $province';
    }
    // Varsayılan: Türkiye merkez
    else {
      defaultPosition = LatLng(39.9334, 32.8597); // Ankara
      markerTitle = province.isNotEmpty ? '$district, $province' : 'Konum Bilgisi Yok';
    }

    _initialCameraPosition = CameraPosition(
      target: defaultPosition,
      zoom: 13.0,
    );

    _markers.add(
      Marker(
        markerId: MarkerId('listing_location'),
        position: defaultPosition,
        infoWindow: InfoWindow(
          title: markerTitle,
          snippet: 'İlan konumu (yaklaşık)',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.listing['images'] as List?;
    final hasImages = images != null && images.isNotEmpty;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image Gallery
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: _backgroundColor,
            iconTheme: IconThemeData(color: _primaryText),
            flexibleSpace: FlexibleSpaceBar(
              background: hasImages
                  ? _buildImageGallery(images!)
                  : _buildNoImagePlaceholder(),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleAndPrice(),
                  SizedBox(height: 16),
                  _buildCategoryAndDate(),
                  SizedBox(height: 24),
                  _buildDescription(),
                  SizedBox(height: 24),
                  _buildLocationCard(),
                  SizedBox(height: 24),
                  _buildSellerInfo(),
                  SizedBox(height: 24),
                  _buildInfoSection(),
                  SizedBox(height: 32),
                  _buildContactButton(),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(List images) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentImageIndex = index);
          },
          itemCount: images.length,
          itemBuilder: (context, index) {
            final imageUrl = images[index]['url'] ?? '';
            return Container(
              width: double.infinity,
              child: Image.network(
                '${UrlConstants.apiBaseUrl}$imageUrl',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: _surfaceColor,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          color: _tertiaryText,
                          size: 64,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Resim yüklenemedi',
                          style: TextStyle(color: _tertiaryText),
                        ),
                      ],
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: _surfaceColor,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(_blueColor),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Resim yükleniyor...',
                            style: TextStyle(color: _secondaryText),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        // Image indicators
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
                        ? _blueColor
                        : _primaryText.withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
          ),
        // Image counter
        if (images.length > 1)
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${images.length}',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      color: _surfaceColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image,
            color: _tertiaryText,
            size: 80,
          ),
          SizedBox(height: 16),
          Text(
            'Fotoğraf Yok',
            style: TextStyle(
              color: _tertiaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Bu ilan için fotoğraf eklenmemiş',
            style: TextStyle(
              color: _tertiaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleAndPrice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.listing['title']?.toString() ?? 'Başlık Yok',
          style: TextStyle(
            color: _primaryText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Text(
              '${widget.listing['price']?.toString() ?? '0'} EUR',
              style: TextStyle(
                color: _greenColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            if (widget.listing['listingNumber'] != null) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No: ${widget.listing['listingNumber']}',
                  style: TextStyle(
                    color: _accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryAndDate() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _blueColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            widget.listing['category']?.toString() ?? 'Kategori',
            style: TextStyle(
              color: _blueColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: 12),
        Icon(Icons.access_time, color: _tertiaryText, size: 14),
        SizedBox(width: 4),
        Text(
          _formatDate(widget.listing['createdAt']),
          style: TextStyle(
            color: _tertiaryText,
            fontSize: 12,
          ),
        ),
        Spacer(),
        if (widget.listing['viewCount'] != null) ...[
          Icon(Icons.visibility, color: _tertiaryText, size: 14),
          SizedBox(width: 4),
          Text(
            '${widget.listing['viewCount']} görüntülenme',
            style: TextStyle(
              color: _tertiaryText,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDescription() {
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
            children: [
              Icon(Icons.description, color: _blueColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Açıklama',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            widget.listing['description']?.toString() ?? 'Açıklama mevcut değil',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final location = widget.listing['location'];
    if (location == null) return SizedBox.shrink();

    final province = location['province']?.toString() ?? '';
    final district = location['district']?.toString() ?? '';
    final fullAddress = location['fullAddress']?.toString() ?? '';

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
            children: [
              Icon(Icons.location_on, color: _blueColor, size: 24),
              SizedBox(width: 12),
              Text(
                'Konum',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // İl/İlçe bilgisi
          if (province.isNotEmpty && district.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.place, color: _greenColor, size: 16),
                SizedBox(width: 8),
                Text(
                  '$district, $province',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          // Tam adres (varsa)
          if (fullAddress.isNotEmpty) ...[
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.home, color: _accentColor, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fullAddress,
                    style: TextStyle(
                      color: _secondaryText,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: 20),

          // KARMA MODDA SABİT GOOGLE MAPS
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  print('✅ Google Maps karma modda yüklendi');
                },
                initialCameraPosition: _initialCameraPosition,
                markers: _markers,

                // UI Kontrolleri
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
                compassEnabled: false,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: false,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,

                // SABİT KARMA HARITA
                mapType: MapType.hybrid,

                // Tıklama olayı
                onTap: (LatLng position) {
                  print('🎯 Harita tıklandı: ${position.latitude}, ${position.longitude}');
                },
              ),
            ),
          ),

          SizedBox(height: 16),

          // Google Maps'te Aç butonu
          if (province.isNotEmpty && district.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openInMaps(province, district),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blueColor.withOpacity(0.1),
                  foregroundColor: _blueColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _blueColor.withOpacity(0.3)),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(Icons.map, size: 20),
                label: Text(
                  'Google Maps\'te Aç',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSellerInfo() {
    final user = widget.listing['userId'];
    if (user == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: _blueColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Satıcı Bilgileri',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              // Profil resmi
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _borderColor),
                ),
                child: ClipOval(
                  child: _getUserProfileImage(user),
                ),
              ),
              SizedBox(width: 16),
              // Kullanıcı bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['username']?.toString() ?? 'Kullanıcı',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (user['firstName'] != null || user['lastName'] != null)
                      Text(
                        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
                        style: TextStyle(
                          color: _secondaryText,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              // Mesaj butonu
              IconButton(
                onPressed: () => _showContactOptions(),
                icon: Icon(Icons.message, color: _blueColor),
                style: IconButton.styleFrom(
                  backgroundColor: _blueColor.withOpacity(0.1),
                  shape: CircleBorder(),
                ),
              ),
            ],
          ),
        ],
      ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: _blueColor, size: 20),
              SizedBox(width: 8),
              Text(
                'İlan Bilgileri',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow('İlan No', widget.listing['listingNumber']?.toString() ?? 'N/A'),
          Divider(color: _borderColor, height: 24),
          _buildInfoRow('Yayın Tarihi', _formatDateFull(widget.listing['createdAt'])),
          Divider(color: _borderColor, height: 24),
          _buildInfoRow('Görüntülenme', '${widget.listing['viewCount'] ?? 0} kez'),
          if (widget.listing['contactCount'] != null) ...[
            Divider(color: _borderColor, height: 24),
            _buildInfoRow('İletişim', '${widget.listing['contactCount']} kez'),
          ],
          if (widget.listing['expiryDate'] != null) ...[
            Divider(color: _borderColor, height: 24),
            _buildInfoRow('Bitiş Tarihi', _formatDateFull(widget.listing['expiryDate'])),
          ],
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
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: _primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildContactButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showContactOptions,
        style: ElevatedButton.styleFrom(
          backgroundColor: _greenColor,
          foregroundColor: _primaryText,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: Icon(Icons.phone, size: 24),
        label: Text(
          'İletişime Geç',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _getUserProfileImage(dynamic user) {
    final profileImage = user['profileImage'] ?? user['profileImageUrl'];
    if (profileImage != null && profileImage.isNotEmpty) {
      String imageUrl = profileImage;
      if (!imageUrl.startsWith('http') && !imageUrl.startsWith('/')) {
        imageUrl = '/uploads/$imageUrl';
      }

      return Image.network(
        '${UrlConstants.apiBaseUrl}$imageUrl',
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            color: _accentColor.withOpacity(0.3),
            child: Icon(Icons.person, color: _accentColor, size: 30),
          );
        },
      );
    }

    return Container(
      width: 50,
      height: 50,
      color: _accentColor.withOpacity(0.3),
      child: Icon(Icons.person, color: _accentColor, size: 30),
    );
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return '';

    try {
      final date = DateTime.parse(dateString.toString());
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${difference.inDays} gün önce';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} gün önce';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} saat önce';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} dakika önce';
      } else {
        return 'Şimdi';
      }
    } catch (e) {
      return '';
    }
  }

  String _formatDateFull(dynamic dateString) {
    if (dateString == null) return '';

    try {
      final date = DateTime.parse(dateString.toString());
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Future<void> _openInMaps(String province, String district) async {
    try {
      final query = Uri.encodeComponent('$district, $province, Turkey');
      final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$query';

      if (await canLaunch(googleMapsUrl)) {
        await launch(googleMapsUrl);
      } else {
        _showMessage('Haritalar açılamadı');
      }
    } catch (e) {
      print('❌ Maps açma hatası: $e');
      _showMessage('Haritalar açılırken hata oluştu');
    }
  }

  void _showContactOptions() {
    final phoneNumber = widget.listing['phoneNumber']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24),

              // Title
              Text(
                'İletişim Seçenekleri',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 24),

              // Contact options
              if (phoneNumber.isNotEmpty) ...[
                // Telefon araması
                _buildContactOption(
                  icon: Icons.phone,
                  title: 'Telefon Et',
                  subtitle: phoneNumber,
                  color: _greenColor,
                  onTap: () => _makePhoneCall(phoneNumber),
                ),

                SizedBox(height: 12),

                // WhatsApp
                _buildContactOption(
                  icon: Icons.chat,
                  title: 'WhatsApp',
                  subtitle: 'WhatsApp ile mesaj gönder',
                  color: _greenColor,
                  onTap: () => _openWhatsApp(phoneNumber),
                ),

                SizedBox(height: 12),

                // SMS
                _buildContactOption(
                  icon: Icons.sms,
                  title: 'SMS Gönder',
                  subtitle: 'Kısa mesaj gönder',
                  color: _blueColor,
                  onTap: () => _sendSMS(phoneNumber),
                ),
              ] else ...[
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _errorColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: _errorColor),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bu ilan için iletişim bilgisi mevcut değil',
                          style: TextStyle(color: _errorColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 24),

              // Cancel button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'İptal',
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _primaryText,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final url = 'tel:$phoneNumber';
      if (await canLaunch(url)) {
        await launch(url);
        Navigator.pop(context);
        _incrementContactCount();
      } else {
        _showMessage('Telefon araması yapılamadı');
      }
    } catch (e) {
      _showMessage('Telefon araması yapılamadı');
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    try {
      // Telefon numarasını temizle (sadece rakamlar)
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      final message = Uri.encodeComponent(
          'Merhaba, "${widget.listing['title']}" ilanınız hakkında bilgi almak istiyorum.'
      );
      final url = 'https://wa.me/$cleanNumber?text=$message';

      if (await canLaunch(url)) {
        await launch(url);
        Navigator.pop(context);
        _incrementContactCount();
      } else {
        _showMessage('WhatsApp açılamadı');
      }
    } catch (e) {
      _showMessage('WhatsApp açılamadı');
    }
  }

  Future<void> _sendSMS(String phoneNumber) async {
    try {
      final message = Uri.encodeComponent(
          'Merhaba, "${widget.listing['title']}" ilanınız hakkında bilgi almak istiyorum.'
      );
      final url = 'sms:$phoneNumber?body=$message';

      if (await canLaunch(url)) {
        await launch(url);
        Navigator.pop(context);
        _incrementContactCount();
      } else {
        _showMessage('SMS gönderilemedi');
      }
    } catch (e) {
      _showMessage('SMS gönderilemedi');
    }
  }

  Future<void> _incrementContactCount() async {
    try {
      // Backend'e iletişim sayısını artır
      await _dio.post(
        '${UrlConstants.apiBaseUrl}/api/store/listings/${widget.listing['_id']}/contact',
      );
      print('✅ Contact count incremented');
    } catch (e) {
      print('❌ Contact count increment error: $e');
      // Sessizce devam et
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: _primaryText),
        ),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}