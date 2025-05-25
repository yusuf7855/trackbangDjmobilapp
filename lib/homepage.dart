import 'package:flutter/material.dart';
import 'package:djmobilapp/music_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'menu/biz_kimiz_screen.dart';
import 'menu/listeler_screen.dart';
import 'menu/magaza_screen.dart';
import 'menu/mostening_screen.dart';
import 'menu/sample_bank_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),

                Image.asset(
                  'assets/your_logo.png',
                  height: 40, // Adjusted logo height
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_none, color: Colors.white),
                  onPressed: () {
                    // Notification action
                  },
                ),
                IconButton(
                  icon: Icon(Icons.message_outlined, color: Colors.white),
                  onPressed: () {
                    // DM action
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: Colors.black,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey[900],
                      child: Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Kullanıcı Adı',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'userr@example.com',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.list_alt_rounded,
              title: 'Listeler',
              page: ListelerScreen(),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.library_music_rounded,
              title: 'Sample Bank',
              page: SampleBankScreen(),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.headset_rounded,
              title: 'Mostening',
              page: MosteningScreen(),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.shopping_bag_rounded,
              title: 'Mağaza',
              page: MagazaScreen(),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.info_outline_rounded,
              title: 'Biz Kimiz',
              page: BizKimizScreen(),
            ),
            Divider(color: Colors.white.withOpacity(0.1)),
            _buildDrawerItem(
              context,
              icon: Icons.settings_rounded,
              title: 'Ayarlar',
              page: Container(), // Replace with your settings screen
            ),
            _buildDrawerItem(
              context,
              icon: Icons.logout_rounded,
              title: 'Çıkış Yap',
              page: Container(), // Replace with your logout logic
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.grey[900]!,
            ],
          ),
        ),
        child: Column(
          children: [
            // Search bar would go here if needed
            Expanded(
              child: MusicScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String title, required Widget page}) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () async {
        Navigator.pop(context);

        if (title == 'Çıkış Yap') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear(); // Tüm verileri temizle

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
                (Route<dynamic> route) => false,
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        }
      },
      hoverColor: Colors.white.withOpacity(0.1),
      focusColor: Colors.white.withOpacity(0.1),
      splashColor: Colors.white.withOpacity(0.1),
    );
  }
}