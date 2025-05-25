import 'dart:async';
import 'dart:convert';
import 'package:djmobilapp/url_constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  static const String _loginEndpoint = '${UrlConstants.apiBaseUrl}/api/login';
  static const String _forgotPasswordEndpoint = '${UrlConstants.apiBaseUrl}/api/forgot-password';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthState();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthState() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getString('userId');

    if (token != null && userId != null && await _isValidToken(token)) {
      await _navigateToHome();
    }
  }

  // JWT Token kontrolü
  Future<bool> _isValidToken(String token) async {
    try {
      final payload = _parseJwt(token);
      final exp = payload['exp'] as int?;
      if (exp == null) return false;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return expiryDate.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> _parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid token');
    }

    final payload = _decodeBase64(parts[1]);
    final payloadMap = json.decode(payload);
    if (payloadMap is! Map<String, dynamic>) {
      throw Exception('Invalid payload');
    }

    return payloadMap;
  }

  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');

    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!');
    }

    return utf8.decode(base64Url.decode(output));
  }

  Future<void> _saveUserData(String token, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    final tokenData = _parseJwt(token);
    await prefs.setString('userId', tokenData['userId'].toString());
    await prefs.setString('userName', username);
  }

  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('userId');
    await prefs.remove('userName');
  }

  Future<void> _navigateToHome() async {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MainHomePage()),
          (Route<dynamic> route) => false,
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(_loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 10));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        await _saveUserData(responseData['token'], responseData['username'] ?? '');
        await _navigateToHome();
      } else {
        throw responseData['message'] ?? 'Giriş başarısız. Lütfen bilgilerinizi kontrol edin.';
      }
    } on http.ClientException catch (e) {
      setState(() => _errorMessage = 'Sunucuya bağlanılamadı: ${e.message}');
    } on TimeoutException catch (_) {
      setState(() => _errorMessage = 'Bağlantı zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.');
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    if (_resetEmailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen e-posta girin')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(_forgotPasswordEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': _resetEmailController.text.trim()}),
      ).timeout(const Duration(seconds: 10));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'])),
        );
        Navigator.pop(context);
      } else {
        throw responseData['message'] ?? 'Şifre sıfırlama başarısız';
      }
    } on TimeoutException catch (_) {
      setState(() => _errorMessage = 'İstek zaman aşımına uğradı');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    _resetEmailController.clear();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      builder: (ctx) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Şifre Sıfırlama',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 20),
            TextFormField(
              controller: _resetEmailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
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
            ),
            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black, backgroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
              onPressed: _isLoading ? null : _forgotPassword,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.black)
                  : Text('Gönder', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
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

                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofocus: false,
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
                        validator: (value) => value!.isEmpty ? 'E-posta girin' : null,
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        autofocus: false,
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
                        validator: (value) =>
                        value!.length < 6 ? 'En az 6 karakter olmalı' : null,
                      ),
                      SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black, backgroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 50),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.black)
                            : Text('Giriş Yap', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 20),
                      TextButton(
                        onPressed: _isLoading ? null : _showForgotPasswordDialog,
                        child: Text('Şifremi Unuttum',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => RegisterPage()));
                        },
                        child: Text(
                          'Hesabınız yok mu? Kayıt Ol',
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