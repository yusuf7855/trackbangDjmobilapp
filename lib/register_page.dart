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
      setState(() => _isLoading = false);
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
            title: Row(
              children: [
                Icon(Icons.payment, color: Colors.green),
                SizedBox(width: 8),
                Text('💳 Premium Üyelik Zorunlu'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    '📱 Hesabınız oluşturuldu!\nUygulamayı kullanmaya başlamak için Premium üyelik gereklidir.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 16),
                Text('🎵 Premium Üyelik Avantajları:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '10€/ay',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'İlk ay deneme süresi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
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
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
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
                          color: Colors.white,
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
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ÖDEME İŞLEMİ
  Future<void> _handlePremiumPurchase() async {
    if (_isPaymentInProgress) return;

    setState(() {
      _isPaymentInProgress = true;
    });

    try {
      print('🛒 Starting premium purchase...');

      // Auth token kontrolü
      if (_authToken == null) {
        throw Exception('Kullanıcı girişi gerekli');
      }

      // Payment service ile ödeme başlat
      final bool success = await _paymentService.purchaseMonthlySubscription();

      if (success) {
        print('✅ Payment process started successfully');
        Navigator.of(context).pop(); // Ödeme dialogunu kapat
        _showProcessingDialog();
      } else {
        throw Exception('Ödeme işlemi başlatılamadı');
      }

    } catch (error) {
      print('❌ Payment error: $error');
      _showErrorDialog('Ödeme hatası: $error');
    } finally {
      setState(() {
        _isPaymentInProgress = false;
      });
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
            title: Row(
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(width: 16),
                Text('İşleminiz Gerçekleştiriliyor'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ödemeniz Google Play üzerinden işleniyor...\n\nLütfen bekleyin, sayfayı kapatmayın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '💡 Bu işlem 30 saniye ile 2 dakika arası sürebilir.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
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
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 30),
              SizedBox(width: 12),
              Text('🎉 Tebrikler!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Premium üyeliğiniz başarıyla aktifleştirildi!\n\nArtık tüm özelliklerden yararlanabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '✨ Hoş geldiniz! Uygulamayı keşfetmeye başlayabilirsiniz.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
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
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
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
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('⏳ Ödeme Bekleniyor'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ödemeniz henüz onaylanmadı.\n\nBu normal bir durum - Google Play ödemeleri birkaç dakika sürebilir.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Ne yapmak istiyorsunuz?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkSubscriptionStatus(); // Tekrar kontrol et
              },
              child: Text('🔄 Tekrar Kontrol Et'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showPaymentDialog(); // Ödeme dialogunu tekrar aç
              },
              child: Text('💳 Yeniden Ödeme Yap'),
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
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('❌ Hata'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showPaymentDialog(); // Ödeme dialoguna geri dön
              },
              child: Text('Tekrar Dene'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 40),
              // Logo
              Container(
                height: 100,
                child: Icon(
                  Icons.music_note,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: 40),
              Text(
                'Hesap Oluştur',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Premium üyelikle tüm özelliklere erişin',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),

              // Error message
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
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
                      decoration: InputDecoration(
                        labelText: 'Kullanıcı Adı',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) => value!.isEmpty ? 'Kullanıcı adı gerekli' : null,
                    ),
                    SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Ad',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) => value!.isEmpty ? 'Ad gerekli' : null,
                    ),
                    SizedBox(height: 16),

                    TextFormField(
                      controller: _surnameController,
                      decoration: InputDecoration(
                        labelText: 'Soyad',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) => value!.isEmpty ? 'Soyad gerekli' : null,
                    ),
                    SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Telefon',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) => value!.isEmpty ? 'Telefon gerekli' : null,
                    ),
                    SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value!.isEmpty) return 'E-posta gerekli';
                        if (!value.contains('@')) return 'Geçerli e-posta girin';
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value!.isEmpty) return 'Şifre gerekli';
                        if (value.length < 6) return 'Şifre en az 6 karakter olmalı';
                        return null;
                      },
                    ),
                    SizedBox(height: 24),

                    // Register Button
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Hesap Oluşturuluyor...'),
                          ],
                        )
                            : Text(
                          'Hesap Oluştur & Premium Ol',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Zaten hesabınız var mı? '),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => LoginPage()),
                            );
                          },
                          child: Text(
                            'Giriş Yapın',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }
}