// lib/menu/sample_bank_screen.dart - Düzeltilmiş ve Modern Tasarım
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

  // WIDGET LIFECYCLE İÇİN GÜVENLİ SCAFFOLD MESSENGER
  ScaffoldMessengerState? _scaffoldMessenger;

  // Modern monochrome colors
  static const Color _backgroundColor = Color(0xFF000000);
  static const Color _surfaceColor = Color(0xFF1A1A1A);
  static const Color _cardColor = Color(0xFF2A2A2A);
  static const Color _primaryText = Color(0xFFFFFFFF);
  static const Color _secondaryText = Color(0xFF9E9E9E);
  static const Color _tertiaryText = Color(0xFF757575);
  static const Color _accentColor = Color(0xFF424242);
  static const Color _borderColor = Color(0xFF3A3A3A);

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Widget lifecycle için güvenli ScaffoldMessenger referansı
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    // Animation controller'ları önce durdur ve temizle
    try {
      _animationController.stop();
      _animationController.reset();
      _progressAnimationController.stop();
      _progressAnimationController.reset();
    } catch (e) {
      print('Animation controller dispose error: $e');
    }

    // Stream'leri temizle
    _scrollController.dispose();
    _audioPlayer.dispose();
    _searchController.dispose();

    // Animation controller'ları dispose et
    _animationController.dispose();
    _progressAnimationController.dispose();

    // Dio'yu kapat
    _dio.close();

    // ScaffoldMessenger referansını temizle
    _scaffoldMessenger = null;

    super.dispose();
  }

  // SETUP AUDIO PLAYER - Güvenli stream handling
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
          // DÜZELTME: Oynatma durdurulduğunda pozisyonu sıfırlamıyoruz
          // Bu, oynatma çubuğunun görünür kalmasını sağlar
        });
      }
    }).onError((error) {
      print('Audio player stream error: $error');
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // Load more samples if needed
    }
  }

  // SAMPLES FETCH - DÜZELTME
  Future<void> _fetchSamples() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      if (_samples.isEmpty) {
        _isLoading = true;
      }
    });

    try {
      final response = await _dio.get('${UrlConstants.apiBaseUrl}/api/samples');

      print('API Response Status: ${response.statusCode}');
      print('API Response Data: ${response.data}');

      if (response.statusCode == 200) {
        // API'den dönen veri yapısını kontrol et
        List<dynamic> fetchedSamples = [];

        if (response.data is Map<String, dynamic>) {
          // Eğer response.data bir map ise, samples array'ini al
          fetchedSamples = response.data['samples'] ?? response.data['data'] ?? [];
        } else if (response.data is List) {
          // Eğer response.data doğrudan bir liste ise
          fetchedSamples = response.data;
        } else {
          print('Unexpected response format: ${response.data.runtimeType}');
          fetchedSamples = [];
        }

        print('Fetched samples count: ${fetchedSamples.length}');

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

          print('Samples loaded: ${_samples.length}');
          print('Genres: $_genres');
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
    // Güvenli ScaffoldMessenger kullanımı
    if (mounted) {
      try {
        if (_scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.grey[800],
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Fallback: context üzerinden dene
          final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
          if (scaffoldMessenger != null) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.grey[800],
                duration: Duration(seconds: 3),
              ),
            );
          } else {
            print('Error message (no ScaffoldMessenger): $message');
          }
        }
      } catch (e) {
        print('SnackBar error: $e - Message: $message');
      }
    } else {
      print('Error message (not mounted): $message');
    }
  }

  void _showSuccessSnackBar(String message) {
    // Güvenli ScaffoldMessenger kullanımı
    if (mounted) {
      try {
        if (_scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: _accentColor,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Fallback: context üzerinden dene
          final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
          if (scaffoldMessenger != null) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: _accentColor,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            print('Success message (no ScaffoldMessenger): $message');
          }
        }
      } catch (e) {
        print('SnackBar error: $e - Message: $message');
      }
    } else {
      print('Success message (not mounted): $message');
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

  // DEMO OYNATMA - DÜZELTME
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

        // DÜZELTME: setState'i play() çağrısından önce yapıyoruz
        if (mounted) {
          setState(() {
            _currentPlayingId = sampleId;
            _position = Duration.zero; // Pozisyonu başlangıça çekiyoruz
          });
        }

        await _audioPlayer.play();
      }
    } catch (e) {
      print('Audio play error: $e');
      if (mounted) {
        _showErrorSnackBar('Demo oynatılırken hata: ${e.toString()}');
      }
    }
  }

  // İNDİRME FONKSİYONU - DÜZELTME
  Future<void> _downloadMainContent(String sampleId, String title) async {
    if (_isDownloading) return;

    // Boş değer kontrolü
    if (sampleId.isEmpty) {
      _showErrorSnackBar('Sample ID bulunamadı');
      return;
    }

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
      print('Sample ID: $sampleId');

      final tokenResponse = await _dio.post(
        tokenApiUrl,
        data: {'sampleId': sampleId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print('Token Response: ${tokenResponse.statusCode}');
      print('Token Data: ${tokenResponse.data}');

      if (tokenResponse.statusCode != 200 || tokenResponse.data == null) {
        throw Exception('Token oluşturulamadı: ${tokenResponse.statusMessage}');
      }

      // Token'ı farklı field'lardan dene
      String? token;
      if (tokenResponse.data is Map<String, dynamic>) {
        token = tokenResponse.data['token'] ??
            tokenResponse.data['downloadToken'] ??
            tokenResponse.data['access_token'];
      } else if (tokenResponse.data is String) {
        token = tokenResponse.data;
      }

      if (token == null || token.isEmpty) {
        throw Exception('Download token alınamadı');
      }

      print('Download token: $token');

      // İndirme URL'si
      String downloadUrl = '${UrlConstants.apiBaseUrl}/api/samples/download/$token';
      print('Download URL: $downloadUrl');

      // Dosya yolunu belirle
      Directory? directory;
      String fileName = '${title.replaceAll(RegExp(r'[^\w\s-.]'), '_')}.wav';

      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        if (directory != null) {
          String musicPath = '${directory.path}/Music';
          await Directory(musicPath).create(recursive: true);
          directory = Directory(musicPath);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Dosya dizini oluşturulamadı');
      }

      String filePath = '${directory.path}/$fileName';
      print('File path: $filePath');

      // Dosyayı indir
      await _dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
            print('Download progress: ${(_downloadProgress * 100).toStringAsFixed(1)}%');
          }
        },
        options: Options(
          headers: {
            'Accept': '*/*',
          },
        ),
      );

      _showSuccessSnackBar('İndirme tamamlandı: $fileName');

      // Dosyayı aç
      try {
        await OpenFile.open(filePath);
      } catch (e) {
        print('File open error: $e');
        // Dosya açma hatası kritik değil
      }

    } catch (e) {
      print('Download error: $e');
      String errorMessage = 'İndirme hatası';

      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          errorMessage = 'Sample bulunamadı';
        } else if (e.response?.statusCode == 401) {
          errorMessage = 'Yetki hatası';
        } else if (e.response?.statusCode == 500) {
          errorMessage = 'Sunucu hatası';
        } else {
          errorMessage = 'İndirme hatası: ${e.message}';
        }
      } else {
        errorMessage = 'İndirme hatası: ${e.toString()}';
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadingItemId = '';
          _downloadProgress = 0.0;
        });
      }
      _progressAnimationController.reverse();
    }
  }

  // URL BUILDER - Resim için optimize edilmiş
  String _buildImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';

    String baseUrl = UrlConstants.apiBaseUrl;
    String finalUrl = '';

    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      finalUrl = imageUrl;
      if (finalUrl.startsWith('https://')) {
        finalUrl = finalUrl.replaceFirst('https://', 'http://');
      }
      if (finalUrl.contains('localhost') || finalUrl.contains('127.0.0.1')) {
        finalUrl = finalUrl.replaceAll('localhost', '192.168.1.106');
        finalUrl = finalUrl.replaceAll('127.0.0.1', '192.168.1.106');
      }
      if (finalUrl.contains('10.0.2.2')) {
        finalUrl = finalUrl.replaceAll('10.0.2.2', '192.168.1.106');
      }
    } else if (imageUrl.startsWith('/uploads/')) {
      finalUrl = '$baseUrl$imageUrl';
    } else {
      finalUrl = '$baseUrl/uploads/sample-images/$imageUrl';
    }

    return finalUrl;
  }

  // DEMO URL BUILDER - Audio için optimize edilmiş
  String _buildDemoUrl(String demoUrl) {
    if (demoUrl.isEmpty) return '';

    String baseUrl = UrlConstants.apiBaseUrl;
    String finalUrl = '';

    if (demoUrl.startsWith('http://') || demoUrl.startsWith('https://')) {
      finalUrl = demoUrl;
      if (finalUrl.startsWith('https://')) {
        finalUrl = finalUrl.replaceFirst('https://', 'http://');
      }
      if (finalUrl.contains('localhost') || finalUrl.contains('127.0.0.1')) {
        finalUrl = finalUrl.replaceAll('localhost', '192.168.1.106');
        finalUrl = finalUrl.replaceAll('127.0.0.1', '192.168.1.106');
      }
      if (finalUrl.contains('10.0.2.2')) {
        finalUrl = finalUrl.replaceAll('10.0.2.2', '192.168.1.106');
      }
    } else if (demoUrl.startsWith('/uploads/')) {
      finalUrl = '$baseUrl$demoUrl';
    } else {
      finalUrl = '$baseUrl/uploads/sample-demos/$demoUrl';
    }

    return finalUrl;
  }

  // RESIM WIDGET - Büyük resim ve tam ekran özelliği ile
  Widget _buildSampleImage(String imageUrl) {
    final String finalImageUrl = _buildImageUrl(imageUrl);

    if (finalImageUrl.isEmpty) {
      return _buildPlaceholderImage('Resim bulunamadı');
    }

    return GestureDetector(
      onTap: () => _showFullScreenImage(finalImageUrl),
      child: Container(
        width: 120, // Daha büyük resim
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.network(
            finalImageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              final progress = loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null;
              return Center(
                child: CircularProgressIndicator(
                  value: progress,
                  valueColor: AlwaysStoppedAnimation<Color>(_secondaryText),
                  backgroundColor: _accentColor,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholderImage('Resim yüklenemedi');
            },
          ),
        ),
      ),
    );
  }

  // TAM EKRAN RESİM GÖSTERME
  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Resim yüklenemedi',
                          style: TextStyle(color: _secondaryText),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.close,
                    color: _primaryText,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(String text) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: _secondaryText, size: 32),
          SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(color: _tertiaryText, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getGenreColor(String genre) {
    switch (genre.toLowerCase()) {
      case 'trap':
        return _primaryText;
      case 'hip-hop':
        return _secondaryText;
      case 'drill':
        return _accentColor;
      case 'rnb':
        return _tertiaryText;
      default:
        return _secondaryText;
    }
  }

  // SAMPLE CARD WIDGET - Download butonu sabit konumda
  Widget _buildSampleCard(dynamic sample) {
    final String sampleId = sample['_id']?.toString() ?? '';
    final String title = sample['title']?.toString() ?? 'Başlık Yok';
    final String genre = sample['genre']?.toString() ?? 'Genre Yok';
    final String imageUrl = sample['imageUrl']?.toString() ?? '';
    final double price = (sample['price'] ?? 0).toDouble();
    String? demoUrl = sample['demoUrl']?.toString();
    final bool isCurrentPlaying = _currentPlayingId == sampleId;
    final bool isDownloadable = sample['paymentStatus']?.toString() == 'free' ||
        sample['paymentStatus']?.toString() == 'paid' || price == 0;
    final bool isDownloadingThis = _downloadingItemId == sampleId && _isDownloading;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol taraf - Resim
            _buildSampleImage(imageUrl),

            SizedBox(width: 16),

            // Orta - İçerik ve Progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Başlık
                  Text(
                    title,
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3),

                  // Genre
                  Text(
                    genre,
                    style: TextStyle(
                      color: _secondaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.05,
                    ),
                  ),
                  SizedBox(height: 2),

                  // Fiyat
                  Text(
                    price == 0 ? 'Ücretsiz' : '₺${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: price == 0 ? _primaryText : _tertiaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.05,
                    ),
                  ),

                  // Progress bar (sadece oynatılıyorsa)
                  if (isCurrentPlaying) ...[
                    SizedBox(height: 8),
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: _tertiaryText.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 2,
                            decoration: BoxDecoration(
                              color: _tertiaryText.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          if (_duration.inMilliseconds > 0)
                            FractionallySizedBox(
                              widthFactor: _position.inMilliseconds / _duration.inMilliseconds,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: _primaryText,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: _tertiaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: _tertiaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Download butonu (her zaman aynı yerde - music bar'ın altında)
                  if (isDownloadable) ...[
                    SizedBox(height: 8),
                    SizedBox(
                      width: 100,
                      child: GestureDetector(
                        onTap: isDownloadingThis
                            ? null
                            : () => _downloadMainContent(sampleId, title),
                        child: Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: _surfaceColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _borderColor.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isDownloadingThis)
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    value: _downloadProgress,
                                    valueColor: AlwaysStoppedAnimation<Color>(_primaryText),
                                    backgroundColor: _tertiaryText,
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.download_outlined,
                                  color: _primaryText,
                                  size: 14,
                                ),
                              SizedBox(width: 4),
                              Text(
                                isDownloadingThis ? 'İndiriliyor' : 'Download',
                                style: TextStyle(
                                  color: _primaryText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.05,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(width: 12),

            // Sağ taraf - Play butonu (sabit konum)
            if (demoUrl != null && demoUrl.isNotEmpty)
              GestureDetector(
                onTap: () => _playDemo(demoUrl, sampleId),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCurrentPlaying && _isPlaying
                        ? _primaryText
                        : _surfaceColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isCurrentPlaying && _isPlaying
                          ? _primaryText
                          : _borderColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isCurrentPlaying && _isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: isCurrentPlaying && _isPlaying
                        ? _backgroundColor
                        : _primaryText,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Filter UI
  void _showGenreFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
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
                'Genre Seç',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ..._genres.map((genre) {
                final bool isSelected = _selectedGenre == genre;
                return ListTile(
                  title: Text(
                    genre,
                    style: TextStyle(
                      color: isSelected ? _primaryText : _secondaryText,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? _primaryText : _secondaryText,
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

  void _showPriceFilter() {
    final List<String> priceOptions = ['Tümü', 'Ücretsiz', 'Ücretli'];

    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
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
                  color: _primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ...priceOptions.map((option) {
                final bool isSelected = _selectedPriceFilter == option;
                return ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      color: isSelected ? _primaryText : _secondaryText,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? _primaryText : _secondaryText,
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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        title: Text(
          'Sample Bank',
          style: TextStyle(
            color: _primaryText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: _primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _primaryText),
            onPressed: _refreshSamples,
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama çubuğu - Minimal
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            height: 42,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: _primaryText, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Sample ara...',
                hintStyle: TextStyle(color: _secondaryText, fontSize: 15),
                prefixIcon: Icon(Icons.search, color: _secondaryText, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: _secondaryText, size: 18),
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

          // Filtre butonları - Minimal
          Container(
            height: 40,
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                // Genre filtresi
                Expanded(
                  child: GestureDetector(
                    onTap: _showGenreFilter,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borderColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedGenre,
                            style: TextStyle(
                              color: _primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, color: _secondaryText, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 10),

                // Fiyat filtresi
                Expanded(
                  child: GestureDetector(
                    onTap: _showPriceFilter,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borderColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedPriceFilter,
                            style: TextStyle(
                              color: _primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, color: _secondaryText, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 8),

          // Sonuç sayısı - Minimal
          if (!_isLoading)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${filteredSamples.length} sample',
                style: TextStyle(
                  color: _tertiaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

          SizedBox(height: 6),

          // Sample listesi
          Expanded(
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryText),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Samples yükleniyor...',
                    style: TextStyle(color: _secondaryText),
                  ),
                ],
              ),
            )
                : filteredSamples.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_off,
                    color: _secondaryText,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Hiç sample bulunamadı',
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Farklı filtreler deneyin',
                    style: TextStyle(
                      color: _secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              color: _primaryText,
              backgroundColor: _surfaceColor,
              onRefresh: _refreshSamples,
              child: ListView.builder(
                controller: _scrollController,
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: filteredSamples.length,
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: Tween<double>(
                      begin: 0.0,
                      end: 1.0,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          (index / filteredSamples.length) * 0.5,
                          1.0,
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(
                            (index / filteredSamples.length) * 0.5,
                            1.0,
                            curve: Curves.easeOut,
                          ),
                        ),
                      ),
                      child: _buildSampleCard(filteredSamples[index]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}