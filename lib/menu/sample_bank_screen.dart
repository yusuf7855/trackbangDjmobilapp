import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';

import '../url_constants.dart';

class SampleBankScreen extends StatefulWidget {
  @override
  _SampleBankScreenState createState() => _SampleBankScreenState();
}

class _SampleBankScreenState extends State<SampleBankScreen> {
  final Dio _dio = Dio();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isDownloading = false;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  List<dynamic> _samples = [];
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();

  // Audio player states
  String? _currentPlayingId;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Filter states
  String _selectedGenre = 'All';
  String _selectedPriceFilter = 'All';
  List<String> _genres = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchSamples();
    _scrollController.addListener(_scrollListener);
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioPlayer.dispose();
    _dio.close();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.durationStream.listen((Duration? d) {
      if (d != null) {
        setState(() => _duration = d);
      }
    });

    _audioPlayer.positionStream.listen((Duration p) {
      setState(() => _position = p);
    });

    _audioPlayer.playerStateStream.listen((PlayerState state) {
      setState(() => _isPlaying = state.playing);
    });

    _audioPlayer.processingStateStream.listen((ProcessingState state) {
      if (state == ProcessingState.completed) {
        setState(() {
          _currentPlayingId = null;
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.offset <= _scrollController.position.minScrollExtent &&
        !_scrollController.position.outOfRange) {
      _fetchSamples();
    }
  }

  Future<void> _fetchSamples() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final response = await _dio.get('${UrlConstants.apiBaseUrl}/api/samples');
      if (response.data is List) {
        setState(() {
          _samples = response.data;
          _isRefreshing = false;

          // Extract unique genres
          _genres = ['All'];
          Set<String> genreSet = {'All'};
          for (var sample in _samples) {
            String genre = sample['genre']?.toString() ?? 'Unknown';
            genreSet.add(genre);
          }
          _genres = genreSet.toList();
        });
      }
    } catch (e) {
      _showErrorNotification('Örnekler yüklenirken hata: ${e.toString()}');
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  List<dynamic> get _filteredSamples {
    return _samples.where((sample) {
      bool genreMatch = _selectedGenre == 'All' ||
          sample['genre']?.toString() == _selectedGenre;

      bool priceMatch = true;
      if (_selectedPriceFilter == 'Free') {
        priceMatch = sample['price'] == 0 || sample['price'] == null;
      } else if (_selectedPriceFilter == 'Paid') {
        priceMatch = sample['price'] != null && sample['price'] > 0;
      }

      return genreMatch && priceMatch;
    }).toList();
  }

  Future<void> _playDemo(String? demoUrl, String sampleId) async {
    if (demoUrl == null || demoUrl.isEmpty) {
      _showErrorNotification('Demo dosyası bulunamadı');
      return;
    }

    try {
      if (_currentPlayingId == sampleId && _isPlaying) {
        await _audioPlayer.pause();
      } else if (_currentPlayingId == sampleId && !_isPlaying) {
        await _audioPlayer.play();
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(demoUrl);
        await _audioPlayer.play();
        setState(() {
          _currentPlayingId = sampleId;
        });
      }
    } catch (e) {
      _showErrorNotification('Demo oynatılırken hata: ${e.toString()}');
    }
  }

  Future<void> _downloadMainContent(String sampleId) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      _showProgressNotification('İndirme başlatılıyor...');

      final tokenResponse = await _dio.post(
        '${UrlConstants.apiBaseUrl}/api/samples/download/generate',
        data: {'sampleId': sampleId},
      );

      if (tokenResponse.data['error'] != null) {
        throw Exception(tokenResponse.data['error']);
      }

      final downloadUrl = tokenResponse.data['downloadUrl'] as String;
      final fileName = tokenResponse.data['fileName'] as String;

      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status != PermissionStatus.granted) {
          throw Exception('Depolama izni reddedildi');
        }
      }

      final Directory dir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final String filePath = "${dir.path}/$fileName";

      await _dio.download(downloadUrl, filePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              double progress = (received / total) * 100;
              _showProgressNotification('İndiriliyor... ${progress.toStringAsFixed(0)}%');
            }
          }
      );

      _showSuccessNotification('İndirme Tamamlandı!', filePath);

    } on DioException catch (e) {
      final errorMessage = e.response?.data?['error']?.toString() ??
          e.message?.toString() ?? 'Bilinmeyen hata';
      _showErrorNotification('İndirme hatası: $errorMessage');
    } catch (e) {
      _showErrorNotification('İndirme hatası: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Color _getGenreColor(String? genre) {
    switch (genre?.toLowerCase()) {
      case 'house':
        return Colors.purple[600]!;
      case 'techno':
        return Colors.red[600]!;
      case 'trap':
        return Colors.orange[600]!;
      case 'hip hop':
        return Colors.amber[600]!;
      case 'electronic':
        return Colors.blue[600]!;
      case 'ambient':
        return Colors.teal[600]!;
      case 'pop':
        return Colors.pink[600]!;
      case 'rock':
        return Colors.brown[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildSampleCard(Map<String, dynamic> sample) {
    final String sampleId = sample['_id']?.toString() ?? sample['id']?.toString() ?? '';
    final String title = sample['title']?.toString() ?? sample['name']?.toString() ?? 'İsimsiz';
    final String genre = sample['genre']?.toString() ?? 'Kategorisiz';
    final double price = (sample['price'] ?? 0).toDouble();
    final String imageUrl = sample['imageUrl']?.toString() ?? '';
    final String? demoUrl = sample['demoUrl']?.toString();
    final bool isCurrentPlaying = _currentPlayingId == sampleId;
    final bool isDownloadable = sample['paymentStatus']?.toString() == 'free' ||
        sample['paymentStatus']?.toString() == 'paid';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[850]!, Colors.grey[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol taraf - Resim
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: imageUrl.isNotEmpty
                    ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) {
                    print('Image load error: $exception');
                  },
                )
                    : null,
                color: imageUrl.isEmpty ? Colors.grey[700] : null,
              ),
              child: imageUrl.isEmpty
                  ? Center(
                child: Icon(
                  Icons.music_note,
                  size: 40,
                  color: Colors.white54,
                ),
              )
                  : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(width: 16),

            // Sağ taraf - İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 8),

                  // Genre
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getGenreColor(genre),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      genre,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  SizedBox(height: 8),

                  // Fiyat
                  Text(
                    price == 0 ? 'Ücretsiz' : '\$${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: price == 0 ? Colors.green : Colors.amber,
                    ),
                  ),

                  SizedBox(height: 12),

                  // İstatistikler
                  if (sample['downloads'] != null || sample['views'] != null)
                    Row(
                      children: [
                        if (sample['downloads'] != null) ...[
                          Icon(Icons.download, color: Colors.grey[400], size: 16),
                          SizedBox(width: 4),
                          Text(
                            '${sample['downloads']}',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                          SizedBox(width: 12),
                        ],
                        if (sample['views'] != null) ...[
                          Icon(Icons.visibility, color: Colors.grey[400], size: 16),
                          SizedBox(width: 4),
                          Text(
                            '${sample['views']}',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                        ],
                      ],
                    ),

                  SizedBox(height: 16),

                  // Butonlar
                  Row(
                    children: [
                      // Demo oynatma butonu
                      if (demoUrl != null && demoUrl.isNotEmpty)
                        Expanded(
                          flex: 1,
                          child: ElevatedButton.icon(
                            onPressed: () => _playDemo(demoUrl, sampleId),
                            icon: Icon(
                              isCurrentPlaying && _isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 18,
                            ),
                            label: Text(
                              isCurrentPlaying && _isPlaying ? 'Duraklat' : 'Demo',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCurrentPlaying
                                  ? Colors.orange[600]
                                  : Colors.blue[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            ),
                          ),
                        ),

                      if (demoUrl != null && demoUrl.isNotEmpty) SizedBox(width: 8),

                      // İndirme butonu
                      Expanded(
                        flex: 1,
                        child: ElevatedButton.icon(
                          onPressed: _isDownloading || !isDownloadable
                              ? null
                              : () => _downloadMainContent(sampleId),
                          icon: _isDownloading
                              ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : Icon(Icons.download, size: 18),
                          label: Text(
                            _isDownloading ? 'İndiriliyor...' : 'İndir',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDownloadable
                                ? (price == 0 ? Colors.green[600] : Colors.orange[600])
                                : Colors.grey[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Audio progress bar
                  if (isCurrentPlaying && _duration.inSeconds > 0)
                    Column(
                      children: [
                        SizedBox(height: 8),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.blue[400],
                            inactiveTrackColor: Colors.grey[600],
                            thumbColor: Colors.blue[600],
                            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                            trackHeight: 2,
                          ),
                          child: Slider(
                            value: _position.inSeconds.toDouble(),
                            max: _duration.inSeconds.toDouble(),
                            onChanged: (value) async {
                              final position = Duration(seconds: value.toInt());
                              await _audioPlayer.seek(position);
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: TextStyle(color: Colors.grey[400], fontSize: 10),
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: TextStyle(color: Colors.grey[400], fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showProgressNotification(String message) {
    final scaffoldMessenger = _scaffoldMessengerKey.currentState;
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.download, color: Colors.white),
          SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessNotification(String message, String filePath) {
    final scaffoldMessenger = _scaffoldMessengerKey.currentState;
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Aç',
          textColor: Colors.white,
          onPressed: () => OpenFile.open(filePath),
        ),
      ),
    );
  }

  void _showErrorNotification(String message) {
    final scaffoldMessenger = _scaffoldMessengerKey.currentState;
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.error, color: Colors.white),
          SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(
            'Sample Bank',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.grey[900],
          iconTheme: IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _fetchSamples,
            ),
          ],
        ),
        body: Column(
          children: [
            // Filter Section
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.grey[850],
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGenre,
                      decoration: InputDecoration(
                        labelText: 'Genre',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                        ),
                      ),
                      dropdownColor: Colors.grey[800],
                      style: TextStyle(color: Colors.white),
                      items: _genres.map((genre) => DropdownMenuItem(
                        value: genre,
                        child: Text(genre),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGenre = value!;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedPriceFilter,
                      decoration: InputDecoration(
                        labelText: 'Fiyat',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                        ),
                      ),
                      dropdownColor: Colors.grey[800],
                      style: TextStyle(color: Colors.white),
                      items: ['All', 'Free', 'Paid'].map((filter) => DropdownMenuItem(
                        value: filter,
                        child: Text(filter == 'All' ? 'Hepsi' : filter == 'Free' ? 'Ücretsiz' : 'Ücretli'),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPriceFilter = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Sample List
            Expanded(
              child: _isRefreshing && _samples.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      'Sample\'lar yükleniyor...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
                  : _filteredSamples.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_off,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Sample bulunamadı',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Farklı filtreler deneyin',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                onRefresh: _fetchSamples,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _filteredSamples.length,
                  itemBuilder: (context, index) {
                    return _buildSampleCard(_filteredSamples[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}