import 'package:flutter/material.dart';

class BangLoading extends StatefulWidget {
  final String? loadingText;

  const BangLoading({Key? key, this.loadingText}) : super(key: key);

  @override
  _BangLoadingState createState() => _BangLoadingState();
}

class _BangLoadingState extends State<BangLoading> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

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
  }

  @override
  Widget build(BuildContext context) {
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
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      shadows: [
                  Shadow(
                  color: Colors.white.withOpacity(0.7),
                  blurRadius: 15,
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
            widget.loadingText ?? 'Yükleniyor...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}