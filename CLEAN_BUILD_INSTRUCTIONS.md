# Clean Build Instructions

## Fixing "PigeonUserDetails" Type Cast Error

This error is typically caused by stale build artifacts or version mismatches. Follow these steps in order:

### Step 1: Clean Flutter Build
```bash
flutter clean
```

### Step 2: Get Updated Dependencies
```bash
flutter pub get
```

### Step 3: Clean Android Gradle Build
```bash
cd android
./gradlew clean
cd ..
```

### Step 4: Clean Android Build Cache (Windows PowerShell)
```powershell
# Remove Gradle cache
Remove-Item -Recurse -Force $env:USERPROFILE\.gradle\caches
Remove-Item -Recurse -Force $env:USERPROFILE\.gradle\wrapper

# Clean Android build directories
Remove-Item -Recurse -Force android\.gradle -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\app\build -ErrorAction SilentlyContinue
```

### Step 5: Invalidate Caches (If using Android Studio)
1. File → Invalidate Caches / Restart
2. Select "Invalidate and Restart"

### Step 6: Rebuild
```bash
flutter run
```

## Alternative: Full Clean (If above doesn't work)

```powershell
# 1. Clean Flutter
flutter clean

# 2. Remove pub cache
Remove-Item -Recurse -Force $env:USERPROFILE\.pub-cache\hosted\pub.dev\firebase_* -ErrorAction SilentlyContinue

# 3. Clean Android completely
cd android
Remove-Item -Recurse -Force .gradle -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force app\build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
.\gradlew clean
cd ..

# 4. Get fresh dependencies
flutter pub get

# 5. Run
flutter run
```

## Verification

After cleaning, you should see:
- ✅ No "PigeonUserDetails" errors
- ✅ Firebase initialized successfully
- ✅ User registration works without type cast errors





