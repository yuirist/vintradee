# Firebase Setup Instructions

## Current Status
✅ `main.dart` has been updated with proper Firebase initialization
✅ `firebase_options.dart` file structure created

## Next Steps

### Option 1: Using FlutterFire CLI (Recommended)

1. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Configure Firebase for your project:
   ```bash
   flutterfire configure
   ```

3. Select your Firebase project: `vintrade-c835b`

4. Select platforms: Android, iOS (and Web if needed)

This will automatically generate the correct `firebase_options.dart` file with your project's configuration.

### Option 2: Manual Configuration

If you prefer to configure manually:

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project: `vintrade-c835b`
3. Go to Project Settings
4. For each platform (Android, iOS, Web), copy the configuration values
5. Update `lib/firebase_options.dart` with the actual values:
   - `apiKey`
   - `appId`
   - `messagingSenderId`
   - `projectId` (already set to `vintrade-c835b`)
   - `authDomain` (for web)
   - `storageBucket` (already set)
   - `iosBundleId` (for iOS)

## Verification

After configuration, run:
```bash
flutter run
```

You should see in the console:
```
✅ Firebase initialized successfully
```

If you see errors, check:
- Firebase project exists and is active
- Platform-specific configuration files are in place:
  - Android: `android/app/google-services.json`
  - iOS: `ios/Runner/GoogleService-Info.plist`




