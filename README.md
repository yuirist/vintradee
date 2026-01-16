# VinTrade

A campus-exclusive second-hand marketplace for UTHM students.

## Tech Stack

- **Flutter** - Cross-platform mobile framework
- **Firebase** - Backend services
  - Authentication
  - Firestore (Database)
  - Storage (Images)
- **Provider** - State management

## Project Structure

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── widgets/
│       ├── custom_button.dart
│       └── custom_text_field.dart
├── models/
│   ├── user_model.dart
│   ├── product_model.dart
│   └── chat_message_model.dart
├── services/
│   ├── auth_service.dart
│   ├── firebase_service.dart
│   └── chat_service.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── marketplace/
│   │   ├── marketplace_screen.dart
│   │   └── product_detail_screen.dart
│   ├── chat/
│   │   ├── chat_list_screen.dart
│   │   └── chat_screen.dart
│   └── profile/
│       ├── profile_screen.dart
│       └── edit_profile_screen.dart
└── main.dart
```

## Design System

- **Primary Color**: Vibrant Yellow (#FFE500)
- **Secondary Color**: Light Grey (#F5F5F5)
- **Accent Colors**: Green (#4CAF50), Blue (#2196F3)
- **Heading Font**: Playfair Display (Serif)
- **Body Font**: Roboto (Sans-serif)

## Getting Started

1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Set up Firebase:
   - Create a Firebase project
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Enable Authentication, Firestore, and Storage

3. Run the app:
   ```bash
   flutter run
   ```

## Features

- User authentication
- Product listing and browsing
- Real-time chat
- User profiles
- Image uploads




