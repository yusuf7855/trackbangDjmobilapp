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
      return SizedBox.shrink();
    }

    return Column(
      children: topMusics.asMap().entries.map((entry) {
        final index = entry.key;
        final music = entry.value;

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sol taraftaki sıra numarası - minyon ve modern
              Container(
                width: 32,
                height: 32,
                margin: EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[800]?.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey[600]?.withOpacity(0.3) ?? Colors.grey,
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),

              // Şarkı player'ı - genişletilmiş alan
              Expanded(
                child: CommonMusicPlayer(
                  key: ValueKey('top10_${music['_id']}_${index}'),
                  track: music,
                  userId: userId,
                  lazyLoad: false,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}