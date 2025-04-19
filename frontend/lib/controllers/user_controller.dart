import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class UserController with ChangeNotifier {
  List<User> _users = [];
  bool _isLoading = false;
  String? _error;

  // API base URL - change this to match your backend
  final String _baseUrl = 'http://127.0.0.1:8000/api';

  // Getters
  List<User> get users => [..._users];
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fetch all users
  Future<void> fetchUsers(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody.containsKey('data') && responseBody['data'] is List) {
          final List<dynamic> responseData = responseBody['data'];
          _users =
              responseData.map((userData) => User.fromJson(userData)).toList();
        } else {
          _users = []; // Reset users if the response format is unexpected
          _error = 'Formato de respuesta inesperado';
        }
        _isLoading = false;
        notifyListeners();
      } else if (response.statusCode == 401) {
        _error =
            'Sesión expirada o no autorizada. Por favor inicie sesión nuevamente.';
        _users = [];
        _isLoading = false;
        notifyListeners();
      } else {
        try {
          final responseData = jsonDecode(response.body);
          _error = responseData['detail'] ??
              'Error al obtener usuarios: ${response.statusCode}';
        } catch (e) {
          _error = 'Error al obtener usuarios: ${response.statusCode}';
        }
        _users = [];
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _error =
          'Error de conexión: ${e.toString()}. Intente de nuevo más tarde.';
      _users = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new user
  Future<bool> addUser(
    String token, {
    required String email,
    required String password,
    required String fullName,
    String role = 'user',
    String? profilePicture,
    bool isActive = true,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/signup'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
          'role': role,
          'profile_picture': profilePicture,
          'is_active': isActive,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchUsers(token); // Refresh user list
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = responseData['detail'] ?? 'Error al agregar usuario';
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

  // Update user
  Future<bool> updateUser(String token, User user) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/${user.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': user.email,
          'full_name': user.fullName,
          'role': user.role,
          'profile_picture': user.profilePicture,
          'is_active': user.isActive,
        }),
      );

      if (response.statusCode == 200) {
        // Update the user in the list
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          _users[index] = user;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final responseData = jsonDecode(response.body);
        _error = responseData['detail'] ?? 'Error al actualizar usuario';
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

  // Toggle user status
  Future<bool> toggleUserStatus(String token, User user) async {
    final updatedUser = user.copyWith(isActive: !user.isActive);
    return await updateUser(token, updatedUser);
  }

  // Delete user
  Future<bool> deleteUser(String token, String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Remove the user from the list
        _users.removeWhere((user) => user.id == userId);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final responseData = jsonDecode(response.body);
        _error = responseData['detail'] ?? 'Error al eliminar usuario';
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
}
