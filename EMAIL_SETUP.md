# Email Setup Guide - VinTrade

This guide explains how to set up email confirmation functionality using the `mailer` package with Gmail SMTP.

## Setup Steps

### 1. Install Dependencies

The `mailer` package has been added to `pubspec.yaml`. Install it by running:

```bash
flutter pub get
```

### 2. Generate Gmail App Password

1. Go to your Google Account settings: https://myaccount.google.com/
2. Enable **2-Step Verification** if not already enabled
3. Go to **Security** → **2-Step Verification** → **App passwords**
4. Generate a new App Password for "Mail"
5. Copy the 16-character password (it looks like: `abcd efgh ijkl mnop`)

### 3. Configure Email Credentials

Open `lib/services/email_service.dart` and update the following constants:

```dart
static const String _senderEmail = 'your-email@gmail.com'; // Replace with your Gmail
static const String _senderPassword = 'your-16-char-app-password'; // Replace with your App Password
```

**Example:**
```dart
static const String _senderEmail = 'vintrade@gmail.com';
static const String _senderPassword = 'abcd efgh ijkl mnop'; // 16-character App Password
```

### 4. Test the Email Function

The email function is automatically called when a Stripe payment succeeds. To test manually:

```dart
final emailService = EmailService();
await emailService.sendConfirmationEmail(
  recipientEmail: 'buyer@example.com',
  itemName: 'Test Product',
  price: 'RM 50.00',
);
```

## How It Works

### Email Trigger

The email is sent automatically when:
1. User completes a Stripe payment successfully
2. Payment status is 'succeeded'
3. Buyer's email is available

### Email Content

- **Subject**: "VinTrade - Purchase Confirmed"
- **Includes**:
  - Item Name
  - Price (formatted as RM)
  - Professional HTML template with VinTrade branding
  - Plain text fallback

### Email Template

The email includes:
- VinTrade branding (gold color: #dbc156)
- Order details in a styled box
- Professional footer with copyright
- Responsive design for mobile and desktop

## Security Notes

⚠️ **Important**: The email credentials are currently hardcoded in the service file. For production:

1. **Move credentials to environment variables**
2. **Use secure storage** (like Flutter Secure Storage)
3. **Consider using Firebase Cloud Functions** for better security
4. **Never commit credentials to version control**

## Troubleshooting

### Email Not Sending

1. **Check credentials**: Ensure Gmail and App Password are correct
2. **Check App Password**: Make sure you're using the 16-character App Password, not your regular password
3. **Enable Less Secure Apps**: Not needed if using App Password
4. **Check internet connection**: SMTP requires internet access
5. **Check logs**: Look for error messages in debug console

### Common Errors

- **"Authentication failed"**: Wrong email or App Password
- **"Connection timeout"**: Check internet connection or firewall
- **"Invalid credentials"**: Make sure App Password is correct (remove spaces if needed)

## Email Service Location

- **File**: `lib/services/email_service.dart`
- **Function**: `sendConfirmationEmail()`
- **Triggered from**: `lib/screens/marketplace/product_detail_screen.dart` (after successful payment)

## Next Steps

1. Update email credentials in `email_service.dart`
2. Test with a real purchase
3. Monitor email delivery in Gmail Sent folder
4. Consider adding email delivery status tracking

