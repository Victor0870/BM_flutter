import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Provider cho Admin: chỉ đăng nhập Firebase Auth và kiểm tra quyền admin qua collection admins/{uid}.
class AdminAuthProvider with ChangeNotifier {
  User? _user;
  bool _isAdmin = false;
  bool _isCheckingAdmin = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isAdmin => _isAdmin;
  bool get isCheckingAdmin => _isCheckingAdmin;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AdminAuthProvider() {
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) _checkAdmin();
    FirebaseAuth.instance.authStateChanges().listen((User? u) {
      _user = u;
      if (u != null) {
        _checkAdmin();
      } else {
        _isAdmin = false;
        notifyListeners();
      }
    });
  }

  Future<void> _checkAdmin() async {
    if (_user == null) {
      _isAdmin = false;
      notifyListeners();
      return;
    }
    _isCheckingAdmin = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(_user!.uid)
          .get();
      _isAdmin = doc.exists && (doc.data()?['admin'] == true);
    } catch (e) {
      _isAdmin = false;
      _errorMessage = e.toString();
    }
    _isCheckingAdmin = false;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _checkAdmin();
      return _isAdmin;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? e.code;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    _user = null;
    _isAdmin = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
