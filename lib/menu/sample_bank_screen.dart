// lib/menu/sample_bank_screen.dart - Tam Fonksiyonel Versiyon
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:async';

import '../url_constants.dart';

class SampleBankScreen extends StatefulWidget {
  @override
  _SampleBankScreenState createState() => _SampleBankScreenState();
}

class _SampleBankScreenState extends State<SampleBankScreen>
    with TickerProviderStateMixin {
  final Dio _dio = Dio();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _animationController;
  late AnimationController _progressAnimationController;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadingItemId = '';

  List<dynamic> _samples = [];
  bool _isRefreshing = false;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  // Audio player states
  String? _currentPlayingId;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Filter states
  String _selectedGenre = 'Tümü';
  String _selectedPriceFilter = 'Tümü';
  List<String> _genres = ['Tümü'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Modern dark colors
  static const Color _primaryColor = Color(0xFF6B7280);
  static const Color _secondaryColor = Color(0xFF9CA3AF);
  static const Color _backgroundDark = Color(0xFF000000);
  static const Color _surfaceDark = Color(0xFF111827);
  static const Color _cardDark = Color(0xFF1F2937);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFF9CA3AF);
  static const Color _accentGreen = Color(0xFF10B981);
  static const Color _accentOrange = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _progressAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _fetchSamples();
    _scrollController.addListener(_scrollListener);
    _setupAudioPlayer();
    _animationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioPlayer.dispose();
    _dio.close();
    _animationController.dispose();
    _progressAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.durationStream.listen((Duration? duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.positionStream.listen((Duration position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (!state.playing) {
            _position = Duration.zero;
          }
        });
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // Load more samples if needed
    }
  }

  // URL BUILDER - Resim için optimize edilmiş
  String _buildImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';

    String baseUrl = UrlConstants.apiBaseUrl;
    String finalUrl = '';

    // Eğer URL zaten tam ise olduğu gibi kullan
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      finalUrl = imageUrl;

      // HTTPS'yi HTTP'ye çevir
      if (finalUrl.startsWith('https://')) {
        finalUrl = finalUrl.replaceFirst('https://', 'http://');
      }

      // localhost ve 127.0.0.1'i IP'ye çevir
      if (finalUrl.contains('localhost') || finalUrl.contains('127.0.0.1')) {
        finalUrl = finalUrl.replaceAll('localhost', '192.168.1.106');
        finalUrl = finalUrl.replaceAll('127.0.0.1', '192.168.1.106');
      }

      // Emulator IP'sini çevir
      if (finalUrl.contains('10.0.2.2')) {
        finalUrl = finalUrl.replaceAll('10.0.2.2', '192.168.1.106');
      }
    }
    // Eğer /uploads/ ile başlıyorsa base URL ekle
    else if (imageUrl.startsWith('/uploads/')) {
      finalUrl = '$baseUrl$imageUrl';
    }
    // Eğer sadece dosya adı ise /uploads/sample-images/ ekle
    else {
      finalUrl = '$baseUrl/uploads/sample-images/$imageUrl';
    }

    return finalUrl;
  }

  // DEMO URL BUILDER - Audio için optimize edilmiş
  String _buildDemoUrl(String demoUrl) {
    if (demoUrl.isEmpty) return '';

    String baseUrl = UrlConstants.apiBaseUrl;
    String finalUrl = '';

    // Eğer URL zaten tam ise olduğu gibi kullan
    if (demoUrl.startsWith('http://') || demoUrl.startsWith('https://')) {
      finalUrl = demoUrl;

      // HTTPS'yi HTTP'ye çevir
      if (finalUrl.startsWith('https://')) {
        finalUrl = finalUrl.replaceFirst('https://', 'http://');
      }

      // localhost ve 127.0.0.1'i IP'ye çevir
      if (finalUrl.contains('localhost') || finalUrl.contains('127.0.0.1')) {
        finalUrl = finalUrl.replaceAll('localhost', '192.168.1.106');
        finalUrl = finalUrl.replaceAll('127.0.0.1', '192.168.1.106');
      }

      // Emulator IP'sini çevir
      if (finalUrl.contains('10.0.2.2')) {
        finalUrl = finalUrl.replaceAll('10.0.2.2', '192.168.1.106');
      }
    }
    // Eğer /uploads/ ile başlıyorsa base URL ekle
    else if (demoUrl.startsWith('/uploads/')) {
      finalUrl = '$baseUrl$demoUrl';
    }
    // Eğer sadece dosya adı ise /uploads/sample-demos/ ekle
    else {
      finalUrl = '$baseUrl/uploads/sample-demos/$demoUrl';
    }

    return finalUrl;
  }

  // RESIM WIDGET - Error handling ile
  Widget _buildSampleImage(String imageUrl) {
    final String finalImageUrl = _buildImageUrl(imageUrl);

    if (finalImageUrl.isEmpty) {
      return _buildPlaceholderImage('Resim bulunamadı');
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _textSecondary.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          finalImageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;

            final progress = loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null;

            return Container(
              color: _cardDark,
              child: Center(
                child: CircularProgressIndicator(
                  color: _accentGreen,
                  value: progress,
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderImage('Yükleme hatası');
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(String message) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _textSecondary.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note,
            color: _textSecondary,
            size: 24,
          ),
          SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 8,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // SAMPLE FETCHİNG
  Future<void> _fetchSamples() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      if (_samples.isEmpty) _isLoading = true;
    });

    try {
      final response = await _dio.get('${UrlConstants.apiBaseUrl}/api/samples');

      if (response.statusCode == 200) {
        final List<dynamic> fetchedSamples = response.data ?? [];

        Set<String> genreSet = {'Tümü'};
        for (var sample in fetchedSamples) {
          final genre = sample['genre']?.toString();
          if (genre != null && genre.isNotEmpty) {
            genreSet.add(genre);
          }
        }

        if (mounted) {
          setState(() {
            _samples = fetchedSamples;
            _genres = genreSet.toList();
            _isLoading = false;
            _isRefreshing = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching samples: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        _showErrorSnackBar('Samples yüklenirken hata: ${e.toString()}');
      }
    }
  }

  Future<void> _refreshSamples() async {
    await _fetchSamples();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[600],
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _accentGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // FİLTRELEME
  List<dynamic> get _filteredSamples {
    return _samples.where((sample) {
      final genreMatch = _selectedGenre == 'Tümü' ||
          sample['genre']?.toString() == _selectedGenre;

      bool priceMatch = true;
      if (_selectedPriceFilter == 'Ücretsiz') {
        priceMatch = (sample['price'] ?? 0) == 0;
      } else if (_selectedPriceFilter == 'Ücretli') {
        priceMatch = (sample['price'] ?? 0) > 0;
      }

      final searchMatch = _searchQuery.isEmpty ||
          (sample['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (sample['genre']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      return genreMatch && priceMatch && searchMatch;
    }).toList();
  }

  // DEMO OYNATMA
  Future<void> _playDemo(String? demoUrl, String sampleId) async {
    if (demoUrl == null || demoUrl.isEmpty) {
      _showErrorSnackBar('Demo dosyası bulunamadı');
      return;
    }

    try {
      if (_currentPlayingId == sampleId && _isPlaying) {
        await _audioPlayer.pause();
      } else if (_currentPlayingId == sampleId && !_isPlaying) {
        await _audioPlayer.play();
      } else {
        await _audioPlayer.stop();

        String validUrl = _buildDemoUrl(demoUrl);
        print('Playing demo URL: $validUrl');

        await _audioPlayer.setUrl(validUrl);
        await _audioPlayer.play();

        if (mounted) {
          setState(() {
            _currentPlayingId = sampleId;
          });
        }
      }
    } catch (e) {
      print('Audio play error: $e');
      if (mounted) {
        _showErrorSnackBar('Demo oynatılırken hata: ${e.toString()}');
      }
    }
  }

  // İNDİRME FONKSİYONU
  Future<void> _downloadMainContent(String sampleId, String title) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadingItemId = sampleId;
      _downloadProgress = 0.0;
    });

    _progressAnimationController.forward();

    try {
      // İzin kontrolü
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            _showErrorSnackBar('Depolama izni gerekli');
            setState(() {
              _isDownloading = false;
              _downloadingItemId = '';
            });
            return;
          }
        }
      }

      // Token oluştur
      String tokenApiUrl = '${UrlConstants.apiBaseUrl}/api/samples/download/generate';

      print('Token API URL: $tokenApiUrl');

      final tokenResponse = await _dio.post(
        tokenApiUrl,
        data: {'sampleId': sampleId},
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception('Token oluşturulamadı: ${tokenResponse.statusMessage}');
      }

      final String token = tokenResponse.data['token'];
      print('Download token: $token');

      // İndirme URL'si
      String downloadUrl = '${UrlConstants.apiBaseUrl}/api/samples/download/$token';
      print('Download URL: $downloadUrl');

      // Dosya yolunu belirle
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('İndirme klasörü bulunamadı');
      }

      String fileName = '${title.replaceAll(RegExp(r'[^\w\s-]'), '')}.zip';
      String savePath = '${directory.path}/$fileName';

      print('Saving to: $savePath');

      // Dosyayı indir
      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            final progress = received / total;
            setState(() {
              _downloadProgress = progress;
            });
            print('Download progress: ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadingItemId = '';
          _downloadProgress = 0.0;
        });
        _progressAnimationController.reset();

        _showSuccessSnackBar('İndirme tamamlandı: $fileName');

        // Dosyayı aç
        if (Platform.isAndroid) {
          try {
            await OpenFile.open(savePath);
          } catch (e) {
            print('File open error: $e');
            // Hata gösterme opsiyonel
          }
        }
      }

    } catch (e) {
      print('Download error: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadingItemId = '';
          _downloadProgress = 0.0;
        });
        _progressAnimationController.reset();
        _showErrorSnackBar('İndirme hatası: ${e.toString()}');
      }
    }
  }

  // SAMPLE CARD WIDGET
  Widget _buildSampleCard(Map<String, dynamic> sample) {
    final String sampleId = sample['_id']?.toString() ?? sample['id']?.toString() ?? '';
    final String title = sample['title']?.toString() ?? sample['name']?.toString() ?? 'İsimsiz';
    final String genre = sample['genre']?.toString() ?? 'Kategorisiz';
    final double price = (sample['price'] ?? 0).toDouble();
    final String imageUrl = sample['imageUrl']?.toString() ?? '';
    final String? demoUrl = sample['demoUrl']?.toString();
    final bool isCurrentPlaying = _currentPlayingId == sampleId;
    final bool isDownloadable = sample['paymentStatus']?.toString() == 'free' ||
        sample['paymentStatus']?.toString() == 'paid' || price == 0;
    final bool isDownloadingThis = _downloadingItemId == sampleId && _isDownloading;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrentPlaying
              ? [_cardDark, _surfaceDark]
              : [Color(0xFF1A1A1A), _cardDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isCurrentPlaying ? Colors.grey.withOpacity(0.3) : Colors.black54,
            blurRadius: isCurrentPlaying ? 15 : 10,
            offset: Offset(0, 5),
          ),
        ],
        border: isCurrentPlaying
            ? Border.all(color: _accentGreen.withOpacity(0.5), width: 2)
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Resim
            _buildSampleImage(imageUrl),

            SizedBox(width: 16),

            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık ve genre
                  Text(
                    title,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getGenreColor(genre).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getGenreColor(genre).withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      genre,
                      style: TextStyle(
                        color: _getGenreColor(genre),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),

                  // Fiyat
                  Text(
                    price == 0 ? 'Ücretsiz' : '₺${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: price == 0 ? _accentGreen : _accentOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  // Progress bar (eğer bu sample oynatılıyorsa)
                  if (isCurrentPlaying && _duration.inMilliseconds > 0)
                    Column(
                      children: [
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _position.inMilliseconds / _duration.inMilliseconds,
                          backgroundColor: _textSecondary.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(_accentGreen),
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(color: _textSecondary, fontSize: 10),
                            ),
                            Text(
                              '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(color: _textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Aksiyon butonları
            Column(
              children: [
                // Play/Pause button
                if (demoUrl != null && demoUrl.isNotEmpty)
                  GestureDetector(
                    onTap: () => _playDemo(demoUrl, sampleId),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isCurrentPlaying && _isPlaying
                              ? [_accentGreen, _accentGreen.withOpacity(0.7)]
                              : [_surfaceDark, _cardDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: isCurrentPlaying ? _accentGreen.withOpacity(0.3) : Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isCurrentPlaying && _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: _textPrimary,
                        size: 24,
                      ),
                    ),
                  ),

                SizedBox(height: 8),

                // Download button
                if (isDownloadable)
                  GestureDetector(
                    onTap: isDownloadingThis ? null : () => _downloadMainContent(sampleId, title),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDownloadingThis
                              ? [_accentOrange, _accentOrange.withOpacity(0.7)]
                              : [_surfaceDark, _cardDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: isDownloadingThis ? _accentOrange.withOpacity(0.3) : Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isDownloadingThis
                          ? Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _downloadProgress,
                            color: _textPrimary,
                            strokeWidth: 2,
                          ),
                          Text(
                            '${(_downloadProgress * 100).toInt()}%',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                          : Icon(
                        Icons.download,
                        color: _textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getGenreColor(String? genre) {
    switch (genre?.toLowerCase()) {
      case 'house':
        return Colors.purple[400]!;
      case 'techno':
        return Colors.red[400]!;
      case 'trap':
        return Colors.orange[400]!;
      case 'hip hop':
        return Colors.amber[400]!;
      case 'electronic':
        return Colors.blue[400]!;
      case 'ambient':
        return Colors.teal[400]!;
      case 'pop':
        return Colors.pink[400]!;
      case 'rock':
        return Colors.brown[400]!;
      default:
        return _textSecondary;
    }
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 1200),
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _cardDark,
              _surfaceDark,
              _cardDark,
            ],
            stops: [0.0, 0.5, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.grey[800]!.withOpacity(0.8),
                Colors.grey[700]!.withOpacity(0.3),
                Colors.grey[800]!.withOpacity(0.8),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  // FİLTRE CHIPS
  Widget _buildFilterChips() {
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Genre Filter
          Expanded(
            child: GestureDetector(
              onTap: _showGenreSelector,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _surfaceDark,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: _textSecondary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedGenre,
                      style: TextStyle(color: _textPrimary, fontSize: 14),
                    ),
                    Icon(Icons.arrow_drop_down, color: _textSecondary),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(width: 12),

          // Price Filter
          Expanded(
            child: GestureDetector(
              onTap: _showPriceSelector,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _surfaceDark,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: _textSecondary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedPriceFilter,
                      style: TextStyle(color: _textPrimary, fontSize: 14),
                    ),
                    Icon(Icons.arrow_drop_down, color: _textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // GENRE SELECTOR
  void _showGenreSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kategori Seçin',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ..._genres.map((genre) {
                final isSelected = genre == _selectedGenre;
                return ListTile(
                  title: Text(
                    genre,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.white : _textSecondary,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedGenre = genre;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // PRICE SELECTOR
  void _showPriceSelector() {
    final priceOptions = ['Tümü', 'Ücretsiz', 'Ücretli'];

    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fiyat Filtresi',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ...priceOptions.map((option) {
                final isSelected = option == _selectedPriceFilter;
                return ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.white : _textSecondary,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedPriceFilter = option;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // ANA UI BUILD METHOD
  @override
  Widget build(BuildContext context) {
    final filteredSamples = _filteredSamples;

    return Scaffold(
      backgroundColor: _backgroundDark,
      appBar: AppBar(
        backgroundColor: _backgroundDark,
        elevation: 0,
        title: Text(
          'Sample Bank',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _textPrimary),
            onPressed: _refreshSamples,
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama çubuğu
          Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceDark,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: _textPrimary),
              decoration: InputDecoration(
                hintText: 'Sample ara...',
                hintStyle: TextStyle(color: _textSecondary),
                prefixIcon: Icon(Icons.search, color: _textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: _textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Filtre çipleri
          _buildFilterChips(),

          SizedBox(height: 8),

          // Ana içerik
          Expanded(
            child: _isLoading
                ? ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) => _buildShimmerCard(),
            )
                : filteredSamples.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_off,
                    size: 64,
                    color: _textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _samples.isEmpty
                        ? 'Henüz sample yüklenmemiş'
                        : 'Filtreye uygun sample bulunamadı',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshSamples,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text('Yenile'),
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _refreshSamples,
              color: _accentGreen,
              backgroundColor: _surfaceDark,
              child: ListView.builder(
                controller: _scrollController,
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: filteredSamples.length,
                itemBuilder: (context, index) {
                  return _buildSampleCard(filteredSamples[index]);
                },
              ),
            ),
          ),
        ],
      ),
      // Floating Action Button - Currently playing info
      floatingActionButton: _currentPlayingId != null
          ? Container(
        width: 60,
        height: 60,
        child: FloatingActionButton(
          backgroundColor: _accentGreen,
          onPressed: () {
            if (_isPlaying) {
              _audioPlayer.pause();
            } else {
              _audioPlayer.play();
            }
          },
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 200),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              key: ValueKey(_isPlaying),
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      )
          : null,
    );
  }
}