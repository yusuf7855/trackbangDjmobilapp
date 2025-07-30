// lib/services/mock_payment_service.dart
// Geliştirme aşamasında kullanmak için

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPaymentService {
  static final MockPaymentService _instance = MockPaymentService._internal();
  factory MockPaymentService() => _instance;
  MockPaymentService._internal();

  bool _isInitialized = false;

  // Mock initialization
  Future<void> initialize() async {
    await Future.delayed(Duration(seconds: 1)); // Simulate initialization delay
    _isInitialized = true;
    print('✅ Mock Payment Service initialized');
  }

  // Mock purchase process
  Future<bool> purchaseMonthlySubscription() async {
    print('🔄 Mock: Starting purchase process...');

    // Simulate loading
    await Future.delayed(Duration(seconds: 2));

    // Simulate successful purchase
    await _simulateSuccessfulPurchase();

    print('✅ Mock: Purchase completed successfully');
    return true;
  }

  // Simulate successful purchase and save to preferences
  Future<void> _simulateSuccessfulPurchase() async {
    final prefs = await SharedPreferences.getInstance();

    // Save mock subscription data
    await prefs.setBool('is_premium', true);
    await prefs.setString('subscription_start', DateTime.now().toIso8601String());
    await prefs.setString('subscription_end',
        DateTime.now().add(Duration(days: 30)).toIso8601String());
    await prefs.setString('payment_method', 'mock_google_play');

    print('💾 Mock subscription data saved');
  }

  // Check premium status
  Future<bool> isPremiumUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool('is_premium') ?? false;

    if (isPremium) {
      final endDateStr = prefs.getString('subscription_end');
      if (endDateStr != null) {
        final endDate = DateTime.parse(endDateStr);
        return DateTime.now().isBefore(endDate);
      }
    }

    return false;
  }

  // Get mock subscription status
  Future<Map<String, dynamic>?> getSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = await isPremiumUser();

    if (isPremium) {
      final startDate = prefs.getString('subscription_start');
      final endDate = prefs.getString('subscription_end');

      return {
        'isActive': true,
        'isPremium': true,
        'type': 'premium',
        'startDate': startDate,
        'endDate': endDate,
        'paymentMethod': 'mock_google_play',
        'daysRemaining': DateTime.parse(endDate!).difference(DateTime.now()).inDays
      };
    }

    return {
      'isActive': false,
      'isPremium': false,
      'type': 'free'
    };
  }

  // Restore purchases (mock)
  Future<void> restorePurchases() async {
    print('🔄 Mock: Restoring purchases...');
    await Future.delayed(Duration(seconds: 1));

    // Simulate found subscription
    await _simulateSuccessfulPurchase();
    print('✅ Mock: Purchases restored');
  }

  // Clear subscription (for testing)
  Future<void> clearSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_premium');
    await prefs.remove('subscription_start');
    await prefs.remove('subscription_end');
    await prefs.remove('payment_method');
    print('🗑️ Mock: Subscription cleared');
  }

  // Test all payment flows
  Future<void> runPaymentTests() async {
    print('🧪 Running Mock Payment Tests...');

    // Test 1: Purchase
    print('\n1. Testing Purchase...');
    final purchaseSuccess = await purchaseMonthlySubscription();
    print('   Purchase Result: $purchaseSuccess');

    // Test 2: Check status
    print('\n2. Testing Status Check...');
    final status = await getSubscriptionStatus();
    print('   Status: $status');

    // Test 3: Premium check
    print('\n3. Testing Premium Check...');
    final isPremium = await isPremiumUser();
    print('   Is Premium: $isPremium');

    print('\n✅ All mock tests completed!');
  }
}

// Helper widget for testing
class MockPaymentTestWidget extends StatefulWidget {
  @override
  _MockPaymentTestWidgetState createState() => _MockPaymentTestWidgetState();
}

class _MockPaymentTestWidgetState extends State<MockPaymentTestWidget> {
  final MockPaymentService _mockService = MockPaymentService();
  bool _isLoading = false;
  String _status = 'Not tested yet';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mock Payment Test')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Mock Payment Service Test',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),

            Text(_status, style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),

            if (_isLoading)
              CircularProgressIndicator()
            else
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _testPurchase,
                    child: Text('Test Purchase'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _checkStatus,
                    child: Text('Check Status'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _clearSubscription,
                    child: Text('Clear Subscription'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _runAllTests,
                    child: Text('Run All Tests'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _testPurchase() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing purchase...';
    });

    try {
      await _mockService.initialize();
      final success = await _mockService.purchaseMonthlySubscription();
      setState(() {
        _status = success ? 'Purchase successful!' : 'Purchase failed!';
      });
    } catch (e) {
      setState(() {
        _status = 'Purchase error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking status...';
    });

    try {
      final status = await _mockService.getSubscriptionStatus();
      final isPremium = await _mockService.isPremiumUser();
      setState(() {
        _status = 'Premium: $isPremium\nDetails: $status';
      });
    } catch (e) {
      setState(() {
        _status = 'Status check error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearSubscription() async {
    await _mockService.clearSubscription();
    setState(() {
      _status = 'Subscription cleared!';
    });
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isLoading = true;
      _status = 'Running all tests...';
    });

    await _mockService.runPaymentTests();

    setState(() {
      _isLoading = false;
      _status = 'All tests completed! Check console for details.';
    });
  }
}