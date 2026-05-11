import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Authentication Controller
///
/// Manages Google Sign-In via Firebase Auth (google_sign_in v7.2+).
/// Exposes an auth state stream so the UI reactively switches
/// between LoginScreen and NotesListScreen.
///
/// v7 API notes:
///  • GoogleSignIn.instance (singleton)
///  • initialize() called once
///  • authenticate() returns GoogleSignInAccount (throws on cancel)
///  • GoogleSignInAuthentication only exposes idToken (no accessToken)
///  • Firebase credential only needs idToken for Google provider
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Controller managing user authentication state and Google Sign-In.
class AuthController extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  bool _isLoading = false;
  String? _errorMessage;

  // ─── Getters ───

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Whether a user is currently signed in.
  bool get isSignedIn => _auth.currentUser != null;

  /// Returns the currently signed-in Firebase user, or null.
  User? getCurrentUser() => _auth.currentUser;

  /// Stream that emits every time the user signs in or out.
  /// Used by the root StreamBuilder to swap screens automatically.
  /// Firebase persists the session, so the user stays logged in
  /// across app restarts without any extra work.
  Stream<User?> get authStateStream => _auth.authStateChanges();

  /// Convenience getters for display.
  String? get userName => _auth.currentUser?.displayName;
  String? get userEmail => _auth.currentUser?.email;
  String? get userPhotoUrl => _auth.currentUser?.photoURL;

  // ─── Initialise GoogleSignIn (v7 requirement) ───

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _googleSignIn.initialize();
      _initialized = true;
    }
  }

  // ─── Sign In with Google ───

  /// Full Google Sign-In → Firebase Auth flow.
  ///
  /// 1. Initialise GoogleSignIn (first time only).
  /// 2. Open Google account picker via authenticate().
  /// 3. Retrieve the idToken from authentication.
  /// 4. Create a Firebase credential and sign in.
  /// 5. Notify listeners so the UI updates.
  // AI NOTE: Initiates the Google Sign-In flow and authenticates with Firebase.
  Future<User?> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1 — Ensure GoogleSignIn is initialised
      await _ensureInitialized();

      // Step 2 — Trigger the Google authentication flow (v7 API).
      // authenticate() returns GoogleSignInAccount directly;
      // it throws GoogleSignInException on cancel / error.
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // Step 3 — Get the idToken.
      // In v7, GoogleSignInAuthentication only has idToken (no accessToken).
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Step 4 — Create a Firebase credential with only the idToken.
      // GoogleAuthProvider.credential accepts idToken alone.
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Step 5 — Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      _isLoading = false;
      notifyListeners();

      return userCredential.user;
    } on GoogleSignInException catch (e) {
      // User cancelled the picker, or another Google Sign-In error
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User just cancelled — not an error to display
        _isLoading = false;
        notifyListeners();
        return null;
      }
      _errorMessage = 'Google Sign-In failed: ${e.description ?? e.code.name}';
      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
      if (kDebugMode) debugPrint('Google Sign-In error: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ─── Email & Password Auth ───

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
      return null;
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
      if (kDebugMode) debugPrint('Email Sign-In error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<User?> signUpWithEmailAndPassword(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // Update display name
      await userCredential.user?.updateDisplayName(name.trim());
      // Reload user so the display name is available immediately
      await userCredential.user?.reload();
      
      return _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
      return null;
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
      if (kDebugMode) debugPrint('Email Sign-Up error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    if (email.trim().isEmpty) {
      _errorMessage = 'Please enter your email to reset password.';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
      if (kDebugMode) debugPrint('Password Reset error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Sign Out ───

  /// Signs out of both Firebase and Google, then clears session.
  /// The auth state stream will emit null, causing the UI to
  /// navigate back to the LoginScreen automatically.
  // AI NOTE: Signs the user out of both Firebase and Google accounts.
  Future<void> signOut() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Sign out of Google so the account picker shows next time
      await _ensureInitialized();
      await _googleSignIn.signOut();

      // Sign out of Firebase (clears persisted session)
      await _auth.signOut();
    } catch (e) {
      _errorMessage = 'Could not sign out. Please try again.';
      if (kDebugMode) debugPrint('Sign-out error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Clear Error ───

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Helpers ───

  /// Converts Firebase error codes to user-friendly messages.
  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-credential':
        return 'Invalid login credentials. Please try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'operation-not-allowed':
        return 'Sign-In method is not enabled. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
