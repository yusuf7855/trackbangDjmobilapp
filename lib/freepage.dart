import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Scale animation with larger range
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Color animation with more contrast
    _colorAnimation = ColorTween(
      begin: Colors.white.withOpacity(0.8),
      end: Colors.white,
    ).animate(_animationController);

    _preloadWebViews();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Image.asset(
          'assets/your_logo.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _allLoaded ? _buildLoadedContent() : _buildLoadingContent(),
    );
  }

  Widget _buildLoadedContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 20),
                // Spotify Web View'ları
                ...tracks.map((track) => _buildSpotifyEmbed(track['id']!)).toList(),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
        // Safe Area ile bottom section
        SafeArea(
          child: _buildBottomSection(),
        ),
      ],
    );
  }

  Widget _buildLoadingContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Icon(
                  Icons.music_note,
                  size: 60,
                  color: _colorAnimation.value,
                ),
              );
            },
          ),
          SizedBox(height: 20),
          Text(
            'Yükleniyor...',
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

  Widget _buildSpotifyEmbed(String trackId) {
    final controller = _controllerCache[trackId];
    if (controller == null) return SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        // Responsive height calculation
        double frameHeight;
        if (screenHeight < 600) {
          frameHeight = 90; // Very small screens
        } else if (screenHeight < 700) {
          frameHeight = 100; // Small screens
        } else {
          frameHeight = 110; // Normal screens
        }

        // Responsive horizontal margin
        double horizontalMargin = screenWidth * 0.05; // 5% of screen width

        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: horizontalMargin.clamp(16.0, 24.0), // Min 16, Max 24
            vertical: 0,
          ),
          height: frameHeight,
          child: WebViewWidget(controller: controller),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenHeight < 700;
        final isVerySmallScreen = screenHeight < 600;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.06, // %6 padding
            vertical: isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 20),
          ),
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
              // Ana metin
              Text(
                'Tüm İçeriklere Erişebilmek İçin Sadece 4€/ay Abone Ol',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              SizedBox(height: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20)),

              // Butonlar için responsive aralık
              Column(
                children: [
                  // Hemen Kayıt Ol butonu
                  SizedBox(
                    width: double.infinity,
                    height: isVerySmallScreen ? 44 : (isSmallScreen ? 48 : 52),
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
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: Text(
                        'Hemen Kayıt Ol',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 16 : (isSmallScreen ? 17 : 18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14)),

                  // Giriş Yap butonu
                  SizedBox(
                    width: double.infinity,
                    height: isVerySmallScreen ? 44 : (isSmallScreen ? 48 : 52),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: Text(
                        'Giriş Yap',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 16 : (isSmallScreen ? 17 : 18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom padding - safe area'dan dolayı az
              SizedBox(height: isVerySmallScreen ? 8 : 10),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controllerCache.clear();
    super.dispose();
  }
}