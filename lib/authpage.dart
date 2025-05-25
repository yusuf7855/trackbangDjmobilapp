
import 'dart:convert';

import 'package:djmobilapp/url_constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isLoading = false;
  String _errorMessage = '';

  // Controllers
  final  _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _resetEmailController = TextEditingController();

  // API endpoints
  static const String _baseUrl = '${UrlConstants.apiBaseUrl}/api';
  static const String _registerEndpoint = '$_baseUrl/register';
  static const String _loginEndpoint = '$_baseUrl/login';
  static const String _forgotPasswordEndpoint = '$_baseUrl/forgot-password';

  // Save token to shared preferences
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Navigate to home
  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MainHomePage()),
    );
  }

  // Handle register
  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(_registerEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _usernameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'phone': _phoneController.text,
          'firstName': _nameController.text,
          'lastName': _surnameController.text,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'])),
        );
        setState(() => _isLogin = true);
      } else {
        throw responseData['message'] ?? 'Kayıt başarısız';
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Handle login
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(_loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        await _saveToken(responseData['token']);
        _navigateToHome();
      } else {
        throw responseData['message'] ?? 'Giriş başarısız';
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Submit auth form
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isLogin) {
      await _login();
    } else {
      await _register();
    }
  }

  // Forgot password
  Future<void> _forgotPassword() async {
    if (_resetEmailController.text.isEmpty) {
      setState(() => _errorMessage = 'Lütfen e-posta girin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(_forgotPasswordEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _resetEmailController.text,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'])),
        );
        Navigator.pop(context);
      } else {
        throw responseData['message'] ?? 'Şifre sıfırlama başarısız';
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Show forgot password dialog
  void _showForgotPasswordDialog() {
    _resetEmailController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Şifre Sıfırlama',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: _resetEmailController,
              decoration: InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _forgotPassword,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Gönder'),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
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
              FlutterLogo(size: 100),
              SizedBox(height: 40),
              Text(
                _isLogin ? 'Hoş Geldiniz' : 'Hesap Oluştur',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),

              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 20),
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
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          prefixIcon: Icon(Icons.account_circle),
                        ),
                        validator: (value) =>
                        value!.isEmpty ? 'Lütfen kullanıcı adı girin' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Ad',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) =>
                        value!.isEmpty ? 'Lütfen adınızı girin' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _surnameController,
                        decoration: InputDecoration(
                          labelText: 'Soyad',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                        value!.isEmpty ? 'Lütfen soyadınızı girin' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Telefon',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                        value!.isEmpty ? 'Lütfen telefon girin' : null,
                      ),
                      SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                      value!.isEmpty ? 'Lütfen e-posta girin' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) =>
                      value!.length < 6 ? 'Şifre en az 6 karakter olmalı' : null,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                        _isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 16),
                    if (_isLogin) TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: Text('Şifremi Unuttum'),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = '';
                      }),
                      child: Text(
                        _isLogin
                            ? 'Hesabınız yok mu? Kayıt Ol'
                            : 'Zaten hesabınız var mı? Giriş Yap',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
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
