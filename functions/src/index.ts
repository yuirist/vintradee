import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";

// Initialize Firebase Admin
admin.initializeApp();

// Configure Nodemailer
// For Gmail, you'll need to use an App Password: https://support.google.com/accounts/answer/185833
// For other providers, adjust the configuration accordingly
const transporter = nodemailer.createTransport({
  service: "gmail", // Change to your email provider (gmail, outlook, etc.)
  auth: {
    user: functions.config().email?.user || process.env.EMAIL_USER,
    pass: functions.config().email?.password || process.env.EMAIL_PASSWORD,
  },
});

/**
 * Cloud Function that triggers on order creation
 * Sends a confirmation email to the buyer with order details
 */
export const sendOrderConfirmationEmail = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snap, context) => {
    const orderData = snap.data();
    const orderId = context.params.orderId;

    try {
      // Extract order data
      const buyerId = orderData.buyerId;
      const sellerId = orderData.sellerId;
      const productId = orderData.productId;
      const productTitle = orderData.productTitle || "Product";
      const amount = orderData.amount || 0;

      if (!buyerId) {
        console.error("❌ No buyerId found in order document");
        return null;
      }

      // Fetch buyer's email from users collection
      const buyerDoc = await admin
        .firestore()
        .collection("users")
        .doc(buyerId)
        .get();

      if (!buyerDoc.exists) {
        console.error(`❌ Buyer document not found for buyerId: ${buyerId}`);
        return null;
      }

      const buyerData = buyerDoc.data();
      const buyerEmail = buyerData?.email;

      if (!buyerEmail) {
        console.error(`❌ No email found for buyerId: ${buyerId}`);
        return null;
      }

      // Fetch seller's name from users collection
      let sellerName = "Seller";
      if (sellerId) {
        const sellerDoc = await admin
          .firestore()
          .collection("users")
          .doc(sellerId)
          .get();

        if (sellerDoc.exists) {
          const sellerData = sellerDoc.data();
          sellerName = sellerData?.displayName || sellerData?.email || "Seller";
        }
      }

      // Format price in Malaysian Ringgit
      const formattedPrice = `RM ${amount.toFixed(2)}`;

      // Email content
      const mailOptions = {
        from: functions.config().email?.user || process.env.EMAIL_USER,
        to: buyerEmail,
        subject: `Order Confirmation - ${productTitle}`,
        html: `
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="utf-8">
              <style>
                body {
                  font-family: Arial, sans-serif;
                  line-height: 1.6;
                  color: #333;
                  max-width: 600px;
                  margin: 0 auto;
                  padding: 20px;
                }
                .header {
                  background-color: #dbc156;
                  color: #000;
                  padding: 20px;
                  text-align: center;
                  border-radius: 8px 8px 0 0;
                }
                .content {
                  background-color: #f9f9f9;
                  padding: 30px;
                  border-radius: 0 0 8px 8px;
                }
                .order-details {
                  background-color: #fff;
                  padding: 20px;
                  border-radius: 8px;
                  margin: 20px 0;
                  border-left: 4px solid #dbc156;
                }
                .detail-row {
                  display: flex;
                  justify-content: space-between;
                  padding: 10px 0;
                  border-bottom: 1px solid #eee;
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
                }
                .price {
                  font-size: 24px;
                  font-weight: bold;
                  color: #dbc156;
                }
                .footer {
                  text-align: center;
                  margin-top: 30px;
                  padding-top: 20px;
                  border-top: 1px solid #eee;
                  color: #666;
                  font-size: 12px;
                }
              </style>
            </head>
            <body>
              <div class="header">
                <h1>🎉 Order Confirmation</h1>
                <p>Thank you for your purchase on VinTrade!</p>
              </div>
              <div class="content">
                <p>Dear ${buyerData?.displayName || "Customer"},</p>
                <p>Your order has been confirmed. Here are the details:</p>
                
                <div class="order-details">
                  <div class="detail-row">
                    <span class="detail-label">Order ID:</span>
                    <span class="detail-value">${orderId}</span>
                  </div>
                  <div class="detail-row">
                    <span class="detail-label">Product Name:</span>
                    <span class="detail-value">${productTitle}</span>
                  </div>
                  <div class="detail-row">
                    <span class="detail-label">Price:</span>
                    <span class="detail-value price">${formattedPrice}</span>
                  </div>
                  <div class="detail-row">
                    <span class="detail-label">Seller:</span>
                    <span class="detail-value">${sellerName}</span>
                  </div>
                </div>

                <p>We've notified the seller about your purchase. They will contact you shortly to arrange the meet-up or delivery.</p>
                <p>If you have any questions, please contact the seller through the chat feature in the app.</p>
              </div>
              <div class="footer">
                <p>© ${new Date().getFullYear()} VinTrade - Campus Marketplace</p>
                <p>This is an automated email. Please do not reply.</p>
              </div>
            </body>
          </html>
        `,
        text: `
Order Confirmation - VinTrade

Dear ${buyerData?.displayName || "Customer"},

Your order has been confirmed. Here are the details:

Order ID: ${orderId}
Product Name: ${productTitle}
Price: ${formattedPrice}
Seller: ${sellerName}

We've notified the seller about your purchase. They will contact you shortly to arrange the meet-up or delivery.

If you have any questions, please contact the seller through the chat feature in the app.

© ${new Date().getFullYear()} VinTrade - Campus Marketplace
This is an automated email. Please do not reply.
        `,
      };

      // Send email
      const info = await transporter.sendMail(mailOptions);
      console.log(`✅ Order confirmation email sent successfully to ${buyerEmail}`);
      console.log(`📧 Message ID: ${info.messageId}`);

      return null;
    } catch (error) {
      console.error("❌ Error sending order confirmation email:", error);
      // Don't throw - email failure shouldn't break the order creation
      return null;
    }
  });

