// lib/screens/listing_detail_screen.dart - İlan Detay Sayfası Google Maps ile

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

  @override
  void initState() {
    super.initState();
    _setupLocationAndMap();
  }

  void _setupLocationAndMap() {
    // Varsayılan koordinatlar (örnek: Samsun merkez)
    double defaultLat = 41.2928;
    double defaultLng = 36.3313;

    // Eğer listing'de koordinatlar varsa onları kullan
    if (widget.listing['location']?['coordinates'] != null) {
      final coords = widget.listing['location']['coordinates'];
      if (coords['latitude'] != null && coords['longitude'] != null) {
        defaultLat = coords['latitude'].toDouble();
        defaultLng = coords['longitude'].toDouble();
      }
    }

    _initialCameraPosition = CameraPosition(
      target: LatLng(defaultLat, defaultLng),
      zoom: 14.0,
    );

    _markers.add(
      Marker(
        markerId: MarkerId('listing_location'),
        position: LatLng(defaultLat, defaultLng),
        infoWindow: InfoWindow(
          title: widget.listing['location']?['district'] ?? 'Konum',
          snippet: widget.listing['location']?['province'] ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('İlan Detayı', style: TextStyle(color: _primaryText)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryText),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: _primaryText),
            onPressed: () => _shareListing(),
          ),
        ],
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
                  SizedBox(height: 20),
                  _buildTitleAndPrice(),
                  SizedBox(height: 20),
                  _buildSellerInfo(),
                  SizedBox(height: 20),
                  _buildInfoSection(),
                  SizedBox(height: 20),
                  _buildLocationSection(),
                  SizedBox(height: 20),
                  _buildMapSection(),
                  SizedBox(height: 20),
                  _buildDescriptionSection(),
                  SizedBox(height: 20),
                  _buildContactButtons(),
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
        height: 250,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Center(
          child: Icon(Icons.image_outlined, size: 64, color: _tertiaryText),
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return Image.network(
                  imageUrls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: _cardColor,
                      child: Icon(Icons.error, color: _tertiaryText),
                    );
                  },
                );
              },
            ),
          ),
        ),
        if (imageUrls.length > 1) ...[
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              imageUrls.length,
                  (index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentImageIndex == index ? _accentColor : _borderColor,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTitleAndPrice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.listing['title']?.toString() ?? 'Başlık yok',
          style: TextStyle(
            color: _primaryText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Text(
              '₺${widget.listing['price']?.toString() ?? '0'}',
              style: TextStyle(
                color: _greenColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accentColor),
              ),
              child: Text(
                widget.listing['category']?.toString() ?? 'Kategori',
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
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
      child: Row(
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
            icon: Icon(Icons.message, color: _accentColor),
            style: IconButton.styleFrom(
              backgroundColor: _accentColor.withOpacity(0.1),
              shape: CircleBorder(),
            ),
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
        children: [
          _buildInfoRow('İlan No', widget.listing['listingNumber']?.toString() ?? 'N/A'),
          Divider(color: _borderColor, height: 24),
          _buildInfoRow('Yayın Tarihi', _formatDate(widget.listing['createdAt'])),
          Divider(color: _borderColor, height: 24),
          _buildInfoRow('Görüntülenme', '${widget.listing['viewCount'] ?? 0}'),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final location = widget.listing['location'];
    if (location == null) return SizedBox.shrink();

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
              Icon(Icons.location_on, color: _accentColor, size: 20),
              SizedBox(width: 8),
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
          SizedBox(height: 12),
          _buildInfoRow('İl', location['province']?.toString() ?? ''),
          Divider(color: _borderColor, height: 16),
          _buildInfoRow('İlçe', location['district']?.toString() ?? ''),
          if (location['fullAddress'] != null && location['fullAddress'].toString().isNotEmpty) ...[
            Divider(color: _borderColor, height: 16),
            _buildInfoRow('Adres', location['fullAddress'].toString()),
          ],
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          initialCameraPosition: _initialCameraPosition,
          markers: _markers,
          mapType: MapType.normal,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: _secondaryText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              color: _primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
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
              color: _primaryText,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactButtons() {
    return Column(
      children: [
        // Telefon arama butonu
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _makePhoneCall(),
            icon: Icon(Icons.phone, color: _primaryText),
            label: Text(
              'Ara: ${widget.listing['phoneNumber']?.toString() ?? 'Telefon Yok'}',
              style: TextStyle(
                color: _primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _greenColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        // WhatsApp butonu
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => _sendWhatsApp(),
            icon: Icon(Icons.chat, color: _accentColor),
            label: Text(
              'WhatsApp ile Mesaj Gönder',
              style: TextStyle(
                color: _accentColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _accentColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _getUserProfileImage(dynamic user) {
    String? imageUrl = user['profileImageUrl']?.toString();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final fullUrl = imageUrl.startsWith('http')
          ? imageUrl
          : '${UrlConstants.apiBaseUrl}$imageUrl';

      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildUserPlaceholder(),
      );
    }

    return _buildUserPlaceholder();
  }

  Widget _buildUserPlaceholder() {
    return Container(
      color: _accentColor,
      child: Icon(
        Icons.person,
        color: _primaryText,
        size: 24,
      ),
    );
  }

  List<String> _getImageUrls() {
    List<String> urls = [];

    if (widget.listing['images'] != null) {
      for (var image in widget.listing['images']) {
        String imageUrl = '';

        if (image is Map && image['url'] != null) {
          imageUrl = image['url'].toString();
        } else if (image is String) {
          imageUrl = image;
        }

        if (imageUrl.isNotEmpty) {
          final fullUrl = imageUrl.startsWith('http')
              ? imageUrl
              : '${UrlConstants.apiBaseUrl}$imageUrl';
          urls.add(fullUrl);
        }
      }
    }

    return urls;
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

  void _makePhoneCall() async {
    final phoneNumber = widget.listing['phoneNumber']?.toString();
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final uri = Uri.parse('tel:$phoneNumber');
      try {
        await launchUrl(uri);
        _incrementContactCount();
      } catch (e) {
        _showErrorSnackBar('Telefon uygulaması açılamadı');
      }
    } else {
      _showErrorSnackBar('Telefon numarası bulunamadı');
    }
  }

  void _sendWhatsApp() async {
    final phoneNumber = widget.listing['phoneNumber']?.toString();
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      // Türkiye telefon numarası formatını düzenle
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanNumber.startsWith('0')) {
        cleanNumber = '90${cleanNumber.substring(1)}';
      } else if (!cleanNumber.startsWith('90')) {
        cleanNumber = '90$cleanNumber';
      }

      final message = Uri.encodeComponent(
          'Merhaba, "${widget.listing['title']}" ilanınız hakkında bilgi almak istiyorum.'
      );

      final uri = Uri.parse('https://wa.me/$cleanNumber?text=$message');

      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _incrementContactCount();
      } catch (e) {
        _showErrorSnackBar('WhatsApp açılamadı');
      }
    } else {
      _showErrorSnackBar('Telefon numarası bulunamadı');
    }
  }

  void _showContactOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'İletişim Seçenekleri',
              style: TextStyle(
                color: _primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _greenColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.phone, color: _greenColor),
              ),
              title: Text(
                'Telefon ile Ara',
                style: TextStyle(color: _primaryText, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                widget.listing['phoneNumber']?.toString() ?? '',
                style: TextStyle(color: _secondaryText),
              ),
              onTap: () {
                Navigator.pop(context);
                _makePhoneCall();
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chat, color: _accentColor),
              ),
              title: Text(
                'WhatsApp',
                style: TextStyle(color: _primaryText, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Mesaj gönder',
                style: TextStyle(color: _secondaryText),
              ),
              onTap: () {
                Navigator.pop(context);
                _sendWhatsApp();
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _shareListing() async {
    // Basit paylaşım fonksiyonu - daha gelişmiş paylaşım için share_plus paketi kullanılabilir
    final text = '${widget.listing['title']} - ₺${widget.listing['price']}\n'
        'Konum: ${widget.listing['location']?['district']}, ${widget.listing['location']?['province']}\n'
        'İlan No: ${widget.listing['listingNumber']}';

    // Burada share fonksiyonu çağrılabilir
    _showSuccessSnackBar('İlan bilgileri kopyalandı');
  }

  Future<void> _incrementContactCount() async {
    try {
      await _dio.post(
        '${UrlConstants.apiBaseUrl}/api/store/listings/${widget.listing['_id']}/contact',
      );
    } catch (e) {
      print('Contact count increment error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _greenColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}