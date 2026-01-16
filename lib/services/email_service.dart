import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Email Service for sending purchase receipts via Firebase Email Templates
/// 
/// This service triggers Firebase email templates by creating a document
/// in the 'email_queue' collection, which can be monitored by:
/// - Firebase Extensions (Trigger Email)
/// - Firebase Cloud Functions
/// - Firestore triggers
class EmailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send purchase receipt email to buyer using Firebase Email Template
  /// 
  /// Creates a document in 'email_queue' collection that triggers the email template
  /// The Firebase Extension/Function should listen to this collection and send emails
  Future<bool> sendPurchaseReceipt({
    required String buyerEmail,
    required String buyerName,
    required String productTitle,
    required double amount,
    required String orderId,
    required String sellerName,
  }) async {
    try {
      // Create email queue document that triggers Firebase email template
      final emailData = {
        'to': buyerEmail,
        'template': 'purchase_receipt', // Your Firebase email template ID
        'data': {
          'buyerName': buyerName,
          'productTitle': productTitle,
          'amount': amount.toStringAsFixed(2),
          'orderId': orderId,
          'sellerName': sellerName,
          'date': DateTime.now().toIso8601String(),
          'currency': 'RM',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add to email_queue collection (Firebase Extension/Function will process this)
      await _firestore
          .collection('email_queue')
          .add(emailData);

      debugPrint('📧 Email receipt queued for Firebase template:');
      debugPrint('   To: $buyerEmail');
      debugPrint('   Template: purchase_receipt');
      debugPrint('   Product: $productTitle');
      debugPrint('   Amount: RM ${amount.toStringAsFixed(2)}');
      debugPrint('   Order ID: $orderId');

      return true;
    } catch (e) {
      debugPrint('❌ Error queuing email: $e');
      return false;
    }
  }

  /// Send seller notification email
  Future<bool> sendSellerNotification({
    required String sellerEmail,
    required String sellerName,
    required String productTitle,
    required double amount,
    required String buyerName,
  }) async {
    try {
      debugPrint('📧 Seller notification (placeholder):');
      debugPrint('   To: $sellerEmail');
      debugPrint('   Product: $productTitle');
      debugPrint('   Amount: RM ${amount.toStringAsFixed(2)}');
      debugPrint('   Buyer: $buyerName');

      // Placeholder: return true for now
      return true;
    } catch (e) {
      debugPrint('❌ Error sending seller notification email: $e');
      return false;
    }
  }
}

