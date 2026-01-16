# Firebase Cloud Functions for VinTrade

This directory contains Firebase Cloud Functions for the VinTrade application.

## Setup

1. Install dependencies:
```bash
cd functions
npm install
```

2. Configure email credentials:

### Option 1: Using Firebase Functions Config (Recommended for Production)
```bash
firebase functions:config:set email.user="your-email@gmail.com" email.password="your-app-password"
```

### Option 2: Using Environment Variables (For Local Development)
Create a `.env` file in the `functions/` directory:
```
EMAIL_USER=your-email@gmail.com
EMAIL_PASSWORD=your-app-password
```

## Email Configuration

### Gmail Setup
1. Enable 2-Step Verification on your Google Account
2. Generate an App Password: https://support.google.com/accounts/answer/185833
3. Use the App Password (not your regular password) in the configuration

### Other Email Providers
Update the `service` field in `src/index.ts`:
- For Outlook: `service: "outlook"`
- For Custom SMTP: Replace the `service` with `host`, `port`, and `secure` options

## Available Functions

### `sendOrderConfirmationEmail`
- **Trigger**: `onCreate` in `orders` collection
- **Purpose**: Sends a confirmation email to the buyer when an order is created
- **Email Includes**:
  - Order ID
  - Product Name
  - Price (RM)
  - Seller Name

## Deployment

1. Build the functions:
```bash
npm run build
```

2. Deploy to Firebase:
```bash
npm run deploy
```

Or deploy all functions:
```bash
firebase deploy --only functions
```

## Local Testing

1. Start the Firebase emulator:
```bash
npm run serve
```

2. The function will automatically trigger when a document is created in the `orders` collection.

## Logs

View function logs:
```bash
npm run logs
```

Or use Firebase Console:
```bash
firebase functions:log
```

