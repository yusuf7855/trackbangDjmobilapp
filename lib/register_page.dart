import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'url_constants.dart';
import 'login_page.dart';
import 'services/payment_service.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPaymentInProgress = false;
  String _errorMessage = '';
  String? _authToken; // Kayıt sonrası auth token

  final PaymentService _paymentService = PaymentService();

  @override
  void initState() {
    super.initState();
    _initializePaymentService();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializePaymentService() async {
    try {
      await _paymentService.initialize();
      print('✅ Payment service initialized successfully');
    } catch (error) {
      print('❌ Payment service initialization error: $error');
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _usernameController.text.trim(),
          'firstName': _nameController.text.trim(),
          'lastName': _surnameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        // Kayıt başarılı - Auth token'ı sakla
        if (responseData['token'] != null) {
          _authToken = responseData['token'];

          // SharedPreferences'a kaydet
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', _authToken!);

          print('✅ Registration successful, token saved');
        }

        // Ödeme dialogunu göster
        _showPaymentDialog();
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Kayıt başarısız';
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Bağlantı hatası: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ZORUNLU ÖDEME DIALOGU
  void _showPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Kapatılamaz!
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Geri tuşunu devre dışı bırak
          child: AlertDialog(
            backgroundColor: Colors.black,
            title: Row(
              children: [
                Icon(Icons.payment, color: Colors.white),
                SizedBox(width: 8),
                Text('💳 Premium Üyelik Zorunlu', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Text(
                    '📱 Hesabınız oluşturuldu!\nUygulamayı kullanmaya başlamak için Premium üyelik gereklidir.',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                SizedBox(height: 16),
                Text('🎵 Premium Üyelik Avantajları:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                SizedBox(height: 8),
                _buildFeature('✨', 'Tüm içeriklere sınırsız erişim'),
                _buildFeature('📱', 'Reklamsız deneyim'),
                _buildFeature('⬇️', 'Offline dinleme özelliği'),
                _buildFeature('🎧', 'Yüksek kalite ses'),
                _buildFeature('🎛️', 'Premium mixler ve sample\'lar'),
                _buildFeature('🔄', 'İstediğin zaman iptal edebilirsin'),

                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '10€/ay',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'İlk ay deneme süresi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Sadece ödeme butonu - iptal yok!
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPaymentInProgress ? null : _handlePremiumPurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isPaymentInProgress
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('İşleniyor...'),
                    ],
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.credit_card),
                      SizedBox(width: 8),
                      Text(
                        'Premium Üyelik Satın Al (10€)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeature(String icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(icon, style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // ÖDEME İŞLEMİ
  Future<void> _handlePremiumPurchase() async {
    setState(() => _isPaymentInProgress = true);

    try {
      _showProcessingDialog();

      // PaymentService üzerinden ödeme başlat
      final bool success = await _paymentService.purchaseMonthlySubscription();

      if (success) {
        // 30 saniye bekle, ardından durum kontrol et
        await Future.delayed(Duration(seconds: 30));
        _checkSubscriptionStatus();
      }
    } catch (error) {
      print('❌ Payment error: $error');
      _showErrorDialog('Ödeme hatası: $error');
    } finally {
      setState(() => _isPaymentInProgress = false);
    }
  }
  // ÖDEME İŞLEME DIALOGU
  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: Colors.black,
            title: Row(
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                ),
                SizedBox(width: 16),
                Text('İşleminiz Gerçekleştiriliyor', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ödemeniz Google Play üzerinden işleniyor...\n\nLütfen bekleyin, sayfayı kapatmayın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '💡 Bu işlem 30 saniye ile 2 dakika arası sürebilir.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // 30 saniye sonra durum kontrolü
    Future.delayed(Duration(seconds: 30), () {
      if (mounted) {
        Navigator.of(context).pop(); // Processing dialogunu kapat
        _checkSubscriptionStatus();
      }
    });
  }

  // ABONELIK DURUMU KONTROLÜ
  Future<void> _checkSubscriptionStatus() async {
    try {
      final bool isPremium = await _paymentService.isPremiumUser();

      if (isPremium) {
        _showSuccessDialog();
      } else {
        _showRetryDialog();
      }
    } catch (error) {
      print('❌ Subscription check error: $error');
      _showRetryDialog();
    }
  }

  // BAŞARI DIALOGU
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 30),
              SizedBox(width: 12),
              Text('🎉 Tebrikler!', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Premium üyeliğiniz başarıyla aktifleştirildi!\n\nArtık tüm özelliklerden yararlanabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '✨ Hoş geldiniz! Uygulamayı keşfetmeye başlayabilirsiniz.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(context, '/free'); // Ana sayfaya git
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Uygulamayı Kullanmaya Başla',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // YENİDEN DENEME DIALOGU
  void _showRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('⏳ Ödeme Bekleniyor', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ödemeniz henüz onaylanmadı.\n\nBu normal bir durum - Google Play ödemeleri birkaç dakika sürebilir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 16),
              Text(
                'Ne yapmak istiyorsunuz?',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkSubscriptionStatus(); // Tekrar kontrol et
              },
              child: Text('🔄 Tekrar Kontrol Et', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showPaymentDialog(); // Ödeme dialogunu tekrar aç
              },
              child: Text('💳 Yeniden Ödeme Yap', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  // HATA DIALOGU
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('❌ Hata', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(message, style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showPaymentDialog(); // Ödeme dialoguna geri dön
              },
              child: Text('Tekrar Dene', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 60),
                // Logo kısmı
                Container(
                  height: 100,
                  child: Image.asset('assets/your_logo.png'),
                ),
                SizedBox(height: 40),

                // Error message
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.person, color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white70),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        validator: (value) => value!.isEmpty ? 'Kullanıcı adı gerekli' : null,
                      ),
                      SizedBox(height: 20),

                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Ad',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.person_outline, color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white70),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        validator: (value) => value!.isEmpty ? 'Ad gerekli' : null,
                      ),
                      SizedBox(height: 20),

                      TextFormField(
                        controller: _surnameController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Soyad',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.person_outline, color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white70),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        validator: (value) => value!.isEmpty ? 'Soyad gerekli' : null,
                      ),
                      SizedBox(height: 20),

                      TextFormField(
                        controller: _phoneController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Telefon',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.phone, color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white70),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) => value!.isEmpty ? 'Telefon gerekli' : null,
                      ),
                      SizedBox(height: 20),

                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'E-posta',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.email, color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white70),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value!.isEmpty) return 'E-posta gerekli';
                          if (!value.contains('@')) return 'Geçerli e-posta girin';
                          return null;
                        },
                      ),
                      SizedBox(height: 20),

                      TextFormField(
                        controller: _passwordController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.lock, color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white70),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value!.isEmpty) return 'Şifre gerekli';
                          if (value.length < 6) return 'Şifre en az 6 karakter olmalı';
                          return null;
                        },
                      ),
                      SizedBox(height: 30),

                      // Register Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: Size(double.infinity, 50),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.black)
                            : Text('Hesap Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 20),

                      // Login Link
                      TextButton(
                        onPressed: _isLoading ? null : () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => LoginPage()),
                          );
                        },
                        child: Text(
                          'Zaten hesabınız var mı? Giriş Yap',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}