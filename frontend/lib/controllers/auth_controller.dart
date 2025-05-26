import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../views/login_view.dart';

class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final DateTime createdAt;
  final String? profilePicture;
  final bool isActive;
  final String? empresa;
  final String? rif;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
    this.profilePicture,
    this.isActive = true,
    this.empresa,
    this.rif,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['user_id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? 'user',
      profilePicture: json['profile_picture'],
      isActive: json['is_active'] ?? true,
      empresa: json['empresa'],
      rif: json['rif'],
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
  bool _isInitializing = true;
  String? _error;

  // API base URL - change this to match your backend
  final String _baseUrl = 'http://localhost:8000/api';

  // Getters
  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get error => _error;
  bool get isAuthenticated => _token != null;

  // Constructor calls the initialization method
  AuthController() {
    _initialize();
  }

  // Initialization method to load credentials
  Future<void> _initialize() async {
    await _loadSavedCredentials();
    _isInitializing = false;
    notifyListeners();
  }

  // Helper to properly encode profile picture URLs
  String? _encodeProfilePictureUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    print('Original profile picture URL: $url');

    try {
      // Handle specific case for tesislospomelos bucket
      if (url.contains('tesislospomelos.s3.amazonaws.com')) {
        print('Detected tesislospomelos S3 URL');

        // Direct access format for S3 - no transformation needed for this bucket
        // Just ensure proper encoding
        final encodedUrl = url.replaceAll(' ', '%20');
        print('Encoded tesislospomelos URL: $encodedUrl');
        return encodedUrl;
      }
      // Check if it's another S3 URL
      else if (url.contains('s3.amazonaws.com')) {
        print('Detected other S3 URL');
        // Convert https://bucketname.s3.amazonaws.com/key to https://s3.amazonaws.com/bucketname/key format
        // This alternate format often works better with public access settings
        final uri = Uri.parse(url);
        final host = uri.host;

        if (host.endsWith('s3.amazonaws.com')) {
          // Extract bucket name from the hostname (e.g., "bucketname.s3.amazonaws.com")
          final bucketName = host.split('.').first;

          // Get the path without leading slash
          final objectKey =
              uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;

          // Build URL in the alternative format
          final formattedUrl =
              'https://s3.amazonaws.com/$bucketName/$objectKey';
          print('Reformatted S3 URL: $formattedUrl');
          return formattedUrl;
        }
      }

      // If not an S3 URL or already in the right format, just encode it properly
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments.map(Uri.encodeComponent).join('/');
      final encodedUrl =
          '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}/$pathSegments';
      print('Generally encoded URL: $encodedUrl');
      return encodedUrl;
    } catch (e) {
      // If URL parsing fails, fall back to basic space encoding
      print('Error encoding URL: $e');
      return url.replaceAll(' ', '%20');
    }
  }

  // Load saved credentials from SharedPreferences
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');
    final savedUser = prefs.getString('user');

    if (savedToken != null && savedUser != null) {
      try {
        _token = savedToken;
        final userData = jsonDecode(savedUser);

        // Encode profile picture URL if exists
        if (userData['profile_picture'] != null) {
          userData['profile_picture'] =
              _encodeProfilePictureUrl(userData['profile_picture']);
        }

        _currentUser = User.fromJson(userData);
      } catch (e) {
        print('Error loading saved credentials: $e');
        await _clearCredentials();
        _token = null;
        _currentUser = null;
      }
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
            'empresa': _currentUser!.empresa,
            'rif': _currentUser!.rif,
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

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _token = responseData['access_token'];
        _currentUser = User(
          id: responseData['user_id']?.toString() ?? '',
          email: responseData['email'] ?? '',
          fullName: responseData['full_name'] ?? '',
          role: responseData['role'] ?? 'user',
          profilePicture: responseData['profile_picture'],
          isActive: responseData['is_active'] ?? true,
          createdAt: DateTime.now(),
          empresa: responseData['empresa'],
          rif: responseData['rif'],
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

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        final isActive = responseData['is_active'] ?? true;
        if (!isActive) {
          _error = 'Tu cuenta está inactiva. Contacta al administrador.';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        _token = responseData['access_token'];

        // Encode profile picture URL if exists
        String? profilePictureUrl = responseData['profile_picture'];
        if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
          profilePictureUrl = _encodeProfilePictureUrl(profilePictureUrl);
          print('Profile picture URL from login: $profilePictureUrl');
        }

        _currentUser = User(
          id: responseData['user_id']?.toString() ?? '',
          email: responseData['email'] ?? '',
          fullName: responseData['full_name'] ?? '',
          role: responseData['role'] ?? 'user',
          profilePicture: profilePictureUrl,
          isActive: responseData['is_active'] ?? true,
          createdAt: DateTime.now(),
          empresa: responseData['empresa'],
          rif: responseData['rif'],
        );

        await _saveCredentials();

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
      _error = 'Error de conexión. Intente de nuevo más tarde: $e';
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

  // Update current user's profile picture
  Future<bool> updateProfilePicture(String newProfilePictureUrl) async {
    if (_currentUser == null) return false;

    try {
      // Create a new user with the updated profile picture URL
      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        fullName: _currentUser!.fullName,
        role: _currentUser!.role,
        createdAt: _currentUser!.createdAt,
        isActive: _currentUser!.isActive,
        profilePicture: _encodeProfilePictureUrl(newProfilePictureUrl),
        empresa: _currentUser!.empresa,
        rif: _currentUser!.rif,
      );

      // Save updated user to SharedPreferences
      await _saveCredentials();

      // Notify listeners to update UI
      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating profile picture: $e');
      return false;
    }
  }

  // Update current user's info from server response
  Future<bool> updateUserInfo(Map<String, dynamic> userData) async {
    if (_currentUser == null) return false;

    try {
      // Create new user object with updated info from server
      final updatedUser = User.fromJson(userData);

      // Update current user
      _currentUser = updatedUser;

      // Save to persistent storage
      await _saveCredentials();

      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating user info: $e');
      return false;
    }
  }

  // Validate token (real implementation)
  Future<bool> validateToken() async {
    if (_token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token'
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Solo hacemos logout si el servidor explícitamente rechaza el token
        await logout();
        return false;
      } else {
        // Para otros códigos de error (500, etc.), asumimos que es un error temporal
        // y no invalidamos el token automáticamente
        print(
            'Error validando token: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
        return true; // Mantenemos al usuario como autenticado en caso de errores del servidor
      }
    } catch (e) {
      // Para errores de red o conexión, no hacemos logout automáticamente
      print('Error de conexión al validar token: $e');
      return true; // Mantenemos al usuario como autenticado en caso de errores de red
    }
  }

  // Check authentication status and redirect if not authenticated
  void checkAuthAndRedirect(BuildContext context) {
    if (!isAuthenticated) {
      // Forzar redirección al login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginView(
            toggleTheme: () {}, // Necesitas manejar esto apropiadamente
          ),
        ),
        (route) => false,
      );
    }
  }

  // Refresh user data from the server
  Future<bool> refreshUserData() async {
    if (_token == null) return false;

    print('Starting user data refresh');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      print('User data refresh response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        print('User data response: $responseData');

        final userData = responseData['data'];

        if (userData != null) {
          print('User data contains: ${userData.keys.join(', ')}');

          // Encode profile picture URL if exists
          String? profilePictureUrl = userData['profile_picture'];
          print(
              'Original profile picture URL from refresh: $profilePictureUrl');

          if (profilePictureUrl != null) {
            profilePictureUrl = _encodeProfilePictureUrl(profilePictureUrl);
            print(
                'Encoded profile picture URL after refresh: $profilePictureUrl');
          }

          // Update current user with fresh data
          _currentUser = User(
            id: userData['_id']?.toString() ?? _currentUser!.id,
            email: userData['email'] ?? _currentUser!.email,
            fullName: userData['full_name'] ?? _currentUser!.fullName,
            role: userData['role'] ?? _currentUser!.role,
            profilePicture: profilePictureUrl,
            isActive: userData['is_active'] ?? true,
            createdAt: userData['created_at'] != null
                ? DateTime.parse(userData['created_at'])
                : _currentUser!.createdAt,
            empresa: userData['empresa'],
            rif: userData['rif'],
          );

          // Save updated user data
          await _saveCredentials();
          print('User data saved to SharedPreferences');
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error refreshing user data: $e');
      return false;
    }
  }
}
