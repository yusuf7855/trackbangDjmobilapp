import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'common_music_player.dart';

class Top10MusicCard extends StatefulWidget {
  final List<Map<String, dynamic>> topMusics;
  final String? userId;

  const Top10MusicCard({
    Key? key,
    required this.topMusics,
    this.userId,
  }) : super(key: key);

  @override
  State<Top10MusicCard> createState() => _Top10MusicCardState();
}

class _Top10MusicCardState extends State<Top10MusicCard>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  bool _isExpanded = false;
  List<Widget> _preloadedPlayers = [];
  bool _isPreloaded = false;

  // Çoklu sanatçı desteği için helper method
  String _getDisplayArtists(Map<String, dynamic> music) {
    // 1. displayArtists varsa onu kullan (backend'den gelen hazır format)
    if (music['displayArtists'] != null &&
        music['displayArtists'].toString().isNotEmpty) {
      return music['displayArtists'].toString();
    }

    // 2. artists array varsa onu birleştir
    if (music['artists'] != null &&
        music['artists'] is List &&
        (music['artists'] as List).isNotEmpty) {
      final artistsList = music['artists'] as List;
      return artistsList
          .where((artist) => artist != null && artist.toString().trim().isNotEmpty)
          .map((artist) => artist.toString().trim())
          .join(', ');
    }

    // 3. Eski tek sanatçı field'i varsa onu kullan (backward compatibility)
    if (music['artist'] != null &&
        music['artist'].toString().trim().isNotEmpty) {
      return music['artist'].toString().trim();
    }

    // 4. Hiçbiri yoksa default
    return 'Unknown Artist';
  }

  @override
  void initState() {
    super.initState();
    _preloadMusicPlayers();
  }

  Future<void> _preloadMusicPlayers() async {
    if (widget.topMusics.isEmpty || _isPreloaded) return;

    final preloadedList = <Widget>[];

    for (int i = 0; i < widget.topMusics.length && i < 5; i++) {
      final music = widget.topMusics[i];

      final player = CommonMusicPlayer(
        key: ValueKey('top10_${music['_id']}_$i'),
        track: music,
        userId: widget.userId,
        preloadWebView: true,
        lazyLoad: false,
      );

      preloadedList.add(player);

      // Small delay between preloads
      if (mounted) {
        await Future.delayed(Duration(milliseconds: 150));
      }
    }

    if (mounted) {
      setState(() {
        _preloadedPlayers = preloadedList;
        _isPreloaded = true;
      });
    }
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  Widget _buildTop3Preview() {
    final top3 = widget.topMusics.take(3).toList();

    return Column(
      children: top3.asMap().entries.map((entry) {
        final index = entry.key;
        final music = entry.value;
        final displayArtists = _getDisplayArtists(music);

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getRankColor(index + 1).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getRankColor(index + 1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),

              // Music info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      music['title'] ?? 'Unknown Title',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      displayArtists,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Likes and category
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, color: Colors.red, size: 12),
                      SizedBox(width: 4),
                      Text(
                        '${music['likes'] ?? 0}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (music['category'] != null) ...[
                    SizedBox(height: 2),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        music['category'],
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpandedView() {
    if (!_isExpanded) return SizedBox.shrink();

    return Column(
      children: [
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aşağıdaki player\'lar otomatik yüklenmiştir. Diğer şarkılar için "Player\'ı Yükle" butonuna tıklayın.',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),

        // Preloaded players (first 5)
        ..._preloadedPlayers,

        // Remaining players (lazy load)
        ...widget.topMusics.skip(_preloadedPlayers.length).toList().asMap().entries.map((entry) {
          final globalIndex = entry.key + _preloadedPlayers.length;
          final music = entry.value;

          return CommonMusicPlayer(
            key: ValueKey('top10_remaining_${music['_id']}_$globalIndex'),
            track: music,
            userId: widget.userId,
            lazyLoad: true,
          );
        }).toList(),
      ],
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // Gold
      case 2:
        return Colors.grey[400]!; // Silver
      case 3:
        return Colors.orange[700]!; // Bronze
      default:
        return Colors.blue;
    }
  }

  Widget _buildStatsRow() {
    final totalLikes = widget.topMusics.fold<int>(
      0,
          (sum, music) => sum + (music['likes'] ?? 0) as int,
    );

    final categories = widget.topMusics
        .where((music) => music['category'] != null)
        .map((music) => music['category'])
        .toSet()
        .length;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.music_note, '${widget.topMusics.length}', 'Şarkı'),
          _buildStatItem(Icons.favorite, '$totalLikes', 'Beğeni'),
          _buildStatItem(Icons.category, '$categories', 'Kategori'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.orange, size: 18),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.topMusics.isEmpty) {
      return Card(
        color: Colors.grey[900],
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.music_off, color: Colors.grey[600], size: 48),
              SizedBox(height: 12),
              Text(
                'Henüz Top 10 müzik bulunamadı',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.grey[900],
      margin: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top 10 En Beğenilen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'En çok beğenilen şarkılar',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Expand/Collapse button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleExpansion,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isExpanded
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isExpanded ? 'Kapat' : 'Tümünü Gör',
                            style: TextStyle(
                              color: _isExpanded ? Colors.orange : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: _isExpanded ? Colors.orange : Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Stats row
            _buildStatsRow(),

            SizedBox(height: 16),

            // Top 3 preview (always visible)
            _buildTop3Preview(),

            // Expanded view (remaining songs with players)
            _buildExpandedView(),

            // Loading indicator for preloaded players
            if (!_isPreloaded && _isExpanded) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Player\'lar hazırlanıyor...',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}