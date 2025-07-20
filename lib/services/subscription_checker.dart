import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'payment_service.dart';

class SubscriptionChecker {
  static final PaymentService _paymentService = PaymentService();

  // Premium kontrolü - tüm uygulamada kullanılacak
  static Future<bool> isPremiumUser() async {
    try {
      return await _paymentService.isPremiumUser();
    } catch (error) {
      print('Premium check error: $error');
      return false;
    }
  }

  // Premium gerektiren sayfalar için widget wrapper
  static Widget premiumGate({
    required Widget child,
    required Widget fallback,
  }) {
    return FutureBuilder<bool>(
      future: isPremiumUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.data == true) {
          return child;
        } else {
          return fallback;
        }
      },
    );
  }
}