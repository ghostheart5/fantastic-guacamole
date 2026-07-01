import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/error_handler.dart';
import '../../data/services/auth_service.dart';

class AuthSessionController extends ChangeNotifier {
  AuthSessionController({AuthService? authService})
      : _authService = authService ?? AuthService(),
        _isMounted = true;

  static const String demoEmail = 'demo@chronospark.app';
  static const String demoPassword = 'chronospark123';
  static const String _sessionEmailKey = 'auth.session.email';
  static const String _sessionDemoKey = 'auth.session.demo';

  final AuthService _authService;
  bool _isMounted;
  StreamSubscription<User?>? _authSub;

  bool _isLoading = true;
  bool _isSignedIn = false;
  bool _isDemoSession = false;
  String? _email;
  String? _errorMessage;
  bool get allowDemoAuth => kDebugMode;

  bool get isLoading => _isLoading;
  bool get isSignedIn => _isSignedIn;
  bool get isDemoSession => _isDemoSession;
  String? get email => _email;
  String? get errorMessage => _errorMessage;

  Future<void> bootstrap() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Do not auto-restore demo sessions on app restart.
    // This prevents bypassing the login screen in debug builds.
    if (allowDemoAuth && (prefs.getBool(_sessionDemoKey) ?? false)) {
      await _clearSessionMetadata(prefs);
      _isSignedIn = false;
      _isDemoSession = false;
      _email = null;
    }

    final User? firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      await _authService.signOut();
      await _clearSessionMetadata(prefs);
      _isSignedIn = false;
      _isDemoSession = false;
      _email = null;
    } else if (!allowDemoAuth && _isDemoSession) {
      await _clearSessionMetadata(prefs);
      _isSignedIn = false;
      _isDemoSession = false;
      _email = null;
    }

    // Cancel any existing subscription to prevent memory leak
    await _authSub?.cancel();
    
    _authSub = _authService.authStateChanges().listen((User? user) async {
      if (user == null) {
        if (_isDemoSession) {
          return;
        }
        _isSignedIn = false;
        _isDemoSession = false;
        _email = null;
        if (_isMounted) notifyListeners();
        return;
      }

      final String resolvedEmail = user.email ?? user.uid;
      try {
        final SharedPreferences streamPrefs = await SharedPreferences.getInstance();
        if (_isMounted) {
          await _persistSessionMetadata(streamPrefs, email: resolvedEmail, isDemo: false);
        }
      } catch (e) {
        if (_isMounted) {
          _errorMessage = 'Session sync failed: $e';
          notifyListeners();
        }
      }
    });

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    _errorMessage = null;

    if (allowDemoAuth && normalizedEmail == demoEmail && password == demoPassword) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await _persistSessionMetadata(prefs, email: demoEmail, isDemo: true);
      return;
    }

    try {
      final UserCredential credential = await _authService.signIn(
        email: email.trim(),
        password: password,
      );
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await _persistSessionMetadata(
        prefs,
        email: credential.user?.email ?? email.trim(),
        isDemo: false,
      );
    } on FirebaseAuthException catch (error) {
      _errorMessage = ErrorHandler.getUserFriendlyAuthError(error);
      notifyListeners();
      rethrow;
    } catch (error) {
      _errorMessage = 'Sign-in failed: ${ErrorHandler.getUserFriendlyPurchaseError(error)}';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!_isDemoSession) {
      await _authService.signOut();
    }

    await _clearSessionMetadata(prefs);
    _isSignedIn = false;
    _isDemoSession = false;
    _email = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) async {
    final String normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw StateError('Enter a valid email address.');
    }

    try {
      await _authService.sendPasswordReset(normalizedEmail);
      _errorMessage = null;
      notifyListeners();
    } on FirebaseAuthException catch (error) {
      _errorMessage = ErrorHandler.getUserFriendlyAuthError(error);
      notifyListeners();
      rethrow;
    } catch (error) {
      _errorMessage = 'Could not send reset email: $error';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _persistSessionMetadata(
    SharedPreferences prefs, {
    required String email,
    required bool isDemo,
  }) async {
    await prefs.setBool(_sessionDemoKey, isDemo);
    await prefs.setString(_sessionEmailKey, email);
    _isSignedIn = true;
    _isDemoSession = isDemo;
    _email = email;
    notifyListeners();
  }

  Future<void> _clearSessionMetadata(SharedPreferences prefs) async {
    await prefs.remove(_sessionDemoKey);
    await prefs.remove(_sessionEmailKey);
  }

  @override
  void dispose() {
    _isMounted = false;
    _authSub?.cancel();
    super.dispose();
  }
}
