import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final DateTime createdAt;
  final String? profilePicture;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
    this.profilePicture,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['user_id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? 'user',
      profilePicture: json['profile_picture'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class AuthController with ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _error;

  // API base URL - change this to match your backend
  final String _baseUrl = 'http://localhost:8000/api';

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
            'profile_picture': _currentUser!.profilePicture,
            'is_active': _currentUser!.isActive,
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

  // SignUp method
  Future<bool> signup(String email, String password, String fullName,
      {String role = 'user', String? profilePicture}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
          'role': role,
          'profile_picture': profilePicture,
          'is_active': true,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _token = responseData['access_token'];
        _currentUser = User(
          id: responseData['user_id'],
          email: responseData['email'],
          fullName: responseData['full_name'],
          role: responseData['role'],
          profilePicture: responseData['profile_picture'],
          isActive: responseData['is_active'] ?? true,
          createdAt: DateTime.now(),
        );

        await _saveCredentials();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = responseData['detail'] ?? 'Error al registrar usuario';
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

  // Login method
  Future<bool> login(String email, String password, bool rememberMe) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Check if user is active
        final isActive = responseData['is_active'] ?? true;
        if (!isActive) {
          _error = 'Tu cuenta está inactiva. Contacta al administrador.';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        _token = responseData['access_token'];
        _currentUser = User(
          id: responseData['user_id'],
          email: responseData['email'],
          fullName: responseData['full_name'],
          role: responseData['role'],
          profilePicture: responseData['profile_picture'],
          isActive: isActive,
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
        _error = responseData['detail'] ?? 'Credenciales inválidas';
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

  // Validate token (real implementation)
  Future<bool> validateToken() async {
    if (_token == null) return false;

    try {
      // You can add a token validation endpoint to your backend if needed
      return true;
    } catch (e) {
      await logout();
      return false;
    }
  }
}
