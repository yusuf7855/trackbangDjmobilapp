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
      backgroundColor: Colors.black, // Arka plan siyah
      appBar: AppBar(
        backgroundColor: Colors.black, // AppBar arka planını da siyah yap
        title: Image.asset(
          'assets/your_logo.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        elevation: 0, // Gölge efektini kaldır (isteğe bağlı)
      ),
      body: _allLoaded ? _buildContent() : _buildLoadingAnimation(),
    );
  }

  Widget _buildLoadingAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Text(
                  'B',
                  style: TextStyle(
                      color: _colorAnimation.value,
                      fontSize: 96, // Increased from 72 to 96
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      shadows: [
                  Shadow(
                  color: Colors.white.withOpacity(0.7),
                  blurRadius: 15, // Increased blur
                  offset: Offset(0, 0),
                  )
                  ],
                ),
              ),
              );
            },
          ),
          SizedBox(height: 30),
          Text(
            'İçerikler Yükleniyor...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18, // Slightly larger text
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return _buildTrackCard(track);
            },
          ),
        ),
        _buildBottomSection(),
      ],
    );
  }

  Widget _buildTrackCard(Map<String, String> track) {
    final controller = _controllerCache[track['id']];

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: WebViewWidget(controller: controller!),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Tüm İçeriklere Erişebilmek İçin Sadece 10€/ay Abone Ol',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: Text(
                'Giriş Yap',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controllerCache.clear();
    super.dispose();
  }
}