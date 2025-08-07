// lib/services/payment_service.dart - Eksiksiz hatasız versiyon

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

  // ✅ ÜRÜN ID'LERİ - Google Play Console'da tanımlanması gereken ID'ler
  static const String premiumAccessProductId = 'dj_app_premium_access'; // Uygulama içi ürün
  static const String monthlySubscriptionId = 'dj_app_monthly_10_euro'; // Abonelik

  // Callback function'lar
  Function? onPurchaseSuccess;
  Function(String)? onPurchaseError;
  Function? onPurchasePending;

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
        onPurchasePending?.call();
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

  // ✅ UYGULAMA İÇİ ÜRÜN SATINALMASI - Tek seferlik premium erişim
  Future<bool> purchasePremiumAccess() async {
    try {
      print('🔄 Premium erişim satın alma başlatılıyor...');

      if (!_isInitialized) await initialize();
      if (!_isAvailable) throw Exception('Google Play Billing kullanılamıyor');

      // Get product details from Google Play Console
      print('🔄 Google Play Console\'dan ürün bilgileri alınıyor...');
      final Set<String> productIds = {premiumAccessProductId};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);

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
        throw Exception('''
Ödeme sistemi henüz hazır değil.

Lütfen Google Play Console'da şu ürünü oluşturun:
Product ID: $premiumAccessProductId
Type: In-app product (Managed)
Price: ₺180.00

Bulunamayan ürünler: ${response.notFoundIDs}
        ''');
      }

      if (response.productDetails.isEmpty) {
        throw Exception('Google Play Console\'da hiç ürün bulunamadı. Lütfen "$premiumAccessProductId" ürününü oluşturun.');
      }

      // Product found, proceed with purchase
      final ProductDetails productDetails = response.productDetails.first;
      print('✅ Google Play\'de ürün bulundu:');
      print('   ID: ${productDetails.id}');
      print('   Başlık: ${productDetails.title}');
      print('   Fiyat: ${productDetails.price} (Beklenen: ₺180.00)');
      print('   Açıklama: ${productDetails.description}');

      // Create purchase parameter
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      // Start purchase flow - TEK SEFERLİK ÜRÜN İÇİN buyNonConsumable kullanıyoruz
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
      print('❌ Premium erişim satın alma hatası: $error');
      onPurchaseError?.call(error.toString());
      rethrow;
    }
  }

  // ✅ ABONELİK SATINALMASI - Aylık abonelik
  Future<bool> purchaseMonthlySubscription() async {
    try {
      print('🔄 Aylık abonelik satın alma başlatılıyor...');

      if (!_isInitialized) await initialize();
      if (!_isAvailable) throw Exception('Google Play Billing kullanılamıyor');

      // Get subscription details from Google Play Console
      print('🔄 Google Play Console\'dan abonelik bilgileri alınıyor...');
      final Set<String> subscriptionIds = {monthlySubscriptionId};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(subscriptionIds);

      print('🔍 Abonelik sorgu sonucu:');
      print('   Hata: ${response.error}');
      print('   Bulunamayan ID\'ler: ${response.notFoundIDs}');
      print('   Bulunan abonelik sayısı: ${response.productDetails.length}');

      // Check for errors
      if (response.error != null) {
        throw Exception('Google Play abonelik sorgu hatası: ${response.error}');
      }

      if (response.notFoundIDs.isNotEmpty) {
        print('❌ Google Play Console\'da bulunamayan abonelikler: ${response.notFoundIDs}');
        throw Exception('''
Abonelik sistemi henüz hazır değil.

Lütfen Google Play Console'da şu aboneliği oluşturun:
Subscription ID: $monthlySubscriptionId
Type: Subscription (Auto-renewable)
Price: ₺180.00/month

Bulunamayan abonelikler: ${response.notFoundIDs}
        ''');
      }

      if (response.productDetails.isEmpty) {
        throw Exception('Google Play Console\'da hiç abonelik bulunamadı. Lütfen "$monthlySubscriptionId" aboneliğini oluşturun.');
      }

      // Subscription found, proceed with purchase
      final ProductDetails productDetails = response.productDetails.first;
      print('✅ Google Play\'de abonelik bulundu:');
      print('   ID: ${productDetails.id}');
      print('   Başlık: ${productDetails.title}');
      print('   Fiyat: ${productDetails.price} (Beklenen: ₺180/ay)');
      print('   Açıklama: ${productDetails.description}');

      // Create purchase parameter
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      // Start subscription purchase flow - ABONELİK İÇİN buyNonConsumable kullanıyoruz
      print('🔄 Google Play Store abonelik ödeme akışı başlatılıyor...');
      final bool result = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      print('📱 Google Play abonelik ödeme akışı başlatma sonucu: $result');

      if (result) {
        print('✅ Google Play Store abonelik ödeme ekranı açıldı');
        print('💡 Kullanıcı abonelik ödeme ekranında işlem yapacak...');
      } else {
        print('❌ Google Play Store abonelik ödeme ekranı açılamadı');
      }

      return result;

    } catch (error) {
      print('❌ Abonelik satın alma hatası: $error');
      onPurchaseError?.call(error.toString());
      rethrow;
    }
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

        // UI'ye başarı callback gönder
        onPurchaseSuccess?.call();

      } else {
        print('❌ Backend doğrulama başarısız');
        onPurchaseError?.call('Ödeme doğrulanamadı. Lütfen destek ile iletişime geçin.');
      }
    } catch (error) {
      print('❌ Başarılı ödeme işleme hatası: $error');
      onPurchaseError?.call('Ödeme işlenirken hata oluştu: $error');
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

    onPurchaseError?.call(errorMessage);
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

      // Ürün türünü belirle
      String purchaseType = 'in_app_product';
      if (purchaseDetails.productID == monthlySubscriptionId) {
        purchaseType = 'subscription';
      }

      final requestData = {
        'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
        'productId': purchaseDetails.productID,
        'orderId': purchaseDetails.purchaseID,
        'packageName': 'com.trackbang.djmobilapp',
        'purchaseType': purchaseType, // Backend'e ürün türünü bildir
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

  // Check if user already has premium access
  Future<bool> hasPremiumAccess() async {
    try {
      print('🔄 Premium erişim durumu kontrol ediliyor...');

      // Check local storage first
      final prefs = await SharedPreferences.getInstance();
      final isPremiumLocal = prefs.getBool('is_premium') ?? false;

      if (isPremiumLocal) {
        print('✅ Local premium durumu: true');
        return true;
      }

      // Check with server
      final subscription = await getSubscriptionStatus();
      if (subscription != null && subscription['isPremium'] == true) {
        print('✅ Server\'dan premium doğrulandı');
        await prefs.setBool('is_premium', true); // Local cache güncelle
        return true;
      }

      print('❌ Premium erişim yok');
      return false;

    } catch (error) {
      print('❌ Premium erişim kontrol hatası: $error');

      // Fallback to local
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool('is_premium') ?? false;
      } catch (e) {
        return false;
      }
    }
  }

  // Get subscription status from server
  Future<Map<String, dynamic>?> getSubscriptionStatus() async {
    try {
      print('🔄 Sunucudan premium durumu alınıyor...');

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

      print('📥 Premium durumu response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          print('✅ Premium durumu alındı: ${data['subscription']}');
          return data['subscription'];
        }
      }

      print('❌ Premium durumu alınamadı');
      return null;
    } catch (error) {
      print('❌ Premium durumu alma hatası: $error');
      return null;
    }
  }

  // Restore purchases
  Future<void> restorePurchases() async {
    try {
      print('🔄 Google Play\'den satın almalar geri yükleniyor...');

      if (!_isInitialized) await initialize();
      if (!_isAvailable) throw Exception('Google Play Billing kullanılamıyor');

      await _inAppPurchase.restorePurchases();
      print('✅ Google Play satın alma geri yükleme başlatıldı');

    } catch (error) {
      print('❌ Satın alma geri yükleme hatası: $error');
      throw error;
    }
  }

  // Debug method - hangi ürünlerin mevcut olduğunu kontrol edin
  Future<void> debugAvailableProducts() async {
    try {
      print('🔍 Google Play\'de mevcut ürünler kontrol ediliyor...');

      if (!_isInitialized) await initialize();
      if (!_isAvailable) {
        print('❌ Google Play Billing kullanılamıyor');
        return;
      }

      // Hem gerçek hem test ürünlerini kontrol et
      final Set<String> allIds = {
        premiumAccessProductId,           // Sizin uygulama içi ürününüz
        monthlySubscriptionId,            // Sizin aboneliğiniz
        'android.test.purchased',         // Google test ürünü
        'android.test.subscription',      // Google test abonelik
      };

      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(allIds);

      print('📊 Google Play Ürün Sorgu Sonuçları:');
      print('   ❌ Bulunamayan: ${response.notFoundIDs}');
      print('   ✅ Bulunan: ${response.productDetails.length} ürün');

      for (var product in response.productDetails) {
        print('   📦 ${product.id}: ${product.title} - ${product.price}');
      }

      if (response.error != null) {
        print('   🚨 Hata: ${response.error}');
      }

    } catch (error) {
      print('❌ Debug sorgu hatası: $error');
    }
  }

  // Test satın alma (geliştirme için)
  Future<bool> purchaseTestProduct() async {
    try {
      print('🧪 Test ürünü satın alma başlatılıyor...');

      if (!_isInitialized) await initialize();
      if (!_isAvailable) throw Exception('Google Play Billing kullanılamıyor');

      // Google'ın test ürününü dene
      final Set<String> testIds = {'android.test.purchased'};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(testIds);

      if (response.productDetails.isNotEmpty) {
        final ProductDetails productDetails = response.productDetails.first;
        print('✅ Test ürünü bulundu: ${productDetails.id}');

        final PurchaseParam purchaseParam = PurchaseParam(
          productDetails: productDetails,
        );

        final bool result = await _inAppPurchase.buyNonConsumable(
          purchaseParam: purchaseParam,
        );

        print('🧪 Test satın alma sonucu: $result');
        return result;
      } else {
        print('❌ Test ürünü bulunamadı');
        return false;
      }

    } catch (error) {
      print('❌ Test satın alma hatası: $error');
      return false;
    }
  }

  // Set callbacks
  void setCallbacks({
    Function? onSuccess,
    Function(String)? onError,
    Function? onPending,
  }) {
    onPurchaseSuccess = onSuccess;
    onPurchaseError = onError;
    onPurchasePending = onPending;
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