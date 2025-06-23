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

  // Modern dark colors - Siyah, gri, beyaz tonları
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

    // Başlangıç animasyonu
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
    _audioPlayer.durationStream.listen((Duration? d) {
      if (d != null && mounted) {
        setState(() => _duration = d);
      }
    });

    _audioPlayer.positionStream.listen((Duration p) {
      if (mounted) {
        setState(() => _position = p);
      }
    });

    _audioPlayer.playerStateStream.listen((PlayerState state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });

    _audioPlayer.processingStateStream.listen((ProcessingState state) {
      if (state == ProcessingState.completed && mounted) {
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
      _refreshSamples();
    }
  }

  Future<void> _refreshSamples() async {
    if (!_isRefreshing) {
      await _fetchSamples();
    }
  }

  Future<void> _fetchSamples() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      if (_samples.isEmpty) _isLoading = true;
    });

    try {
      final response = await _dio.get(
        '${UrlConstants.apiBaseUrl}/api/samples',
        options: Options(
          sendTimeout: Duration(seconds: 10),
          receiveTimeout: Duration(seconds: 10),
        ),
      );

      if (response.data is List && mounted) {
        setState(() {
          _samples = response.data;

          // Extract unique genres
          _genres = ['Tümü'];
          Set<String> genreSet = {'Tümü'};
          for (var sample in _samples) {
            String genre = sample['genre']?.toString() ?? 'Kategorisiz';
            genreSet.add(genre);
          }
          _genres = genreSet.toList();
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Örnekler yüklenirken hata: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _filteredSamples {
    List<dynamic> filtered = _samples.where((sample) {
      bool genreMatch = _selectedGenre == 'Tümü' ||
          sample['genre']?.toString() == _selectedGenre;

      bool priceMatch = true;
      if (_selectedPriceFilter == 'Ücretsiz') {
        priceMatch = sample['price'] == 0 || sample['price'] == null;
      } else if (_selectedPriceFilter == 'Ücretli') {
        priceMatch = sample['price'] != null && sample['price'] > 0;
      }

      bool searchMatch = _searchQuery.isEmpty ||
          (sample['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (sample['genre']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      return genreMatch && priceMatch && searchMatch;
    }).toList();

    return filtered;
  }

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

        // URL'yi düzenle - HTTP kullan ve IP adresini ayarla
        String validUrl = demoUrl;

        // Eğer URL tam değilse API base URL ile birleştir
        if (!demoUrl.startsWith('http://') && !demoUrl.startsWith('https://')) {
          validUrl = '${UrlConstants.apiBaseUrl}$demoUrl';
        }

        // HTTPS'yi HTTP'ye çevir
        if (validUrl.startsWith('https://')) {
          validUrl = validUrl.replaceFirst('https://', 'http://');
        }

        // localhost ve 127.0.0.1'i 192.168.1.106'ya çevir
        if (validUrl.contains('localhost') || validUrl.contains('127.0.0.1')) {
          validUrl = validUrl.replaceAll('localhost', '192.168.1.106');
          validUrl = validUrl.replaceAll('127.0.0.1', '192.168.1.106');
        }

        // 10.0.2.2'yi de 192.168.1.106'ya çevir (emulator IP)
        if (validUrl.contains('10.0.2.2')) {
          validUrl = validUrl.replaceAll('10.0.2.2', '192.168.1.106');
        }

        print('Trying to play URL: $validUrl'); // Debug için

        await _audioPlayer.setUrl(validUrl);
        await _audioPlayer.play();

        if (mounted) {
          setState(() {
            _currentPlayingId = sampleId;
          });
        }
      }
    } catch (e) {
      print('Audio play error: $e'); // Debug için
      if (mounted) {
        _showErrorSnackBar('Demo oynatılırken hata: ${e.toString()}');
      }
    }
  }

  Future<void> _downloadMainContent(String sampleId, String title) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadingItemId = sampleId;
      _downloadProgress = 0.0;
    });

    _progressAnimationController.forward();

    try {
      // Token oluştur - HTTP kullan ve IP düzelt
      String tokenApiUrl = '${UrlConstants.apiBaseUrl}/api/samples/download/generate';

      // HTTPS'yi HTTP'ye çevir
      if (tokenApiUrl.startsWith('https://')) {
        tokenApiUrl = tokenApiUrl.replaceFirst('https://', 'http://');
      }

      // localhost ve 127.0.0.1'i 192.168.1.106'ya çevir
      if (tokenApiUrl.contains('localhost') || tokenApiUrl.contains('127.0.0.1')) {
        tokenApiUrl = tokenApiUrl.replaceAll('localhost', '192.168.1.106');
        tokenApiUrl = tokenApiUrl.replaceAll('127.0.0.1', '192.168.1.106');
      }

      // 10.0.2.2'yi de 192.168.1.106'ya çevir
      if (tokenApiUrl.contains('10.0.2.2')) {
        tokenApiUrl = tokenApiUrl.replaceAll('10.0.2.2', '192.168.1.106');
      }

      print('Token API URL: $tokenApiUrl'); // Debug

      final tokenResponse = await _dio.post(
        tokenApiUrl,
        data: {'sampleId': sampleId},
        options: Options(
          sendTimeout: Duration(seconds: 15),
          receiveTimeout: Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (tokenResponse.data['error'] != null) {
        throw Exception(tokenResponse.data['error']);
      }

      String downloadUrl = tokenResponse.data['downloadUrl'] as String;
      final fileName = tokenResponse.data['fileName'] as String;

      // Download URL'yi de düzelt
      if (downloadUrl.startsWith('https://')) {
        downloadUrl = downloadUrl.replaceFirst('https://', 'http://');
      }

      if (downloadUrl.contains('localhost') || downloadUrl.contains('127.0.0.1')) {
        downloadUrl = downloadUrl.replaceAll('localhost', '192.168.1.106');
        downloadUrl = downloadUrl.replaceAll('127.0.0.1', '192.168.1.106');
      }

      if (downloadUrl.contains('10.0.2.2')) {
        downloadUrl = downloadUrl.replaceAll('10.0.2.2', '192.168.1.106');
      }

      print('Download URL: $downloadUrl'); // Debug

      // İzin kontrolü
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('Depolama izni reddedildi');
          }
        }
      }

      // Dosya yolu
      final Directory dir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final String filePath = "${dir.path}/$fileName";

      // Dosya varsa sil
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Yeni Dio instance için daha uzun timeout'lar
      final downloadDio = Dio();
      downloadDio.options.connectTimeout = Duration(seconds: 30);
      downloadDio.options.receiveTimeout = Duration(minutes: 10);
      downloadDio.options.sendTimeout = Duration(seconds: 30);

      // Retry mekanizması ile indirme
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          await downloadDio.download(
            downloadUrl,
            filePath,
            onReceiveProgress: (received, total) {
              if (total != -1 && mounted) {
                setState(() {
                  _downloadProgress = (received / total);
                });
                print('Download progress: ${(received / total * 100).toStringAsFixed(1)}%');
              }
            },
            options: Options(
              followRedirects: true,
              validateStatus: (status) => status != null && status < 500,
              headers: {
                'Accept': '*/*',
                'User-Agent': 'DJMobilApp/1.0',
              },
            ),
          );

          // İndirme başarılı, döngüden çık
          break;

        } catch (e) {
          retryCount++;
          print('Download attempt $retryCount failed: $e');

          if (retryCount >= maxRetries) {
            throw Exception('İndirme başarısız oldu ($maxRetries deneme): ${e.toString()}');
          }

          // Yeniden denemeden önce bekle
          await Future.delayed(Duration(seconds: 2 * retryCount));
        }
      }

      downloadDio.close();

      // Dosyanın başarıyla indirildiğini kontrol et
      if (await file.exists() && await file.length() > 0) {
        _showSuccessSnackBar('İndirme tamamlandı: $fileName');

        // Dosyayı aç
        try {
          await OpenFile.open(filePath);
        } catch (e) {
          print('File open error: $e');
          _showSuccessSnackBar('Dosya indirildi: ${dir.path}');
        }
      } else {
        throw Exception('Dosya düzgün indirilemedi');
      }

    } on DioException catch (e) {
      String errorMessage = 'Bağlantı hatası';

      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Bağlantı zaman aşımına uğradı';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'İndirme zaman aşımına uğradı';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Sunucuya bağlanılamıyor. Sunucu çalışıyor mu?';
      } else if (e.response?.statusCode == 404) {
        errorMessage = 'Dosya bulunamadı';
      } else if (e.response?.statusCode == 403) {
        errorMessage = 'İndirme yetkisi yok';
      } else if (e.response?.data is Map) {
        errorMessage = e.response?.data['error']?.toString() ?? errorMessage;
      }

      print('Dio error: ${e.type} - ${e.message}');
      _showErrorSnackBar(errorMessage);

    } catch (e) {
      print('General download error: $e');
      _showErrorSnackBar('İndirme hatası: ${e.toString()}');
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

  void _showErrorSnackBar(String message) {
    // Widget'ın hala aktif olup olmadığını kontrol et
    if (mounted && context.mounted) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        // SnackBar gösteremezse konsola yazdır
        print('Error showing snackbar: $message');
      }
    } else {
      // Widget dispose olmuşsa konsola yazdır
      print('Error (widget disposed): $message');
    }
  }

  void _showSuccessSnackBar(String message) {
    // Widget'ın hala aktif olup olmadığını kontrol et
    if (mounted && context.mounted) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        // SnackBar gösteremezse konsola yazdır
        print('Success message: $message');
      }
    } else {
      // Widget dispose olmuşsa konsola yazdır
      print('Success (widget disposed): $message');
    }
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

  String _buildImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';

    // Eğer URL zaten tam ise olduğu gibi kullan
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      // HTTP'yi HTTP'ye çevir ve IP'yi düzelt
      String validUrl = imageUrl;
      if (validUrl.startsWith('https://')) {
        validUrl = validUrl.replaceFirst('https://', 'http://');
      }

      if (validUrl.contains('localhost') || validUrl.contains('127.0.0.1')) {
        validUrl = validUrl.replaceAll('localhost', '192.168.1.106');
        validUrl = validUrl.replaceAll('127.0.0.1', '192.168.1.106');
      }

      if (validUrl.contains('10.0.2.2')) {
        validUrl = validUrl.replaceAll('10.0.2.2', '192.168.1.106');
      }

      return validUrl;
    }

    // Eğer /uploads/ ile başlıyorsa base URL ekle
    else if (imageUrl.startsWith('/uploads/')) {
      String baseUrl = UrlConstants.apiBaseUrl;

      // Base URL'yi düzelt
      if (baseUrl.startsWith('https://')) {
        baseUrl = baseUrl.replaceFirst('https://', 'http://');
      }

      if (baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1')) {
        baseUrl = baseUrl.replaceAll('localhost', '192.168.1.106');
        baseUrl = baseUrl.replaceAll('127.0.0.1', '192.168.1.106');
      }

      if (baseUrl.contains('10.0.2.2')) {
        baseUrl = baseUrl.replaceAll('10.0.2.2', '192.168.1.106');
      }

      return '$baseUrl$imageUrl';

    }

    // Eğer sadece dosya adı ise /uploads/ ekle
    else {
      String baseUrl = UrlConstants.apiBaseUrl;

      // Base URL'yi düzelt
      if (baseUrl.startsWith('https://')) {
        baseUrl = baseUrl.replaceFirst('https://', 'http://');
      }

      if (baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1')) {
        baseUrl = baseUrl.replaceAll('localhost', '192.168.1.106');
        baseUrl = baseUrl.replaceAll('127.0.0.1', '192.168.1.106');
      }

      if (baseUrl.contains('10.0.2.2')) {
        baseUrl = baseUrl.replaceAll('10.0.2.2', '192.168.1.106');
      }

      return '$baseUrl/uploads/sample-images/$imageUrl';
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
            ? Border.all(color: Colors.grey.withOpacity(0.5), width: 1)
            : Border.all(color: Colors.grey.withOpacity(0.1), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resim
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                        imageUrl.startsWith('http')
                            ? imageUrl
                            : '${UrlConstants.apiBaseUrl}$imageUrl',
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: _surfaceDark,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: _primaryColor,
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Color(0xFF2A2A2A),
                            child: Icon(
                              Icons.music_note_rounded,
                              color: _textSecondary,
                              size: 30,
                            ),
                          );
                        },
                      )
                          : Container(
                        color: Color(0xFF2A2A2A),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: _textSecondary,
                          size: 30,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 16),

                  // İçerik
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
                            color: _textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: 8),

                        // Tür
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getGenreColor(genre).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getGenreColor(genre).withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            genre.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getGenreColor(genre),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        SizedBox(height: 8),

                        // Fiyat
                        Text(
                          price == 0 ? 'ÜCRETSİZ' : '₺${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: price == 0 ? _accentGreen : _accentOrange,
                          ),
                        ),

                        SizedBox(height: 12),

                        // Butonlar
                        Row(
                          children: [
                            // Demo butonu
                            if (demoUrl != null && demoUrl.isNotEmpty)
                              Expanded(
                                child: Container(
                                  height: 36,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _playDemo(demoUrl, sampleId),
                                    icon: AnimatedSwitcher(
                                      duration: Duration(milliseconds: 200),
                                      child: Icon(
                                        isCurrentPlaying && _isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        key: ValueKey(isCurrentPlaying && _isPlaying),
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                    label: Text(
                                      isCurrentPlaying && _isPlaying ? 'Duraklat' : 'Demo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isCurrentPlaying
                                          ? Color(0xFF4A4A4A)
                                          : Color(0xFF374151),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            if (demoUrl != null && demoUrl.isNotEmpty && isDownloadable)
                              SizedBox(width: 8),

                            // İndirme butonu
                            if (isDownloadable)
                              Expanded(
                                child: Container(
                                  height: 36,
                                  child: ElevatedButton.icon(
                                    onPressed: isDownloadingThis
                                        ? null
                                        : () => _downloadMainContent(sampleId, title),
                                    icon: isDownloadingThis
                                        ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                        : Icon(
                                      Icons.download_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      isDownloadingThis ? 'İndiriliyor...' : 'İndir',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDownloadingThis
                                          ? Color(0xFF6B7280)
                                          : _accentGreen,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // İndirme progress indicator
            if (isDownloadingThis)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _downloadProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _accentGreen,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Tür filtresi
          Container(
            margin: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_selectedGenre),
              selected: _selectedGenre != 'Tümü',
              onSelected: (_) => _showGenreBottomSheet(),
              backgroundColor: Color(0xFF1F2937),
              selectedColor: Color(0xFF374151),
              labelStyle: TextStyle(
                color: _selectedGenre != 'Tümü' ? Colors.white : _textSecondary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: _selectedGenre != 'Tümü' ? Colors.grey.withOpacity(0.5) : _textSecondary.withOpacity(0.3),
              ),
            ),
          ),

          // Fiyat filtresi
          Container(
            margin: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_selectedPriceFilter),
              selected: _selectedPriceFilter != 'Tümü',
              onSelected: (_) => _showPriceBottomSheet(),
              backgroundColor: Color(0xFF1F2937),
              selectedColor: Color(0xFF374151),
              labelStyle: TextStyle(
                color: _selectedPriceFilter != 'Tümü' ? Colors.white : _textSecondary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: _selectedPriceFilter != 'Tümü' ? Colors.grey.withOpacity(0.5) : _textSecondary.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGenreBottomSheet() {
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
                'Tür Seçin',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    children: _genres.map((genre) {
                      bool isSelected = _selectedGenre == genre;
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
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPriceBottomSheet() {
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 16),
              ...priceOptions.map((option) {
                bool isSelected = _selectedPriceFilter == option;
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

  @override
  Widget build(BuildContext context) {
    final filteredSamples = _filteredSamples;

    return Scaffold(
      backgroundColor: _backgroundDark,
      appBar: AppBar(
        backgroundColor: _backgroundDark,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Sample Bank',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
                        ? 'Henüz sample yok'
                        : 'Arama kriterinize uygun sample bulunamadı',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  if (_samples.isEmpty) ...[
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _refreshSamples,
                      icon: Icon(Icons.refresh_rounded),
                      label: Text('Yeniden Dene'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF374151),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _refreshSamples,
              color: _primaryColor,
              backgroundColor: _surfaceDark,
              child: ListView.builder(
                controller: _scrollController,
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: filteredSamples.length,
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: Tween<double>(
                      begin: 0.0,
                      end: 1.0,
                    ).animate(CurvedAnimation(
                      parent: _animationController,
                      curve: Interval(
                        (index / filteredSamples.length) * 0.5,
                        1.0,
                        curve: Curves.easeOut,
                      ),
                    )),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          (index / filteredSamples.length) * 0.5,
                          1.0,
                          curve: Curves.easeOut,
                        ),
                      )),
                      child: _buildSampleCard(filteredSamples[index]),
                    ),
                  );
                },
              ),
            ),
          ),

          // Şu anda çalan müzik kontrolü
          if (_currentPlayingId != null && _isPlaying)
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF374151), Color(0xFF4B5563)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Demo oynatılıyor...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _audioPlayer.pause(),
                        icon: Icon(
                          Icons.pause,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _audioPlayer.stop(),
                        icon: Icon(
                          Icons.stop,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Progress bar
                  if (_duration.inSeconds > 0)
                    Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbColor: Colors.white,
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withOpacity(0.3),
                            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: _position.inSeconds.toDouble(),
                            max: _duration.inSeconds.toDouble(),
                            onChanged: (value) {
                              _audioPlayer.seek(Duration(seconds: value.toInt()));
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}