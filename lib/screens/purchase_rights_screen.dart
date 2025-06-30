// lib/screens/purchase_rights_screen.dart - DÜZELTILMIŞ HATASIZ VERSİYON

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../url_constants.dart';

class PurchaseRightsScreen extends StatefulWidget {
  final VoidCallback? onPurchaseCompleted;

  PurchaseRightsScreen({this.onPurchaseCompleted});

  @override
  _PurchaseRightsScreenState createState() => _PurchaseRightsScreenState();
}

class _PurchaseRightsScreenState extends State<PurchaseRightsScreen> {
  final Dio _dio = Dio();

  bool _isLoading = false;
  int _selectedRightsAmount = 1;
  int _currentAvailableRights = 0;

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

  @override
  void initState() {
    super.initState();
    _loadCurrentRights();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('İlan Hakkı Satın Al', style: TextStyle(color: _primaryText)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryText),
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_blueColor),
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentRightsCard(),
            SizedBox(height: 24),
            _buildInfoCard(),
            SizedBox(height: 24),
            _buildRightsPackages(),
            SizedBox(height: 32),
            _buildPurchaseButton(),
          ],
        ),
      ),
    );
  }

  // DÜZELTILMIŞ: Method class içine taşındı
  Widget _buildCurrentRightsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet,
            size: 48,
            color: _currentAvailableRights > 0 ? _greenColor : _orangeColor,
          ),
          SizedBox(height: 12),
          Text(
            'Mevcut İlan Hakkınız',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '$_currentAvailableRights',
            style: TextStyle(
              color: _primaryText,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_currentAvailableRights == 0) ...[
            SizedBox(height: 8),
            Text(
              'İlan vermek için hak satın almanız gerekiyor',
              style: TextStyle(
                color: _orangeColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
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
              Icon(Icons.info_outline, color: _blueColor, size: 24),
              SizedBox(width: 12),
              Text(
                'İlan Hakkı Hakkında',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoItem('• Her ilan hakkı ile 1 ilan verebilirsiniz'),
          _buildInfoItem('• İlanlar 30 gün süreyle aktif kalır'),
          _buildInfoItem('• Hak satın aldıktan sonra anında kullanabilirsiniz'),
          _buildInfoItem('• Haklar hesabınızda kalıcı olarak saklanır'),
          _buildInfoItem('• İlan hakkı fiyatı: 4.00 EUR'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: _secondaryText,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildRightsPackages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paket Seçin',
          style: TextStyle(
            color: _primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 16),
        _buildPackageOption(1, '4.00 EUR', 'Tek İlan'),
        SizedBox(height: 12),
        _buildPackageOption(3, '10.00 EUR', '3 İlan Paketi'),
        SizedBox(height: 12),
        _buildPackageOption(5, '15.00 EUR', '5 İlan Paketi', isPopular: true),
        SizedBox(height: 12),
        _buildPackageOption(10, '25.00 EUR', '10 İlan Paketi'),
      ],
    );
  }

  Widget _buildPackageOption(int rights, String price, String title, {bool isPopular = false}) {
    bool isSelected = _selectedRightsAmount == rights;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRightsAmount = rights;
        });
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _blueColor.withOpacity(0.1) : _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _blueColor : _borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio button
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _blueColor : _accentColor,
                  width: 2,
                ),
                color: isSelected ? _blueColor : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 14, color: _primaryText)
                  : null,
            ),
            SizedBox(width: 16),
            // Package info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isPopular) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _orangeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'POPÜLER',
                            style: TextStyle(
                              color: _backgroundColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$rights İlan Hakkı',
                    style: TextStyle(
                      color: _secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Price
            Text(
              price,
              style: TextStyle(
                color: _primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseButton() {
    double totalPrice = _selectedRightsAmount * 4.00;

    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _purchaseRights,
        style: ElevatedButton.styleFrom(
          backgroundColor: _blueColor,
          foregroundColor: _primaryText,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryText),
            strokeWidth: 2,
          ),
        )
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Satın Al',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '$_selectedRightsAmount hak - ${totalPrice.toStringAsFixed(2)} EUR',
              style: TextStyle(
                fontSize: 14,
                color: _primaryText.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCurrentRights() async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        _showMessage('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.');
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
          _currentAvailableRights = response.data['rights']['availableRights'] ?? 0;
        });
      }
    } catch (e) {
      print('Rights yükleme hatası: $e');
      _showMessage('İlan hakları yüklenirken hata oluştu');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _purchaseRights() async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        _showMessage('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.');
        return;
      }

      final response = await _dio.post(
        '${UrlConstants.apiBaseUrl}/api/store/rights/purchase',
        data: {
          'rightsAmount': _selectedRightsAmount,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $authToken'},
        ),
      );

      if (response.statusCode == 200 && response.data['success']) {
        final newAvailableRights = response.data['rights']['availableRights'];

        setState(() {
          _currentAvailableRights = newAvailableRights;
        });

        _showMessage(
            '${_selectedRightsAmount} ilan hakkı başarıyla satın alındı!',
            isSuccess: true
        );

        // Callback'i çağır (ana sayfaya döndüğünde liste güncellensin)
        if (widget.onPurchaseCompleted != null) {
          widget.onPurchaseCompleted!();
        }

        // 2 saniye sonra geri dön
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true); // true = satın alma başarılı
          }
        });

      } else {
        _showMessage(response.data['message'] ?? 'Satın alma işlemi başarısız');
      }
    } catch (e) {
      print('Satın alma hatası: $e');
      if (e is DioException) {
        _showMessage(e.response?.data['message'] ?? 'Satın alma işlemi başarısız');
      } else {
        _showMessage('Satın alma işlemi başarısız: $e');
      }
    } finally {
      setState(() => _isLoading = false);
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
        backgroundColor: isSuccess ? _greenColor : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }
}