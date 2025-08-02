// lib/services/payment_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../url_constants.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Product IDs - Google Play Console'da tanımlanması gereken ID
  static const String monthlySubscriptionId = 'dj_app_monthly_10_euro';

  bool _isInitialized = false;
  bool _isAvailable = false;

  // Initialize service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔄 Google Play Billing Service başlatılıyor...');

      // Check if in-app purchases are available
      _isAvailable = await _inAppPurchase.isAvailable();
      print('📱 Google Play Billing durumu: $_isAvailable');

      if (!_isAvailable) {
        throw Exception('Google Play Billing bu cihazda kullanılamıyor');
      }

      // Enable pending purchases for Android
      if (Platform.isAndroid) {
        print('🤖 Android pending purchases aktifleştiriliyor...');
        InAppPurchaseAndroidPlatformAddition.enablePendingPurchases();
      }

      // Set up purchase stream listener
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () {
          print('📱 Purchase stream kapatıldı');
          _subscription.cancel();
        },
        onError: (error) {
          print('❌ Purchase stream hatası: $error');
        },
      );

      _isInitialized = true;
      print('✅ Google Play Billing Service başarıyla başlatıldı');

    } catch (error) {
      print('❌ Google Play Billing Service başlatma hatası: $error');
      _isInitialized = false;
      rethrow;
    }
  }

  // Handle purchase updates
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    print('🔔 Google Play\'den ${purchaseDetailsList.length} purchase güncelleme alındı');

    for (PurchaseDetails purchaseDetails in purchaseDetailsList) {
      print('📦 Purchase durumu: ${purchaseDetails.status}');
      print('📦 Product ID: ${purchaseDetails.productID}');

      if (purchaseDetails.status == PurchaseStatus.pending) {
        print('⏳ Ödeme bekleniyor...');
        _showPendingUI();
      } else if (purchaseDetails.status == PurchaseStatus.purchased) {
        print('✅ Ödeme tamamlandı!');
        _handleSuccessfulPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        print('❌ Ödeme hatası: ${purchaseDetails.error}');
        _handleFailedPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.restored) {
        print('🔄 Ödeme geri yüklendi');
        _handleSuccessfulPurchase(purchaseDetails);
      }

      // Complete the purchase on Android
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
        print('✅ Purchase tamamlandı (Android)');
      }
    }
  }

  // Show pending UI
  void _showPendingUI() {
    print('⏳ Kullanıcıya bekleme durumu gösteriliyor...');
    // Burada loading dialog gösterebilirsin
  }

  // Handle successful purchase
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    try {
      print('🎉 Başarılı ödeme işleniyor...');
      print('📦 Product: ${purchaseDetails.productID}');
      print('📦 Transaction: ${purchaseDetails.purchaseID}');

      // Backend'e doğrulama gönder
      final isVerified = await _verifyPurchaseWithServer(purchaseDetails);

      if (isVerified) {
        print('✅ Ödeme backend tarafından doğrulandı');

        // Local olarak premium durumu kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_premium', true);
        await prefs.setString('purchase_date', DateTime.now().toIso8601String());
        await prefs.setString('product_id', purchaseDetails.productID);
        await prefs.setString('transaction_id', purchaseDetails.purchaseID ?? '');

        print('💾 Premium durumu local olarak kaydedildi');

        // UI'ye başarı mesajı gönder
        _showSuccessUI();

      } else {
        print('❌ Backend doğrulama başarısız');
        _showErrorUI('Ödeme doğrulanamadı. Lütfen destek ile iletişime geçin.');
      }
    } catch (error) {
      print('❌ Başarılı ödeme işleme hatası: $error');
      _showErrorUI('Ödeme işlenirken hata oluştu: $error');
    }
  }

  // Handle failed purchase
  void _handleFailedPurchase(PurchaseDetails purchaseDetails) {
    print('💥 Ödeme başarısız: ${purchaseDetails.error}');

    String errorMessage = 'Ödeme işlemi başarısız';

    if (purchaseDetails.error != null) {
      final error = purchaseDetails.error!;
      switch (error.code) {
        case 'user_canceled':
          errorMessage = 'Ödeme işlemi iptal edildi';
          break;
        case 'payment_invalid':
          errorMessage = 'Geçersiz ödeme bilgisi';
          break;
        case 'payment_not_allowed':
          errorMessage = 'Ödeme izni verilmedi';
          break;
        default:
          errorMessage = 'Ödeme hatası: ${error.message}';
      }
    }

    _showErrorUI(errorMessage);
  }

  // Show success UI
  void _showSuccessUI() {
    print('✅ Başarı mesajı UI\'ye gönderiliyor');
    // Burada success dialog gösterebilirsin
  }

  // Show error UI
  void _showErrorUI(String message) {
    print('❌ Hata mesajı UI\'ye gönderiliyor: $message');
    // Burada error dialog gösterebilirsin
  }

  // Verify purchase with server
  Future<bool> _verifyPurchaseWithServer(PurchaseDetails purchaseDetails) async {
    try {
      print('🔄 Backend\'e ödeme doğrulama gönderiliyor...');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Kullanıcı token\'ı bulunamadı');
      }

      final requestData = {
        'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
        'productId': purchaseDetails.productID,
        'orderId': purchaseDetails.purchaseID,
        'packageName': 'com.trackbang.djmobilapp',
      };

      print('📤 Backend\'e gönderilen data: $requestData');

      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/payments/verify-google-play'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 30));

      print('📥 Backend response status: ${response.statusCode}');
      print('📥 Backend response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final success = data['success'] == true;
        print('✅ Backend doğrulama sonucu: $success');
        return success;
      }

      print('❌ Backend doğrulama başarısız: HTTP ${response.statusCode}');
      return false;

    } catch (error) {
      print('❌ Backend doğrulama hatası: $error');
      return false;
    }
  }

  // Purchase monthly subscription
  Future<bool> purchaseMonthlySubscription() async {
    try {
      print('🔄 Google Play Store ödeme süreci başlatılıyor...');

      // Initialize if not already done
      if (!_isInitialized) {
        await initialize();
      }

      // Check availability
      if (!_isAvailable) {
        throw Exception('Google Play Billing kullanılamıyor');
      }

      // Get product details from Google Play Console
      print('🔄 Google Play Console\'dan ürün bilgileri alınıyor...');
      const Set<String> kIds = <String>{monthlySubscriptionId};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(kIds);

      print('🔍 Google Play Console sorgu sonucu:');
      print('   Hata: ${response.error}');
      print('   Bulunamayan ID\'ler: ${response.notFoundIDs}');
      print('   Bulunan ürün sayısı: ${response.productDetails.length}');

      // Check for errors
      if (response.error != null) {
        throw Exception('Google Play ürün sorgu hatası: ${response.error}');
      }

      if (response.notFoundIDs.isNotEmpty) {
        print('❌ Google Play Console\'da bulunamayan ürünler: ${response.notFoundIDs}');
        throw Exception('Ürün Google Play Console\'da bulunamadı: ${response.notFoundIDs}\n\nLütfen Google Play Console\'da "$monthlySubscriptionId" ID\'li abonelik ürününü oluşturun.');
      }

      if (response.productDetails.isEmpty) {
        throw Exception('Google Play Console\'da hiç ürün bulunamadı. Lütfen abonelik ürününü oluşturun.');
      }

      // Product found, proceed with purchase
      final ProductDetails productDetails = response.productDetails.first;
      print('✅ Google Play\'de ürün bulundu:');
      print('   ID: ${productDetails.id}');
      print('   Başlık: ${productDetails.title}');
      print('   Fiyat: ${productDetails.price}');
      print('   Açıklama: ${productDetails.description}');

      // Create purchase parameter
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      // Start purchase flow
      print('🔄 Google Play Store ödeme akışı başlatılıyor...');
      final bool result = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      print('📱 Google Play ödeme akışı başlatma sonucu: $result');

      if (result) {
        print('✅ Google Play Store ödeme ekranı açıldı');
        print('💡 Kullanıcı ödeme ekranında işlem yapacak...');
      } else {
        print('❌ Google Play Store ödeme ekranı açılamadı');
      }

      return result;

    } catch (error) {
      print('❌ Google Play ödeme süreci hatası: $error');

      // Kullanıcı dostu hata mesajları
      String userMessage = error.toString();
      if (error.toString().contains('not found in Play Console')) {
        userMessage = 'Ödeme sistemi henüz hazır değil. Lütfen daha sonra tekrar deneyin.';
      } else if (error.toString().contains('not available')) {
        userMessage = 'Google Play Store bu cihazda kullanılamıyor.';
      }

      _showErrorUI(userMessage);
      throw error;
    }
  }

  // Get subscription status from server
  Future<Map<String, dynamic>?> getSubscriptionStatus() async {
    try {
      print('🔄 Sunucudan abonelik durumu alınıyor...');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        print('❌ Kullanıcı token\'ı bulunamadı');
        return null;
      }

      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/payments/subscription-status'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 10));

      print('📥 Abonelik durumu response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          print('✅ Abonelik durumu alındı: ${data['subscription']}');
          return data['subscription'];
        }
      }

      print('❌ Abonelik durumu alınamadı');
      return null;
    } catch (error) {
      print('❌ Abonelik durumu alma hatası: $error');
      return null;
    }
  }

  // Check if user is premium
  Future<bool> isPremiumUser() async {
    try {
      print('🔄 Premium durum kontrolü...');

      // First check server
      final subscription = await getSubscriptionStatus();
      if (subscription != null && subscription['isPremium'] == true) {
        print('✅ Server\'dan premium doğrulandı');
        return true;
      }

      // Fallback to local check
      final prefs = await SharedPreferences.getInstance();
      final isPremiumLocal = prefs.getBool('is_premium') ?? false;
      print('📱 Local premium durumu: $isPremiumLocal');

      return isPremiumLocal;
    } catch (error) {
      print('❌ Premium durum kontrol hatası: $error');

      // Final fallback to local
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool('is_premium') ?? false;
      } catch (e) {
        return false;
      }
    }
  }

  // Restore purchases
  Future<void> restorePurchases() async {
    try {
      print('🔄 Google Play\'den satın almalar geri yükleniyor...');

      if (!_isInitialized) {
        await initialize();
      }

      if (!_isAvailable) {
        throw Exception('Google Play Billing kullanılamıyor');
      }

      await _inAppPurchase.restorePurchases();
      print('✅ Google Play satın alma geri yükleme başlatıldı');
      print('💡 Geri yüklenen satın almalar otomatik olarak işlenecek');

    } catch (error) {
      print('❌ Satın alma geri yükleme hatası: $error');
      throw error;
    }
  }

  // Test connectivity with Google Play
  Future<bool> testGooglePlayConnection() async {
    try {
      print('🧪 Google Play bağlantısı test ediliyor...');

      await initialize();

      if (!_isAvailable) {
        print('❌ Google Play Billing kullanılamıyor');
        return false;
      }

      // Try to query a test product
      const Set<String> testIds = <String>{
        'android.test.purchased', // Google's test product
      };

      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(testIds);

      print('🔍 Google Play test sonucu:');
      print('   Hata: ${response.error}');
      print('   Test başarılı: ${response.error == null}');

      return response.error == null;

    } catch (error) {
      print('❌ Google Play bağlantı test hatası: $error');
      return false;
    }
  }

  // Dispose
  void dispose() {
    if (_isInitialized) {
      _subscription.cancel();
      _isInitialized = false;
      print('🔄 Google Play Payment Service kapatıldı');
    }
  }
}