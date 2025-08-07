// lib/register_page.dart - Eksiksiz güncellenmiş versiyon

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'url_constants.dart';
import 'login_page.dart';
import 'main.dart';
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
  String? _authToken;

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
      print('🔄 Kayıt isteği gönderiliyor...');

      // Form data hazırlama
      final formData = {
        'username': _usernameController.text.trim(),
        'firstName': _nameController.text.trim(),
        'lastName': _surnameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? ''
            : _phoneController.text.trim(), // Boşsa boş string
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      };

      print('📤 Gönderilen data: ${formData.keys.toList()}');

      // Client-side validation
      if (formData['username']!.length < 3) {
        throw Exception('Kullanıcı adı en az 3 karakter olmalıdır');
      }

      if (formData['password']!.length < 6) {
        throw Exception('Şifre en az 6 karakter olmalıdır');
      }

      if (!_isValidEmail(formData['email']!)) {
        throw Exception('Geçerli bir e-posta adresi girin');
      }

      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(formData),
      ).timeout(Duration(seconds: 30));

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        print('✅ Kayıt başarılı!');

        // Auth token'ı sakla
        if (responseData['token'] != null) {
          _authToken = responseData['token'];

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', _authToken!);

          // User bilgilerini de sakla
          if (responseData['user'] != null) {
            await prefs.setString('user_data', json.encode(responseData['user']));
          }

          print('✅ Token ve kullanıcı bilgileri kaydedildi');
        }

        // Başarı mesajı göster
        _showSuccessMessage('Hesabınız başarıyla oluşturuldu!');

        // Ödeme dialogunu göster
        await Future.delayed(Duration(seconds: 1));
        _showPaymentDialog();

      } else {
        // Hata durumu
        String errorMessage = 'Kayıt başarısız';

        if (responseData['message'] != null) {
          errorMessage = responseData['message'];
        } else if (responseData['error'] != null) {
          errorMessage = responseData['error'];
        }

        setState(() {
          _errorMessage = errorMessage;
        });

        print('❌ Kayıt hatası: $errorMessage');
      }
    } catch (e) {
      print('❌ Kayıt exception: $e');

      String errorMessage = 'Kayıt sırasında hata oluştu';

      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'İnternet bağlantınızı kontrol edin.';
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }

      setState(() => _errorMessage = errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isValidEmail(String email) {
    return email.contains('@') && email.contains('.');
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Ödeme dialog'u - 2 BUTON TEST AMAÇLI
  void _showPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Premium Erişim - Test',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kayıt işleminiz başarıyla tamamlandı! 🎉',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Premium özellikler:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...[
                    '✅ Tüm müzik kütüphanesine erişim',
                    '✅ Reklamsız deneyim',
                    '✅ Yüksek kalite ses',
                    '✅ Özel çalma listeleri',
                    '✅ Offline dinleme',
                  ].map((feature) => Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      feature,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  )).toList(),
                  SizedBox(height: 16),

                  // Test amaçlı bilgi kutusu
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.science, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Test Modları:',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Uygulama İçi Ürün: Tek seferlik ₺180\n'
                              '• Abonelik: Aylık ₺180',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                // İptal butonu
                TextButton(
                  onPressed: _isPaymentInProgress ? null : () {
                    Navigator.of(context).pop();
                    // Ana sayfaya yönlendir (ücretsiz kullanıcı olarak)
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => MainHomePage()),
                    );
                  },
                  child: Text(
                    'Şimdi Değil',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

                // Abonelik butonu (TEST)
                ElevatedButton(
                  onPressed: _isPaymentInProgress ? null : () => _handleSubscriptionPurchase(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isPaymentInProgress
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                      : Text('Abonelik\n₺180/ay', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                ),

                SizedBox(width: 8),

                // Uygulama içi ürün butonu (TEST)
                ElevatedButton(
                  onPressed: _isPaymentInProgress ? null : () => _handleInAppPurchase(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isPaymentInProgress
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      strokeWidth: 2,
                    ),
                  )
                      : Text('Tek Ödeme\n₺180', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ABONELIK SATINALMASI (TEST)
  Future<void> _handleSubscriptionPurchase() async {
    try {
      print('🔄 ABONELİK satın alma başlatılıyor...');

      Navigator.of(context).pop(); // Dialog'u kapat

      setState(() {
        _isPaymentInProgress = true;
      });

      // Payment service callback'lerini ayarla
      _paymentService.setCallbacks(
        onSuccess: () {
          print('✅ Abonelik ödeme başarılı!');
          if (mounted) {
            setState(() {
              _isPaymentInProgress = false;
            });
            _navigateToMainWithSuccess('Abonelik aktifleştirildi!');
          }
        },
        onError: (String error) {
          print('❌ Abonelik ödeme hatası: $error');
          if (mounted) {
            setState(() {
              _isPaymentInProgress = false;
            });
            _showQuickError('Abonelik hatası: $error');
          }
        },
        onPending: () {
          print('⏳ Abonelik ödeme bekleniyor...');
          _showQuickMessage('Abonelik ödeme işlemi devam ediyor...', Colors.orange);
        },
      );

      // ABONELİK SATINALMASI - direkt Google Play
      final bool success = await _paymentService.purchaseMonthlySubscription();

      if (!success) {
        setState(() {
          _isPaymentInProgress = false;
        });
        _showQuickError('Abonelik ödeme ekranı açılamadı');
      }

    } catch (error) {
      print('❌ Abonelik satın alma exception: $error');
      setState(() {
        _isPaymentInProgress = false;
      });
      _showQuickError('Abonelik hatası: $error');
    }
  }

  // UYGULAMA İÇİ ÜRÜN SATINALMASI (TEST)
  Future<void> _handleInAppPurchase() async {
    try {
      print('🔄 UYGULAMA İÇİ ÜRÜN satın alma başlatılıyor...');

      Navigator.of(context).pop(); // Dialog'u kapat

      setState(() {
        _isPaymentInProgress = true;
      });

      // Payment service callback'lerini ayarla
      _paymentService.setCallbacks(
        onSuccess: () {
          print('✅ Uygulama içi ürün ödeme başarılı!');
          if (mounted) {
            setState(() {
              _isPaymentInProgress = false;
            });
            _navigateToMainWithSuccess('Premium erişim aktifleştirildi!');
          }
        },
        onError: (String error) {
          print('❌ Uygulama içi ürün ödeme hatası: $error');
          if (mounted) {
            setState(() {
              _isPaymentInProgress = false;
            });
            _showQuickError('Premium ürün hatası: $error');
          }
        },
        onPending: () {
          print('⏳ Uygulama içi ürün ödeme bekleniyor...');
          _showQuickMessage('Premium ödeme işlemi devam ediyor...', Colors.orange);
        },
      );

      // UYGULAMA İÇİ ÜRÜN SATINALMASI - direkt Google Play
      final bool success = await _paymentService.purchasePremiumAccess();

      if (!success) {
        setState(() {
          _isPaymentInProgress = false;
        });
        _showQuickError('Premium ürün ödeme ekranı açılamadı');
      }

    } catch (error) {
      print('❌ Uygulama içi ürün satın alma exception: $error');
      setState(() {
        _isPaymentInProgress = false;
      });
      _showQuickError('Premium ürün hatası: $error');
    }
  }

  // Hızlı mesaj gösterme
  void _showQuickMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Hızlı hata gösterme
  void _showQuickError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Ana Sayfa',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MainHomePage()),
            );
          },
        ),
      ),
    );
  }

  // Başarı ile ana sayfaya yönlendirme
  void _navigateToMainWithSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    Future.delayed(Duration(seconds: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainHomePage()),
      );
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginPage()),
            );
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo ve başlık
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.music_note,
                        size: 40,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Hesap Oluştur',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'DJ App ailesine katılın',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),

              // Hata mesajı
              if (_errorMessage.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(bottom: 20),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Kullanıcı Adı
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
                        errorBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Kullanıcı adı gerekli';
                        }
                        if (value.length < 3) {
                          return 'Kullanıcı adı en az 3 karakter olmalı';
                        }
                        if (value.length > 30) {
                          return 'Kullanıcı adı en fazla 30 karakter olabilir';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // Ad
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
                        errorBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ad gerekli';
                        }
                        if (value.length > 50) {
                          return 'Ad en fazla 50 karakter olabilir';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // Soyad
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
                        errorBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Soyad gerekli';
                        }
                        if (value.length > 50) {
                          return 'Soyad en fazla 50 karakter olabilir';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // Telefon (Opsiyonel)
                    TextFormField(
                      controller: _phoneController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Telefon (Opsiyonel)',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon: Icon(Icons.phone, color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        errorBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        // Telefon opsiyonel, ama girilmişse geçerli olmalı
                        if (value != null && value.isNotEmpty) {
                          if (value.length < 10) {
                            return 'Telefon numarası en az 10 haneli olmalıdır';
                          }
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // E-posta
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
                        errorBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'E-posta gerekli';
                        }
                        if (!_isValidEmail(value)) {
                          return 'Geçerli bir e-posta adresi girin';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // Şifre
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
                        errorBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Şifre gerekli';
                        }
                        if (value.length < 6) {
                          return 'Şifre en az 6 karakter olmalı';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 30),

                    // Kayıt butonu
                    ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: Size(double.infinity, 50),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            strokeWidth: 2,
                          ),
                          SizedBox(width: 10),
                          Text('Kayıt oluşturuluyor...'),
                        ],
                      )
                          : Text(
                        'Hesap Oluştur',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Giriş yapma linki
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Zaten hesabınız var mı?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => LoginPage()),
                            );
                          },
                          child: Text(
                            'Giriş Yap',
                            style: TextStyle(
                              color: Colors.white,
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