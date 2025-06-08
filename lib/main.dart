import 'package:djmobilapp/profile.dart';
import 'package:djmobilapp/register_page.dart';
import 'package:djmobilapp/search_screen.dart';
import 'package:djmobilapp/hot_page.dart';
import 'package:djmobilapp/menu/listeler_screen.dart'; // YENİ IMPORT EKLENDİ
import 'package:djmobilapp/menu/sample_bank_screen.dart'; // YENİ IMPORT EKLENDİ
import 'package:djmobilapp/menu/mostening_screen.dart'; // YENİ IMPORT EKLENDİ
import 'package:djmobilapp/menu/magaza_screen.dart'; // YENİ IMPORT EKLENDİ
import 'package:djmobilapp/menu/biz_kimiz_screen.dart'; // YENİ IMPORT EKLENDİ
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
        '/register': (context) => RegisterPage(),
        '/home': (context) => MainHomePage(),
        '/profile': (context) => ProfileScreen(),
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

  // Scaffold key'i drawer kontrolü için
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserId();

    // HomeScreen'e drawer'ı açma fonksiyonunu geçiyoruz
    _pages = [
      HomeScreen(onMenuPressed: _openDrawer),
      SearchScreen(),
      MyBangsScreen(),
      ProfileScreen(),
    ];

    debugPrint('MainHomePage initialized');
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
          (Route<dynamic> route) => false,
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
        key: _scaffoldKey, // Scaffold key eklendi
        backgroundColor: Colors.black,
        appBar: _buildAppBar(),
        drawer: _currentIndex == 0 ? _buildDrawer() : null, // Sadece ana sayfada drawer göster
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    // HomeScreen kendi AppBar'ını yönetsin
    if (_currentIndex == 0) return null;

    String title;
    switch (_currentIndex) {
      case 1: title = 'Ara'; break;
      case 2: title = 'My Bangs'; break;
      case 3: title = 'Profile'; break;
      default: title = 'App';
    }

    return AppBar(
      title: Text(
        title,
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
      actions: [
        if (_currentIndex == 3) // Only show logout on profile page
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
      ],
    );
  }

  // DÜZELTİLEN DRAWER
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.black,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.grey[900],
            ),
            child: Image.asset(
              'assets/your_logo.png',
              height: 60,
              fit: BoxFit.contain,
            ),
          ),
          // DÜZELTİLEN KISIM: Tüm navigation işlemleri eklendi
          _buildDrawerItem(
            icon: Icons.list,
            title: 'Listeler',
            onTap: () {
              Navigator.pop(context); // Drawer'ı kapat
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ListelerScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.library_music,
            title: 'Samplebank',
            onTap: () {
              Navigator.pop(context); // Drawer'ı kapat
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SampleBankScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.headset,
            title: 'Mostening',
            onTap: () {
              Navigator.pop(context); // Drawer'ı kapat
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MosteningScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.store,
            title: 'Mağaza',
            onTap: () {
              Navigator.pop(context); // Drawer'ı kapat
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MagazaScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.info,
            title: 'Biz Kimiz',
            onTap: () {
              Navigator.pop(context); // Drawer'ı kapat
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BizKimizScreen()),
              );
            },
          ),
          Divider(color: Colors.grey[700]),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Çıkış Yap',
            onTap: () async {
              Navigator.pop(context);
              await _logout();
            },
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
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Colors.transparent,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          iconSize: 28,
          selectedFontSize: 12,
          unselectedFontSize: 10,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Ara',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              label: 'My Bangs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}