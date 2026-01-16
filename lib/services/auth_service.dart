import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String studentId,
    required String faculty,
  }) async {
    // Validate UTHM email
    if (!email.endsWith('@student.uthm.edu.my') &&
        !email.endsWith('@uthm.edu.my')) {
      throw Exception('Please use your official UTHM student email.');
    }

    try {
      // Create user with email and password - wrapped in try-catch
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Get the user from credential
      final User? user = credential.user;
      
      if (user == null) {
        throw Exception('Failed to create user account. Please try again.');
      }

      // Update display name in Firebase Auth
      try {
        await user.updateDisplayName(displayName.trim());
        await user.reload();
      } catch (updateError) {
        print('⚠️ Warning: Failed to update display name: $updateError');
        // Continue even if display name update fails
      }

      // Create user document in Firestore with proper Map<String, dynamic>
      try {
        final userData = <String, dynamic>{
          'uid': user.uid,
          'email': email.trim(),
          'displayName': displayName.trim(),
          'studentId': studentId.trim(),
          'faculty': faculty,
          'created_at': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('users').doc(user.uid).set(userData);
        print('✅ User document created in Firestore for ${user.uid}');
      } catch (firestoreError, stackTrace) {
        print('❌ Error creating user document in Firestore: $firestoreError');
        print('Stack trace: $stackTrace');
        // Don't throw here - user is already created in Auth, just log the error
        // You might want to retry this later or handle it differently
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Exception: ${e.code} - ${e.message}');
      throw Exception(_handleAuthException(e));
    } catch (e, stackTrace) {
      print('❌ Unexpected error during sign up: $e');
      print('Stack trace: $stackTrace');
      if (e.toString().contains('Please use your official UTHM student email')) {
        rethrow;
      }
      throw Exception('An error occurred during registration: $e');
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Get current user before signing out
      final currentUser = _auth.currentUser;
      
      if (currentUser == null) {
        // User is already logged out, return successfully
        debugPrint('User is already logged out');
        return;
      }

      // Sign out from Firebase Auth
      await _auth.signOut();
      
      // Verify sign out was successful
      if (_auth.currentUser != null) {
        throw Exception('Failed to sign out. User is still authenticated.');
      }
      
      debugPrint('✅ User signed out successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth error during sign out: ${e.code} - ${e.message}');
      throw Exception('Error signing out: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('❌ Error signing out: $e');
      throw Exception('Error signing out: $e');
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        debugPrint('✅ Verification email sent to ${user.email}');
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('An error occurred sending verification email: $e');
    }
  }

  // Reload user to check email verification status
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      debugPrint('Error reloading user: $e');
    }
  }

  // Check if user email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      await currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  // Handle Firebase Auth Exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}
