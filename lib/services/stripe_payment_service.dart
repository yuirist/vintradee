import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StripePaymentService {
  // Stripe Test Mode Publishable Key
  static const String publishableKey =
      'pk_test_51Spuw1QhUkm9L0tp981VfbiP4Ibo4Ley58B5VvhUQz9xUc839k9LSFWwHfsSMlwyYLQm0hGGxIxi6iE9UqMPkZkA00aAZfugaS';

  // ⚠️ SECURITY WARNING: This Secret Key should ONLY be used for testing!
  // In production, you MUST move this to a secure backend server.
  // Get your Secret Key from: https://dashboard.stripe.com/test/apikeys
  // TODO: Replace with your actual Stripe Secret Key for testing
  static const String secretKey =
      'sk_test_51Spuw1QhUkm9L0tpbF8RQ5bEm5w26gy8Bv6ImIACZ2jmuYcnVvitlmTxtyvs0etQfGctPmLlKK8tUs7e8R9bgomw00RviOQDKa'; // Starts with 'sk_test_...'

  // Stripe API endpoint for creating payment intents
  static const String stripeApiUrl =
      'https://api.stripe.com/v1/payment_intents';

  /// Initialize Stripe with the publishable key
  static Future<void> initialize() async {
    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
    debugPrint('✅ Stripe initialized with publishable key');
  }

  /// Create payment intent directly via Stripe API (FOR TESTING ONLY)
  ///
  /// ⚠️ SECURITY WARNING: This method uses the Secret Key directly in the app.
  /// This is ONLY for testing. In production, move this to a secure backend.
  ///
  /// This method:
  /// 1. Creates a PaymentIntent with the specified amount and currency
  /// 2. Uses FPX payment method for Malaysian users
  /// 3. Returns the client_secret for the Payment Sheet
  Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    String currency = 'myr',
  }) async {
    try {
      debugPrint(
          '💳 Creating payment intent: RM ${amount.toStringAsFixed(2)} (${currency.toUpperCase()})');

      // Check if secret key is configured
      if (secretKey == 'YOUR_SECRET_KEY_HERE') {
        throw Exception(
            'Please configure your Stripe Secret Key in stripe_payment_service.dart');
      }

      // Convert amount to cents/sen (Stripe requires integer)
      final amountInCents = (amount * 100).toInt();

      // Get current user's email for Stripe receipt
      // CRITICAL: Without receipt_email, Stripe has no recipient address and won't send the email
      // even if 'Successful payments' toggle is ON in the Stripe dashboard
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserEmail = currentUser?.email?.trim();

      // Stripe API requires form-encoded body
      final body = <String, String>{
        'amount': amountInCents.toString(),
        'currency': currency.toLowerCase(),
        'payment_method_types[]':
            'fpx', // FPX for Malaysian users (Bank Rakyat, etc.)
      };

      // Add receipt_email parameter - REQUIRED for Stripe to send receipts
      // Use the email of the currently logged-in user: FirebaseAuth.instance.currentUser?.email
      if (currentUserEmail != null && currentUserEmail.isNotEmpty) {
        body['receipt_email'] = currentUserEmail;
        debugPrint(
            '📧 Receipt email parameter added to PaymentIntent: $currentUserEmail');
        debugPrint(
            '   ✅ Stripe will email receipt to this address after successful payment');
      } else {
        debugPrint('⚠️ WARNING: No user email available!');
        debugPrint('   Current user: ${currentUser?.uid ?? "null"}');
        debugPrint('   User email: ${currentUser?.email ?? "null"}');
        debugPrint(
            '   ❌ Receipt email NOT included - Stripe will NOT send receipt even if toggle is ON');
      }

      // Encode body as form-urlencoded
      final encodedBody = body.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      // Call Stripe API directly
      final response = await http.post(
        Uri.parse(stripeApiUrl),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: encodedBody,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Payment intent created successfully');

        // Verify receipt_email was included in the response (echoed back by Stripe)
        final receiptEmailInResponse = result['receipt_email'];
        if (receiptEmailInResponse != null) {
          debugPrint(
              '✅ Receipt email confirmed in PaymentIntent response: $receiptEmailInResponse');
          debugPrint(
              '   Stripe will email receipt to this address after successful payment');
        } else if (currentUserEmail != null && currentUserEmail.isNotEmpty) {
          debugPrint(
              '⚠️ WARNING: receipt_email not found in PaymentIntent response');
          debugPrint('   Expected: $currentUserEmail');
        }

        final clientSecret = result['client_secret']?.toString() ?? '';
        if (clientSecret.isNotEmpty) {
          final preview = clientSecret.length > 20
              ? clientSecret.substring(0, 20)
              : clientSecret.substring(0, clientSecret.length);
          debugPrint('   Client Secret: $preview...');
        }
        return result;
      } else {
        final errorBody = jsonDecode(response.body);
        debugPrint(
            '❌ Stripe API Error: ${errorBody['error']?['message'] ?? response.body}');
        throw Exception(
            'Failed to create payment intent: ${errorBody['error']?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      debugPrint('❌ Error creating payment intent: $e');
      rethrow;
    }
  }

  /// Initialize and present the Stripe Payment Sheet
  ///
  /// This method:
  /// 1. Initializes the Payment Sheet with the client secret
  /// 2. Presents the Payment Sheet to the user
  /// 3. Returns true if payment was successful, false if canceled
  Future<bool> presentPaymentSheet({
    required String clientSecret,
    String currency = 'myr',
  }) async {
    try {
      debugPrint('💳 Initializing Payment Sheet...');

      // Initialize payment sheet with PaymentIntent client secret
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'VinTrade',
          style: ThemeMode.light,
          returnURL:
              'vintrade://stripe-redirect', // Deep link to return to app after FPX payment
        ),
      );

      debugPrint('✅ Payment Sheet initialized, presenting...');

      // Present payment sheet to user
      await Stripe.instance.presentPaymentSheet();

      // Payment was successful
      debugPrint('✅ Payment completed successfully');
      return true;
    } on StripeException catch (e) {
      debugPrint('❌ Stripe error: ${e.error.message}');
      if (e.error.code == FailureCode.Canceled) {
        // User canceled the payment
        debugPrint('⚠️ Payment canceled by user');
        return false;
      }
      throw Exception('Payment failed: ${e.error.message}');
    } catch (e) {
      debugPrint('❌ Payment error: $e');
      throw Exception('Payment failed: $e');
    }
  }

  /// Complete payment flow: create intent and present sheet
  ///
  /// This is a convenience method that combines:
  /// 1. Creating a payment intent
  /// 2. Initializing and presenting the payment sheet
  Future<bool> processPayment({
    required double amount,
    String currency = 'myr',
  }) async {
    try {
      // Step 1: Create payment intent
      final paymentIntent = await createPaymentIntent(
        amount: amount,
        currency: currency,
      );

      final clientSecret = paymentIntent['client_secret'] as String?;
      if (clientSecret == null) {
        throw Exception(
            'Invalid payment intent response: missing client_secret');
      }

      // Step 2: Present payment sheet
      return await presentPaymentSheet(
        clientSecret: clientSecret,
        currency: currency,
      );
    } catch (e) {
      debugPrint('❌ Payment processing error: $e');
      rethrow;
    }
  }

  /// Make test payment with FPX (for Stripe Test Mode)
  ///
  /// This method:
  /// 1. Creates a test payment intent with FPX payment method
  /// 2. Initializes and presents the Payment Sheet
  /// 3. Hardcodes currency to 'myr' and includes 'fpx' in payment_method_types
  Future<bool> makeTestPayment(double amount, String currency) async {
    try {
      debugPrint('🧪 Creating test payment: RM ${amount.toStringAsFixed(2)}');

      // Hardcode currency to 'myr' and use FPX for Bank Rakyat testing
      const testCurrency = 'myr';

      // Step 1: Create payment intent via backend (or simulate for testing)
      // In production, this should call your backend
      Map<String, dynamic> paymentIntent;

      try {
        // Create payment intent directly via Stripe API
        paymentIntent = await createPaymentIntent(
          amount: amount,
          currency: testCurrency,
        );
      } catch (e) {
        // If payment intent creation fails, throw error
        debugPrint('❌ Payment intent creation failed: $e');
        rethrow;
      }

      final clientSecret = paymentIntent['client_secret'] as String?;
      if (clientSecret == null) {
        throw Exception(
            'Invalid payment intent response: missing client_secret');
      }

      // Step 2: Initialize Payment Sheet with FPX support
      debugPrint('💳 Initializing Payment Sheet with FPX...');

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'VinTrade',
          style: ThemeMode.light,
          returnURL:
              'vintrade://stripe-redirect', // Deep link to return to app after FPX payment
        ),
      );

      debugPrint('✅ Payment Sheet initialized, presenting...');

      // Step 3: Present payment sheet to user
      await Stripe.instance.presentPaymentSheet();

      debugPrint('✅ Test payment completed successfully');
      return true;
    } on StripeException catch (e) {
      debugPrint('❌ Stripe error: ${e.error.message}');
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('⚠️ Payment canceled by user');
        return false;
      }
      throw Exception('Payment failed: ${e.error.message}');
    } catch (e) {
      debugPrint('❌ Test payment error: $e');
      throw Exception('Test payment failed: $e');
    }
  }
}
