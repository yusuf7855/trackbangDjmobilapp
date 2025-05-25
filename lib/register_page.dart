import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';
import './url_constants.dart';
class RegisterPage extends StatefulWidget {
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  static const String _registerEndpoint = '${UrlConstants.apiBaseUrl}/api/register';

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseData['message'])));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
      } else {
        throw responseData['message'] ?? 'Kayıt başarısız';
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
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
                'Hesap Oluştur',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              if (_errorMessage.isNotEmpty)
                Text(_errorMessage, style: TextStyle(color: Colors.red), textAlign: TextAlign.center),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(labelText: 'Kullanıcı Adı', prefixIcon: Icon(Icons.person)),
                      validator: (value) => value!.isEmpty ? 'Kullanıcı adı girin' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Ad', prefixIcon: Icon(Icons.person_outline)),
                      validator: (value) => value!.isEmpty ? 'Ad girin' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _surnameController,
                      decoration: InputDecoration(labelText: 'Soyad', prefixIcon: Icon(Icons.person_outline)),
                      validator: (value) => value!.isEmpty ? 'Soyad girin' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(labelText: 'Telefon', prefixIcon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                      validator: (value) => value!.isEmpty ? 'Telefon girin' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email)),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => value!.isEmpty ? 'E-posta girin' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: 'Şifre', prefixIcon: Icon(Icons.lock)),
                      obscureText: true,
                      validator: (value) => value!.length < 6 ? 'Şifre en az 6 karakter olmalı' : null,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      child: _isLoading ? CircularProgressIndicator(color: Colors.white) : Text('Kayıt Ol'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
                      },
                      child: Text('Zaten hesabınız var mı? Giriş Yap'),
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
