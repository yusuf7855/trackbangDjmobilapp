import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async'; // Timer için gerekli import
import 'services/payment_service.dart';

class FreePage extends StatefulWidget {
  @override
  _FreePageState createState() => _FreePageState();
}

class _FreePageState extends State<FreePage> with SingleTickerProviderStateMixin {
  final Map<String, WebViewController> _controllerCache = {};
  final Map<String, bool> _loadingStates = {};
  bool _allLoaded = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  final List<Map<String, String>> tracks = [
    {'id': "4QHKR48C18rwlpSYW6rH7p"},
    {'id': "3pPe4F2kFRp9ipARwxFmQr"},
    {'id': "2MFs3zQcS0MuIjuyyG85fV"},
    {'id': "0RMmME0OhJcrWtnb2kZMHL"},
    {'id': "70sMnVjOXAbZCH5USpGuOG"},
  ];

  final PaymentService _paymentService = PaymentService();
  bool _isPaymentInProgress = false;
  Timer? _processingTimer; // Timer variable

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _colorAnimation = ColorTween(
      begin: Colors.white.withOpacity(0.8),
      end: Colors.white,
    ).animate(_animationController);

    _preloadWebViews();
    _initializePaymentService();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _paymentService.dispose();
    _processingTimer?.cancel(); // Timer'ı temizle
    super.dispose();
  }

  Future<void> _initializePaymentService() async {
    try {
      await _paymentService.initialize();
      print('Payment service initialized successfully');
    } catch (error) {
      print('Payment service initialization error: $error');
    }
  }

  void _preloadWebViews() async {
    for (final track in tracks) {
      _loadingStates[track['id']!] = false;

      final controller = WebViewController();

      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              if (mounted) {
                setState(() {
                  _loadingStates[track['id']!] = true;
                  _checkAllLoaded();
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(
          'https://open.spotify.com/embed/track/${track['id']}?utm_source=generator',
        ));

      _controllerCache[track['id']!] = controller;
    }
  }

  void _checkAllLoaded() {
    if (_loadingStates.values.every((isLoaded) => isLoaded)) {
      if (mounted) {
        setState(() {
          _allLoaded = true;
        });
        _animationController.dispose();
      }
    }
  }

  // Ödeme işlemi başlat
  Future<void> _handleSubscriptionPurchase() async {
    if (_isPaymentInProgress) return;

    setState(() {
      _isPaymentInProgress = true;
    });

    try {
      // Önce kullanıcıya ödeme onayı sor
      final bool? confirmed = await _showPaymentConfirmDialog();

      if (confirmed == true) {
        // Ödeme işlemini başlat
        final bool success = await _paymentService.purchaseMonthlySubscription();

        if (success) {
          // Başarılı ödeme işlemi başlatıldı
          _showProcessingDialog();
        }
      }
    } catch (error) {
      print('Payment error: $error');
      _showErrorDialog('Ödeme sırasında bir hata oluştu: $error');
    } finally {
      setState(() {
        _isPaymentInProgress = false;
      });
    }
  }

  // Ödeme onay dialogu
  Future<bool?> _showPaymentConfirmDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('🎵 Premium Üyelik'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✨ Tüm içeriklere sınırsız erişim'),
              SizedBox(height: 8),
              Text('📱 Reklamsız deneyim'),
              SizedBox(height: 8),
              Text('⬇️ Offline dinleme'),
              SizedBox(height: 8),
              Text('🎧 Yüksek kalite ses'),
              SizedBox(height: 8),
              Text('🎛️ Premium mixler ve sample\'lar'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Text(
                  '10€/ay - İstediğin zaman iptal edebilirsin',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Satın Al'),
            ),
          ],
        );
      },
    );
  }

  // İşleme dialogu - DÜZELTİLMİŞ Timer kullanımı
  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('İşleminiz Gerçekleştiriliyor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Ödemeniz doğrulanıyor...\nLütfen bekleyin.'),
            ],
          ),
        );
      },
    );

    // DÜZELTİLMİŞ - Timer kullanımı
    _processingTimer = Timer(Duration(seconds: 30), () {
      if (mounted) {
        Navigator.of(context).pop();
        _checkSubscriptionStatus();
      }
    });
  }

  // Abonelik durumunu kontrol et
  Future<void> _checkSubscriptionStatus() async {
    try {
      final bool isPremium = await _paymentService.isPremiumUser();
      if (isPremium) {
        _showSuccessDialog();
      } else {
        _showErrorDialog('Ödeme henüz onaylanmadı. Lütfen birkaç dakika bekleyip tekrar deneyin.');
      }
    } catch (error) {
      _showErrorDialog('Durum kontrol edilemedi: $error');
    }
  }

  // Başarı dialogu
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('🎉 Tebrikler!'),
          content: Text('Premium üyeliğiniz aktifleştirildi!\n\nArtık tüm içeriklere erişebilir, reklamsız deneyimin keyfini çıkarabilirsiniz.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/home');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Anasayfaya Git'),
            ),
          ],
        );
      },
    );
  }

  // Hata dialogu
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('❌ Hata'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Tamam'),
            ),
            if (message.contains('tekrar dene'))
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _checkSubscriptionStatus();
                },
                child: Text('Tekrar Kontrol Et'),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Image.asset(
          'assets/your_logo.png',
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              'DJ App',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _allLoaded ? _buildMainContent() : _buildLoadingScreen(),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        Expanded(child: _buildTracksList()),
        _buildBottomSection(),
      ],
    );
  }

  Widget _buildTracksList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final controller = _controllerCache[track['id']!];

        if (controller == null) return SizedBox.shrink();

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          height: 152,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: WebViewWidget(controller: controller),
          ),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isVerySmallScreen = screenWidth < 350;

    return Container(
      padding: EdgeInsets.all(isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16)),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tüm İçeriklere Erişebilmek İçin Premium Ol!',
            style: TextStyle(
              color: Colors.white,
              fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20)),

          // Premium ol butonu
          SizedBox(
            width: double.infinity,
            height: isVerySmallScreen ? 48 : (isSmallScreen ? 50 : 52),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 3,
                shadowColor: Colors.white.withOpacity(0.3),
              ),
              onPressed: _isPaymentInProgress ? null : _handleSubscriptionPurchase,
              child: _isPaymentInProgress
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
                  : Text(
                'Premium Ol - 10€/ay',
                style: TextStyle(
                  fontSize: isVerySmallScreen ? 16 : (isSmallScreen ? 17 : 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          SizedBox(height: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14)),

          // Giriş yap butonu
          SizedBox(
            width: double.infinity,
            height: isVerySmallScreen ? 44 : (isSmallScreen ? 46 : 48),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: Text(
                'Zaten Üye Misin? Giriş Yap',
                style: TextStyle(
                  fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _colorAnimation.value,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.music_note,
                    size: 40,
                    color: Colors.black,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 20),
          Text(
            'Müzikler Yükleniyor...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
