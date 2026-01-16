import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Email Service for sending purchase receipts using mailer package
/// 
/// Uses Gmail SMTP with App Password authentication
class EmailService {
  // Gmail SMTP Configuration
  // ⚠️ SECURITY WARNING: Store these credentials securely in production!
  static const String _smtpHost = 'smtp.gmail.com';
  static const int _smtpPort = 587;
  static const String _senderEmail = 'ai230018@student.uthm.edu.my';
  static const String _senderPassword = 'pcafvmycbchciasd'; // App Password (16 characters, spaces removed)

  /// Get SMTP server configuration for Gmail
  SmtpServer _getSmtpServer() {
    return SmtpServer(
      _smtpHost,
      port: _smtpPort,
      username: _senderEmail,
      password: _senderPassword,
      ssl: false,
      allowInsecure: false,
    );
  }

  /// Send receipt email to buyer after successful purchase
  /// 
  /// Uses Gmail SMTP to send a professional purchase confirmation email
  /// with Product Name and Price
  Future<bool> sendReceiptEmail({
    required String recipientEmail,
    required String itemName,
    required String price,
  }) async {
    try {
      debugPrint('📧 Sending receipt email to: $recipientEmail');
      debugPrint('   Item: $itemName');
      debugPrint('   Price: $price');

      // Create email message
      final message = Message()
        ..from = Address(_senderEmail, 'VinTrade')
        ..recipients.add(recipientEmail)
        ..subject = 'VinTrade - Purchase Confirmed'
        ..html = _buildEmailHtml(itemName, price)
        ..text = _buildEmailText(itemName, price);

      // Send email via SMTP
      final sendReport = await send(message, _getSmtpServer());

      debugPrint('✅ Receipt email sent successfully!');
      debugPrint('   Message ID: ${sendReport.toString()}');
      
      return true;
    } catch (e) {
      debugPrint('❌ Error sending receipt email: $e');
      debugPrint('   Error details: $e');
      return false;
    }
  }

  /// Send confirmation email to buyer after successful purchase
  /// 
  /// Alias for sendReceiptEmail (for backward compatibility)
  Future<bool> sendConfirmationEmail({
    required String recipientEmail,
    required String itemName,
    required String price,
  }) async {
    return await sendReceiptEmail(
      recipientEmail: recipientEmail,
      itemName: itemName,
      price: price,
    );
  }

  /// Build HTML email body
  String _buildEmailHtml(String itemName, String price) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
      background-color: #f4f4f4;
    }
    .email-container {
      background-color: #ffffff;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .header {
      background-color: #dbc156;
      color: #000000;
      padding: 30px 20px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 28px;
      font-weight: bold;
    }
    .content {
      padding: 30px 20px;
    }
    .greeting {
      font-size: 16px;
      margin-bottom: 20px;
    }
    .order-details {
      background-color: #f9f9f9;
      border-left: 4px solid #dbc156;
      padding: 20px;
      margin: 20px 0;
      border-radius: 4px;
    }
    .detail-row {
      display: flex;
      justify-content: space-between;
      padding: 12px 0;
      border-bottom: 1px solid #e0e0e0;
    }
    .detail-row:last-child {
      border-bottom: none;
    }
    .detail-label {
      font-weight: bold;
      color: #666;
    }
    .detail-value {
      color: #333;
      font-weight: 500;
    }
    .price {
      font-size: 24px;
      font-weight: bold;
      color: #dbc156;
    }
    .footer {
      background-color: #f9f9f9;
      padding: 20px;
      text-align: center;
      color: #666;
      font-size: 12px;
      border-top: 1px solid #e0e0e0;
    }
    .footer p {
      margin: 5px 0;
    }
  </style>
</head>
<body>
  <div class="email-container">
    <div class="header">
      <h1>🎉 Purchase Confirmed</h1>
    </div>
    <div class="content">
      <div class="greeting">
        <p>Dear Valued Customer,</p>
        <p>Thank you for your purchase on <strong>VinTrade</strong>! Your order has been confirmed.</p>
      </div>
      
      <div class="order-details">
        <div class="detail-row">
          <span class="detail-label">Item Name:</span>
          <span class="detail-value">$itemName</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Price:</span>
          <span class="detail-value price">$price</span>
        </div>
      </div>

      <p>Your seller has been notified and will contact you shortly to arrange the meet-up or delivery.</p>
      <p>If you have any questions, please contact the seller through the chat feature in the VinTrade app.</p>
    </div>
    <div class="footer">
      <p><strong>VinTrade</strong> - Campus Marketplace</p>
      <p>This is an automated confirmation email. Please do not reply.</p>
      <p>© ${DateTime.now().year} VinTrade. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  /// Build plain text email body
  String _buildEmailText(String itemName, String price) {
    return '''
VinTrade - Purchase Confirmed

Dear Valued Customer,

Thank you for your purchase on VinTrade! Your order has been confirmed.

Order Details:
--------------
Item Name: $itemName
Price: $price

Your seller has been notified and will contact you shortly to arrange the meet-up or delivery.

If you have any questions, please contact the seller through the chat feature in the VinTrade app.

---
VinTrade - Campus Marketplace
This is an automated confirmation email. Please do not reply.
© ${DateTime.now().year} VinTrade. All rights reserved.
    ''';
  }

  /// Send purchase receipt email to buyer (legacy method - kept for compatibility)
  /// 
  /// Now uses direct email sending via SMTP instead of Firebase queue
  Future<bool> sendPurchaseReceipt({
    required String buyerEmail,
    required String buyerName,
    required String productTitle,
    required double amount,
    required String orderId,
    required String sellerName,
  }) async {
    final formattedPrice = 'RM ${amount.toStringAsFixed(2)}';
    return await sendReceiptEmail(
      recipientEmail: buyerEmail,
      itemName: productTitle,
      price: formattedPrice,
    );
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

