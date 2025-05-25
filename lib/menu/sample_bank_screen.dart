import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

import '../url_constants.dart';

class SampleBankScreen extends StatefulWidget {
  @override
  _SampleBankScreenState createState() => _SampleBankScreenState();
}

class _SampleBankScreenState extends State<SampleBankScreen> {
  final Dio _dio = Dio();
  bool _isDownloading = false;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  List<dynamic> _samples = [];
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchSamples();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dio.close();
    super.dispose();
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
      setState(() {
        _samples = response.data;
        _isRefreshing = false;
      });
    } catch (e) {
      _showErrorNotification('Örnekler yüklenirken hata: ${e.toString()}');
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _downloadFile(String sampleId) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      _showProgressNotification('İndirme başlatılıyor...');

      final tokenResponse = await _dio.post(
        '${UrlConstants.apiBaseUrl}/api/download/generate',
        data: {'sampleId': sampleId},
      );

      if (tokenResponse.data['error'] != null) {
        throw Exception(tokenResponse.data['error']);
      }

      final downloadUrl = tokenResponse.data['downloadUrl'] as String;

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

      final sample = _samples.firstWhere(
            (s) => s['_id'] == sampleId,
        orElse: () => throw Exception('Sample bulunamadı'),
      );

      final String fileName = sample['fileName']?.toString() ?? 'sample_${sampleId.substring(0, 6)}';
      final String filePath = "${dir.path}/$fileName";

      await _dio.download(downloadUrl, filePath);

      _showSuccessNotification('İndirme Tamamlandı!', filePath);

    } on DioException catch (e) {
      final errorMessage = e.response?.data?['error']?.toString() ?? e.message?.toString() ?? 'Bilinmeyen hata';
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

  void _showProgressNotification(String message) {
    final scaffoldMessenger = _scaffoldMessengerKey.currentState;
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.download, color: Colors.white),
          SizedBox(width: 8),
          Text(message),
        ]),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        duration: Duration(days: 1),
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
          Text(message),
        ]),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'AÇ',
          textColor: Colors.white,
          onPressed: () => _openFile(filePath),
        ),
        duration: Duration(seconds: 4),
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
          Flexible(child: Text(message)),
        ]),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openFile(String filePath) async {
    try {
      await OpenFile.open(filePath);
    } catch (e) {
      _showErrorNotification('Dosya açılamadı: Uygun uygulama yükleyin');
    }
  }

  Widget _buildImagePreview(int index) {
    final imageNumber = (index % 4) + 1;
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(
          image: AssetImage('assets/sample$imageNumber.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildSampleCard(int index) {
    final sample = _samples[index];
    final isDownloadable = sample['paymentStatus'] == 'paid' ||
        sample['paymentStatus'] == 'free';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePreview(index),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sample['name']?.toString() ?? 'İsimsiz',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    sample['category']?.toString() ?? 'Kategorisiz',
                    style: TextStyle(
                      color: Colors.grey[400],
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fiyat',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '\$${sample['price']?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Durum',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              sample['paymentStatus']?.toString() ?? 'unknown',
                              style: TextStyle(
                                color: isDownloadable ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isDownloading
                          ? null
                          : isDownloadable
                          ? () => _downloadFile(sample['_id']?.toString() ?? '')
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDownloadable
                            ? Colors.green
                            : Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isDownloading
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        'Download',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _fetchSamples,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _fetchSamples,
          color: Colors.blue,
          child: _isRefreshing && _samples.isEmpty
              ? Center(
            child: CircularProgressIndicator(
              color: Colors.blue,
            ),
          )
              : _samples.isEmpty
              ? Center(
            child: Text(
              'Örnek bulunamadı',
              style: TextStyle(color: Colors.white),
            ),
          )
              : ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: _samples.length,
            itemBuilder: (context, index) {
              return _buildSampleCard(index);
            },
          ),
        ),
      ),
    );
  }
}