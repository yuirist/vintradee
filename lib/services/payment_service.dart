import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import 'chat_service.dart';
import 'email_service.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();
  final EmailService _emailService = EmailService();

  // Create order document after successful payment
  Future<String> createOrder({
    required String buyerId,
    required String sellerId,
    required String productId,
    required double amount,
    required String productTitle,
    String? buyerEmail,
    String? buyerName,
    String? sellerEmail,
    String? sellerName,
  }) async {
    try {
      final orderData = {
        'buyerId': buyerId,
        'sellerId': sellerId,
        'productId': productId,
        'productTitle': productTitle,
        'amount': amount,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection(AppConstants.ordersCollection)
          .add(orderData);

      debugPrint('✅ Order created successfully: ${docRef.id}');

      // Send email receipt to buyer (non-blocking)
      if (buyerEmail != null && buyerName != null) {
        _emailService.sendPurchaseReceipt(
          buyerEmail: buyerEmail,
          buyerName: buyerName,
          productTitle: productTitle,
          amount: amount,
          orderId: docRef.id,
          sellerName: sellerName ?? 'Seller',
        ).catchError((e) {
          debugPrint('⚠️ Email sending failed (non-critical): $e');
          return false;
        });
      }

      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating order: $e');
      throw Exception('Failed to create order: $e');
    }
  }

  // Send notification message to seller via chat
  Future<void> notifySeller({
    required String sellerId,
    required String buyerId,
    required String productId,
    required String productTitle,
    String? buyerName,
    String? meetupLocation,
  }) async {
    try {
      // Create or get chat room (product-specific: buyerId_sellerId_productId)
      final chatRoomId = await _chatService.createOrGetChatRoom(
        sellerId: sellerId,
        buyerId: buyerId,
        productId: productId,
        productTitle: productTitle,
      );

      // Build automated message with buyer name, product name, and meetup location
      final buyerDisplayName = buyerName ?? 'Buyer';
      String message = 'System: $buyerDisplayName has purchased "$productTitle" via FPX.';
      
      if (meetupLocation != null && meetupLocation.isNotEmpty) {
        message += ' Meet-up location: $meetupLocation.';
      }

      // Send notification message
      await _chatService.sendMessage(
        chatRoomId: chatRoomId,
        senderId: buyerId, // System message from buyer
        receiverId: sellerId,
        content: message,
        productId: productId,
        sellerId: sellerId,
      );

      debugPrint('✅ Seller notification sent: $message');
    } catch (e) {
      debugPrint('❌ Error sending seller notification: $e');
      // Don't throw - notification failure shouldn't block the purchase
    }
  }

  // Complete purchase workflow
  Future<void> completePurchase({
    required String buyerId,
    required String sellerId,
    required String productId,
    required double amount,
    required String productTitle,
    String? buyerEmail,
    String? buyerName,
    String? sellerEmail,
    String? sellerName,
    String? meetupLocation,
  }) async {
    try {
      // Create order
      await createOrder(
        buyerId: buyerId,
        sellerId: sellerId,
        productId: productId,
        amount: amount,
        productTitle: productTitle,
        buyerEmail: buyerEmail,
        buyerName: buyerName,
        sellerEmail: sellerEmail,
        sellerName: sellerName,
      );

      // Notify seller with buyer name and meetup location
      await notifySeller(
        sellerId: sellerId,
        buyerId: buyerId,
        productId: productId,
        productTitle: productTitle,
        buyerName: buyerName,
        meetupLocation: meetupLocation,
      );

      debugPrint('✅ Purchase workflow completed');
    } catch (e) {
      debugPrint('❌ Error completing purchase workflow: $e');
      rethrow;
    }
  }
}

