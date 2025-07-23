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

  // Product IDs - Play Console'da tanımlanacak
  static const String monthlySubscriptionId = 'dj_app_monthly_10_euro';

  bool _isInitialized = false;
  bool _isAvailable = false;

  // Initialize service with detailed error handling
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔄 Initializing payment service...');

      // Check if in-app purchases are available
      _isAvailable = await _inAppPurchase.isAvailable();
      print('📱 In-app purchases available: $_isAvailable');

      if (!_isAvailable) {
        throw Exception('In-app purchases not available on this device');
      }

      // Enable pending purchases for Android
      if (Platform.isAndroid) {
        print('🤖 Enabling pending purchases for Android...');
        InAppPurchaseAndroidPlatformAddition.enablePendingPurchases();
      }

      // Set up purchase stream listener
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () {
          print('Purchase stream closed');
          _subscription.cancel();
        },
        onError: (error) {
          print('❌ Purchase stream error: $error');
        },
      );

      _isInitialized = true;
      print('✅ Payment service initialized successfully');

    } catch (error) {
      print('❌ Payment service initialization failed: $error');
      _isInitialized = false;
      rethrow;
    }
  }

  // Check if service is available and ready
  bool get isAvailable => _isAvailable && _isInitialized;

  // Handle purchase updates
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      _handlePurchase(purchaseDetails);
    }
  }

  // Handle individual purchase
  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    print('📦 Purchase status: ${purchaseDetails.status}');
    print('📦 Product ID: ${purchaseDetails.productID}');

    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {

      try {
        // Verify purchase with backend
        final bool verified = await _verifyPurchaseWithServer(purchaseDetails);

        if (verified) {
          print('✅ Purchase verified successfully');
        } else {
          print('❌ Purchase verification failed');
        }
      } catch (error) {
        print('❌ Purchase verification error: $error');
      }

      // Complete the purchase
      if (purchaseDetails.pendingCompletePurchase) {
        try {
          await _inAppPurchase.completePurchase(purchaseDetails);
          print('✅ Purchase completed');
        } catch (error) {
          print('❌ Purchase completion error: $error');
        }
      }
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      print('❌ Purchase error: ${purchaseDetails.error}');
    } else if (purchaseDetails.status == PurchaseStatus.pending) {
      print('⏳ Purchase pending...');
    }
  }

  // Verify purchase with server
  Future<bool> _verifyPurchaseWithServer(PurchaseDetails purchaseDetails) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/payments/verify-google-play'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
          'productId': purchaseDetails.productID,
          'orderId': purchaseDetails.purchaseID,
        }),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }

      print('❌ Server verification failed: ${response.statusCode}');
      return false;
    } catch (error) {
      print('❌ Server verification error: $error');
      return false;
    }
  }

  // Purchase monthly subscription with detailed error handling
  Future<bool> purchaseMonthlySubscription() async {
    try {
      print('🔄 Starting purchase process...');

      // Initialize if not already done
      if (!_isInitialized) {
        await initialize();
      }

      // Check availability
      if (!_isAvailable) {
        throw Exception('In-app purchases not available');
      }

      // Get product details
      print('🔄 Querying product details...');
      const Set<String> kIds = <String>{monthlySubscriptionId};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(kIds);

      if (response.error != null) {
        throw Exception('Product query error: ${response.error}');
      }

      if (response.notFoundIDs.isNotEmpty) {
        throw Exception('Product not found in Play Console: ${response.notFoundIDs}');
      }

      if (response.productDetails.isEmpty) {
        throw Exception('No product details found. Check Play Console configuration.');
      }

      final ProductDetails productDetails = response.productDetails.first;
      print('✅ Product found: ${productDetails.title} - ${productDetails.price}');

      // Create purchase param
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      // Start purchase - For subscription use buyNonConsumable
      print('🔄 Starting purchase...');
      final bool result = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      print('📱 Purchase initiated: $result');
      return result;

    } catch (error) {
      print('❌ Purchase error: $error');
      throw error;
    }
  }

  // Get subscription status from server
  Future<Map<String, dynamic>?> getSubscriptionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/payments/subscription-status'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['subscription'];
        }
      }

      return null;
    } catch (error) {
      print('❌ Get subscription status error: $error');
      return null;
    }
  }

  // Check if user is premium
  Future<bool> isPremiumUser() async {
    try {
      final subscription = await getSubscriptionStatus();
      return subscription?['isPremium'] == true;
    } catch (error) {
      print('❌ Check premium status error: $error');
      return false;
    }
  }

  // Restore purchases
  Future<void> restorePurchases() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      print('🔄 Restoring purchases...');
      await _inAppPurchase.restorePurchases();
      print('✅ Restore purchases initiated');
    } catch (error) {
      print('❌ Restore purchases error: $error');
      throw error;
    }
  }

  // Test product availability
  Future<bool> testProductAvailability() async {
    try {
      await initialize();

      const Set<String> kIds = <String>{monthlySubscriptionId};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(kIds);

      print('🧪 Test Results:');
      print('   Error: ${response.error}');
      print('   Not Found: ${response.notFoundIDs}');
      print('   Found Products: ${response.productDetails.length}');

      if (response.productDetails.isNotEmpty) {
        final product = response.productDetails.first;
        print('   Product: ${product.title} - ${product.price}');
        return true;
      }

      return false;
    } catch (error) {
      print('❌ Product test error: $error');
      return false;
    }
  }

  // Dispose
  void dispose() {
    if (_isInitialized) {
      _subscription.cancel();
      _isInitialized = false;
    }
  }
}