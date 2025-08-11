// lib/main.dart - Orijinal yapı + Yeni Payment Service ile uyumlu

import 'package:djmobilapp/profile.dart';
import 'package:djmobilapp/register_page.dart';
import 'package:djmobilapp/search_screen.dart';
import 'package:djmobilapp/hot_page.dart';
import 'package:djmobilapp/menu/listeler_screen.dart';
import 'package:djmobilapp/menu/sample_bank_screen.dart';
import 'package:djmobilapp/menu/mostening_screen.dart';
import 'package:djmobilapp/menu/magaza_screen.dart';
import 'package:djmobilapp/menu/biz_kimiz_screen.dart';
import 'package:djmobilapp/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase ve bildirim import'ları
import 'package:firebase_core/firebase_core.dart';
import './firebase_options.dart';
import './services/notification_permission_service.dart';
import 'package:dio/dio.dart';

import 'conversations_screen.dart';
import 'freepage.dart';
import 'homepage.dart';
import 'login_page.dart';
import 'myBang.dart';

// Global navigator key for controlling navigation stack
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class LoadingProvider extends ChangeNotifier {
  bool _isLoading = false;
  String _loadingText = 'Yükleniyor...';

  bool get isLoading => _isLoading;
  String get loadingText => _loadingText;

  void startLoading([String text = 'Yükleniyor...']) {
    _isLoading = true;
    _loadingText = text;
    notifyListeners();
  }

  void stopLoading() {
    _isLoading = false;
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i başlat
  print('🔥 Firebase başlatılıyor...');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase başarıyla başlatıldı!');
  } catch (e) {
    print('❌ Firebase başlatma hatası: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => LoadingProvider(),
      child: MyApp(initialRoute: '/'),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({Key? key, required this.initialRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      initialRoute: initialRoute,
      routes: {
        '/': (context) => FreePage(),
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(), // Yeni RegisterPage - direkt abonelik ile
        '/home': (context) => MainHomePage(),
        '/profile': (context) => ProfileScreen(),
        '/notifications': (context) => NotificationsScreen(),
        '/conversations': (context) => ConversationsScreen(),
      },
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.black,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class MainHomePage extends StatefulWidget {
  @override
  _MainHomePageState createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  int _currentIndex = 0;
  String? userId;
  int unreadNotificationCount = 0;

  // Scaffold key'i drawer kontrolü için
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _initializePages();

    // Bildirim izni kontrolü
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPermission();
    });

    debugPrint('MainHomePage initialized');
  }

  // Pages initialization metodu - DOĞRU sınıf adları ile
  void _initializePages() {
    _pages = [
      HomeScreen( // homepage.dart -> HomeScreen sınıfı
        onMenuPressed: _openDrawer,
        unreadNotificationCount: unreadNotificationCount,
        onNotificationPressed: _handleNotificationPressed,
      ),
      SearchPage(), // Custom search widget (mevcut değilse)
      MyBangsScreen(), // myBang.dart -> MyBangsScreen sınıfı
      ProfileScreen(), // profile.dart -> ProfileScreen sınıfı
    ];
  }

  // Bildirim izni kontrol metodu
  void _checkNotificationPermission() async {
    // 2 saniye bekle ki uygulama tam yüklensin
    await Future.delayed(Duration(seconds: 2));

    if (mounted) {
      try {
        await NotificationPermissionService.checkAndRequestPermission(context);
      } catch (e) {
        print('❌ Bildirim izni hatası: $e');
      }
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId') ?? prefs.getString('user_id');
    });
  }

  // Drawer'ı açma fonksiyonu
  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  // Bildirim basma işlevi - NotificationsScreen'e yönlendir
  void _handleNotificationPressed() {
    print('📱 Bildirim butonuna basıldı - Bildirimler sayfasına yönlendiriliyor');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  // FCM Debug Test
  Future<void> _performFCMDebugTest() async {
    try {
      final dio = Dio();
      final response = await dio.post(
        'https://djapi.web.tr/api/send-test-notification',
        data: {'user_id': userId ?? 'test'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Test bildirim gönderildi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Test başarısız: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Custom SearchPage widget (eğer search_screen.dart yoksa veya hatalıysa)
  Widget SearchPage() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              'Arama Sayfası',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            SizedBox(height: 8),
            Text(
              'Müzik arama özelliği yakında...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.black,
        appBar: _buildAppBar(),
        drawer: _currentIndex == 0 ? _buildDrawer() : null,
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_currentIndex == 0) {
      return null; // Home screen kendi AppBar'ını yönetir
    }

    String title;
    switch (_currentIndex) {
      case 1:
        title = 'Ara';
        break;
      case 2:
        title = 'My Bangs';
        break;
      case 3:
        title = 'Profil';
        break;
      default:
        title = '';
    }

    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      title: Text(
        title,
        style: TextStyle(color: Colors.white),
      ),
      iconTheme: IconThemeData(color: Colors.white),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.grey[900],
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.black,
            ),
            child: Row(
              children: [
                // Logo varsa göster, yoksa app adı
                Text(
                  'DJMobil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.list,
                  title: 'Listeler',
                  onTap: () {
                    Navigator.pop(context);
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ListelerScreen()),
                      );
                    } catch (e) {
                      _showMessage('Listeler sayfası henüz hazır değil');
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.library_music,
                  title: 'Sample Bank',
                  onTap: () {
                    Navigator.pop(context);
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SampleBankScreen()),
                      );
                    } catch (e) {
                      _showMessage('Sample Bank sayfası henüz hazır değil');
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.headset,
                  title: 'Mostening',
                  onTap: () {
                    Navigator.pop(context);
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MosteningScreen()),
                      );
                    } catch (e) {
                      _showMessage('Mostening sayfası henüz hazır değil');
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.store,
                  title: 'Mağaza',
                  onTap: () {
                    Navigator.pop(context);
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MagazaScreen()),
                      );
                    } catch (e) {
                      _showMessage('Mağaza sayfası henüz hazır değil');
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.info,
                  title: 'Biz Kimiz',
                  onTap: () {
                    Navigator.pop(context);
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => BizKimizScreen()),
                      );
                    } catch (e) {
                      _showMessage('Biz Kimiz sayfası henüz hazır değil');
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.notifications,
                  title: 'Bildirimler',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                    );
                  },
                ),
                Divider(color: Colors.grey[700]),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Çıkış Yap',
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: TextStyle(color: Colors.white),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Widget _buildBottomNavBar() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          border: Border(
            top: BorderSide(
              color: Colors.grey.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;

            // Responsive height calculation
            double navBarHeight;
            if (screenHeight < 600) {
              navBarHeight = 60; // Very small screens
            } else if (screenHeight < 700) {
              navBarHeight = 65; // Small screens
            } else {
              navBarHeight = 70; // Normal screens
            }

            // Responsive font and icon sizes
            double iconSize = screenWidth < 350 ? 24 : 26;
            double selectedFontSize = screenWidth < 350 ? 10 : 11;
            double unselectedFontSize = screenWidth < 350 ? 9 : 10;

            return SizedBox(
              height: navBarHeight,
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  bottomNavigationBarTheme: BottomNavigationBarThemeData(
                    backgroundColor: Colors.transparent,
                    selectedItemColor: Colors.white,
                    unselectedItemColor: Colors.grey[400],
                    elevation: 0,
                    type: BottomNavigationBarType.fixed,
                    selectedLabelStyle: TextStyle(
                      fontSize: selectedFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: unselectedFontSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  iconSize: iconSize,
                  selectedFontSize: selectedFontSize,
                  unselectedFontSize: unselectedFontSize,
                  onTap: (index) => setState(() => _currentIndex = index),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.home),
                      ),
                      label: 'Ana Sayfa',
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.search),
                      ),
                      label: 'Ara',
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.favorite_border),
                      ),
                      label: 'My Bangs',
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.person),
                      ),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Hata mesajları için yardımcı method
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }
}