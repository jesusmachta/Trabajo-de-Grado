import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      role: json['role'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class AuthController with ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;

  // Constructor loads saved credentials
  AuthController() {
    _loadSavedCredentials();
  }

  // Load saved credentials from SharedPreferences
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');
    final savedUser = prefs.getString('user');

    if (savedToken != null && savedUser != null) {
      _token = savedToken;
      _currentUser = User.fromJson(jsonDecode(savedUser));
      notifyListeners();
    }
  }

  // Save credentials to SharedPreferences
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null && _currentUser != null) {
      await prefs.setString('token', _token!);
      await prefs.setString(
          'user',
          jsonEncode({
            'id': _currentUser!.id,
            'email': _currentUser!.email,
            'full_name': _currentUser!.fullName,
            'role': _currentUser!.role,
            'created_at': _currentUser!.createdAt.toIso8601String(),
          }));
    }
  }

  // Clear saved credentials
  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  // Login method (mock implementation)
  Future<bool> login(String email, String password, bool rememberMe) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    try {
      // Mock credentials check
      if (email == 'admin@storesense.com' && password == 'admin123') {
        // Create mock user and token
        _token = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
        _currentUser = User(
          id: '1',
          email: email,
          fullName: 'Admin User',
          role: 'admin',
          createdAt: DateTime.now(),
        );

        // Save credentials if remember me is checked
        if (rememberMe) {
          await _saveCredentials();
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Credenciales inválidas';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error de conexión. Intente de nuevo más tarde.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout method
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await _clearCredentials();
    notifyListeners();
  }

  // Validate token (mock implementation)
  Future<bool> validateToken() async {
    if (_token == null) return false;

    // In a real app, we would verify the token with the backend
    // For now, just return true if we have a token
    return true;
  }
}
