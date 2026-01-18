import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'screens/intro/intro_page.dart';
import 'screens/main/main_screen.dart';
import 'providers/product_provider.dart';
import 'providers/chat_provider.dart';
import 'services/stripe_payment_service.dart';

void main() async {
  // Ensure Flutter binding is initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handling to prevent black screens
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('❌ Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Set preferred orientations (optional)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('❌ Firebase initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');
    // Re-throw to prevent app from running with broken Firebase
    rethrow;
  }

  // Initialize Stripe
  try {
    await StripePaymentService.initialize();
    debugPrint('✅ Stripe initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Stripe initialization failed: $e');
  }

  // Run the app
  runApp(const VinTradeApp());
}

class VinTradeApp extends StatelessWidget {
  const VinTradeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'VinTrade',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // Use StreamBuilder for auth persistence
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Show loading while checking auth state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppTheme.white,
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.primaryYellow),
                  ),
                ),
              );
            }

            // If user is logged in, show MainScreen
            if (snapshot.hasData && snapshot.data != null) {
              return const MainScreen();
            }

            // If user is not logged in, show IntroPage
            return const IntroPage();
          },
        ),
        // Add error handling
        builder: (context, child) {
          // Ensure we always have a valid widget tree
          if (child == null) {
            return const Scaffold(
              backgroundColor: AppTheme.white,
              body: Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryYellow),
                ),
              ),
            );
          }
          return child;
        },
      ),
    );
  }
}

