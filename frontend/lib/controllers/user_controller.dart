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
        Uri.parse('http://127.0.0.1:8000/api/users'),
        headers: {
          'Authorization': 'Bearer $token', // Agregar el token JWT aquí
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data =
            json.decode(utf8.decode(response.bodyBytes))['data'];
        _users = data.map((user) => User.fromJson(user)).toList();
      } else {
        _error = 'Error al cargar usuarios: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error de red: ${e.toString()}';
    } finally {
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
    required String dateOfBirth,
    required String securityQuestion,
    required String securityAnswer,
    int? rif,
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
          'date_of_birth': dateOfBirth,
          'security_question': securityQuestion,
          'security_answer': securityAnswer,
          if (rif != null) 'rif': rif,
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
  Future<bool> updateUser(
    String token,
    User user, {
    String? password,
    String? securityAnswer,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final body = {
        'email': user.email,
        'full_name': user.fullName,
        'role': user.role,
        'is_active': user.isActive,
        'profile_picture': user.profilePicture,
        'date_of_birth': user.dateOfBirth,
        'security_question': user.securityQuestion,
      };

      // Solo incluir la contraseña si se proporciona
      if (password != null && password.isNotEmpty) {
        body['password'] = password;
      }

      // Include security answer if provided
      if (securityAnswer != null && securityAnswer.isNotEmpty) {
        body['security_answer'] = securityAnswer;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/users/${user.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // Actualizar el usuario en la lista
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

  // Toggle user status (simple version using existing update)
  Future<bool> toggleUserStatus(String token, User user) async {
    final updatedUser = user.copyWith(isActive: !user.isActive);
    return await updateUser(token, updatedUser);
  }

  // Toggle user status directly with endpoint
  Future<bool> toggleUserStatusDirect(
      String token, String userId, bool newStatus) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$userId/toggle-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'is_active': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        // Update the user in the list
        final index = _users.indexWhere((u) => u.id == userId);
        if (index != -1) {
          final updatedUser = _users[index].copyWith(isActive: newStatus);
          _users[index] = updatedUser;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final responseData = jsonDecode(response.body);
        _error =
            responseData['detail'] ?? 'Error al actualizar estado de usuario';
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
        // Eliminar el usuario de la lista local
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
