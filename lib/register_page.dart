// lib/register_page.dart - Düzeltilmiş versiyon

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

      // Validate form data
      final formData = {
        'username': _usernameController.text.trim(),
        'firstName': _nameController.text.trim(),
        'lastName': _surnameController.text.trim(),
        'phone': _phoneController.text.trim(), // Boş olabilir
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      };

      print('📤 Gönderilen data: ${formData.keys.toList()}');

      // Additional client-side validation
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
    return email.contains('@') && email.contains('.') && email.length > 5;
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

  // ZORUNLU ÖDEME DIALOGU
  void _showPaymentDialog() {
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
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                SizedBox(height: 16),

                // Premium özellikleri
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✨ Premium Özellikler:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildFeatureItem('🎵 Sınırsız müzik erişimi'),
                      _buildFeatureItem('📱 Tüm premium içerikler'),
                      _buildFeatureItem('🚫 Reklamsız deneyim'),
                      _buildFeatureItem('⭐ Özel kullanıcı desteği'),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '💰 Sadece €10/ay',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPaymentInProgress ? null : _startPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isPaymentInProgress
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
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
                      Text('Ödeme İşleniyor...', style: TextStyle(fontSize: 16)),
                    ],
                  )
                      : Text(
                    '💳 Premium Üyelik Satın Al (€10/ay)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  // Ödeme başlatma
  Future<void> _startPayment() async {
    setState(() => _isPaymentInProgress = true);

    try {
      print('💳 Ödeme süreci başlatılıyor...');

      final success = await _paymentService.purchaseMonthlySubscription();

      if (success) {
        print('✅ Ödeme başarılı!');
        Navigator.of(context).pop(); // Payment dialog'u kapat
        _showSuccessDialog();
      } else {
        print('❌ Ödeme başarısız');
        _showPaymentErrorDialog('Ödeme işlemi başarısız oldu. Lütfen tekrar deneyin.');
      }

    } catch (error) {
      print('❌ Ödeme hatası: $error');
      _showPaymentErrorDialog('Ödeme sırasında hata oluştu: $error');
    } finally {
      setState(() => _isPaymentInProgress = false);
    }
  }

  // Başarılı ödeme dialogu
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('🎉 Hoş Geldiniz!', style: TextStyle(color: Colors.white)),
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

  // Ödeme hata dialogu
  void _showPaymentErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('❌ Ödeme Hatası', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Tamam', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startPayment(); // Tekrar dene
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Hesap Oluştur',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo veya başlık
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.music_note,
                    size: 64,
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'DJ Mobile App',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Müzik dünyasına katılın',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 40),

            // Hata mesajı
            if (_errorMessage.isNotEmpty)
              Container(
                margin: EdgeInsets.only(bottom: 16),
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
                      prefixIcon: Icon(Icons.person_add_alt_1, color: Colors.white70),
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
                      mainAxisSize: MainAxisSize.min,
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
                        Text(
                          'Hesap Oluşturuluyor...',
                          style: TextStyle(fontSize: 16),
                        ),
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

                  // Giriş yap linki
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Zaten hesabınız var mı? ',
                        style: TextStyle(color: Colors.white70),
                      ),
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
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
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
}