// lib/top10_music_card.dart dosyasını tamamen değiştirin

import 'package:flutter/material.dart';
import 'common_music_player.dart';

class Top10MusicCard extends StatelessWidget {
  final List<Map<String, dynamic>> topMusics;
  final String? userId;

  const Top10MusicCard({
    Key? key,
    required this.topMusics,
    this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (topMusics.isEmpty) {
      return SizedBox.shrink(); // Boş ise hiçbir şey gösterme
    }

    return Column(
      children: topMusics.map((music) {
        return CommonMusicPlayer(
          key: ValueKey('top10_${music['_id']}'),
          track: music,
          userId: userId,
          lazyLoad: false,
        );
      }).toList(),
    );
  }
}