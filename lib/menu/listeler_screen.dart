import 'package:djmobilapp/menu/pages/CategoryPage.dart';
import 'package:flutter/material.dart';
import './pages/CategoryPage.dart';

class ListelerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final buttonHeight = screenHeight / 7;

    return Scaffold(
      appBar: AppBar(
        title: Text('Listeler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: 28,
        ),
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildImageListButton(
              context,
              buttonHeight,
              'assets/afra.jpeg',
              'afrahouse',
              'Afro House',
            ),
            SizedBox(height: 20),
            _buildImageListButton(
              context,
              buttonHeight,
              'assets/indie.jpg',
              'indiedance',
              'Indie Dance',
            ),
            SizedBox(height: 20),
            _buildImageListButton(
              context,
              buttonHeight,
              'assets/organic.jpeg',
              'organichouse',
              'Organic House',
            ),
            SizedBox(height: 20),
            _buildImageListButton(
              context,
              buttonHeight,
              'assets/down.jpg',
              'downtempo',
              'Down Tempo',
            ),
            SizedBox(height: 20),
            _buildImageListButton(
              context,
              buttonHeight,
              'assets/melodic.jpg',
              'melodichouse',
              'Melodic House',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageListButton(
      BuildContext context,
      double height,
      String imagePath,
      String category,
      String title,
      ) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryPage(category: category, title: title),
              ),
            );
          },
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(imagePath),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.3),
                      BlendMode.darken,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(height * 0.1),
                ),
              ),
            ],
          ),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.transparent),
            elevation: MaterialStateProperty.resolveWith<double>(
                  (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered)) return 10;
                if (states.contains(MaterialState.pressed)) return 5;
                return 6;
              },
            ),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(height * 0.1),
              ),
            ),
            overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.15)),
            padding: MaterialStateProperty.all(EdgeInsets.zero),
            animationDuration: Duration(milliseconds: 200),
            shadowColor: MaterialStateProperty.all(Colors.black.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }
}