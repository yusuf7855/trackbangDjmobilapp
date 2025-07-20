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

  // Initialize service
  Future<void> initialize() async {
    if (_isInitialized) return;

    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      throw Exception('In-app purchases not available');
    }

    // DÜZELTİLMİŞ - enablePendingPurchases static method (void return type)
    if (Platform.isAndroid) {
      InAppPurchaseAndroidPlatformAddition.enablePendingPurchases();
    }

    _subscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription.cancel(),
      onError: (error) => print('Purchase stream error: $error'),
    );

    _isInitialized = true;
  }

  // Handle purchase updates
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      _handlePurchase(purchaseDetails);
    }
  }

  // Handle individual purchase
  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    print('Purchase status: ${purchaseDetails.status}');

    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {

      // Verify purchase with backend
      final bool verified = await _verifyPurchaseWithServer(purchaseDetails);

      if (verified) {
        print('Purchase verified successfully');
      } else {
        print('Purchase verification failed');
      }

      // Complete the purchase
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      print('Purchase error: ${purchaseDetails.error}');
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

      return false;
    } catch (error) {
      print('Server verification error: $error');
      return false;
    }
  }

  // Purchase monthly subscription
  Future<bool> purchaseMonthlySubscription() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Get product details
      const Set<String> kIds = <String>{monthlySubscriptionId};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(kIds);

      if (response.notFoundIDs.isNotEmpty) {
        throw Exception('Product not found: ${response.notFoundIDs}');
      }

      if (response.productDetails.isEmpty) {
        throw Exception('No product details found');
      }

      final ProductDetails productDetails = response.productDetails.first;
      print('Product found: ${productDetails.title} - ${productDetails.price}');

      // Create purchase param
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      // Start purchase - DÜZELTİLMİŞ: subscription için doğru method
      final bool result = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      return result;
    } catch (error) {
      print('Purchase error: $error');
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
      print('Get subscription status error: $error');
      return null;
    }
  }

  // Check if user is premium
  Future<bool> isPremiumUser() async {
    try {
      final subscription = await getSubscriptionStatus();
      return subscription?['isPremium'] == true;
    } catch (error) {
      print('Check premium status error: $error');
      return false;
    }
  }

  // Restore purchases
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (error) {
      print('Restore purchases error: $error');
      throw error;
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
