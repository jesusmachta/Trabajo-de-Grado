import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/user_controller.dart';
// Hide the User class from auth_controller to avoid conflict
import '../controllers/auth_controller.dart' hide User;
import '../models/user_model.dart'; // Use this User model
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/toast_notification.dart'; // Import the new ToastService
import 'package:intl/intl.dart'; // For date formatting
import 'package:image_picker/image_picker.dart';
import '../utils/image_picker_helper.dart';
import 'dart:typed_data';

class UsersView extends StatefulWidget {
  final Function toggleTheme;

  const UsersView({super.key, required this.toggleTheme});

  @override
  State<UsersView> createState() => _UsersViewState();
}

enum UserStatusFilter { todos, activo, inactivo }

enum UserRoleFilter { todos, admin, user }

class _UsersViewState extends State<UsersView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  UserStatusFilter _selectedStatus = UserStatusFilter.todos;
  UserRoleFilter _selectedRoleFilter = UserRoleFilter.todos;

  // Pagination variables
  int _currentPage = 1;
  final int _itemsPerPage = 10; // Fixed at 10 rows per page
  int _totalPages = 1;

  // Text controllers for input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _securityAnswerController =
      TextEditingController();
  String _selectedRole = 'user';
  bool _selectedIsActive = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedSecurityQuestion = securityQuestions.first;

  // Variables para manejar la imagen de perfil
  Uint8List? _profileImageBytes;
  String? _profileImageBase64;
  String? _selectedProfilePicture;

  // Security questions list
  static const List<String> securityQuestions = [
    "¿Cuál es el nombre de tu primera mascota?",
    "¿En qué ciudad naciste?",
    "¿Cuál fue el nombre de tu escuela primaria?",
    "¿Cuál es el segundo nombre de tu madre?",
    "¿Cuál fue tu primer trabajo?",
  ];

  bool _isEditMode = false;
  String? _editingUserId;

  // --- NUEVO: Para el ojito y validación de contraseña ---
  bool _obscurePassword = true;
  String? _passwordValidationMessage;

  // Estado de carga para switches individuales
  Set<String> _loadingUserIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text;
        _currentPage = 1; // Reset to first page on search
      });
    });
    // Load users when the view is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _securityAnswerController.dispose();
    super.dispose();
  }

  void _loadUsers() {
    final authController = Provider.of<AuthController>(context, listen: false);
    final userController = Provider.of<UserController>(context, listen: false);

    if (authController.token != null) {
      try {
        userController.fetchUsers(authController.token!).catchError((error) {
          ToastService.showError(
              context, 'Error al cargar usuarios: ${error.toString()}');
        });
      } catch (e) {
        // Manejar errores síncronos
        ToastService.showError(
            context, 'Error al iniciar carga de usuarios: ${e.toString()}');
      }
    } else {
      // Informar al usuario que necesita iniciar sesión
      ToastService.showWarning(
          context, 'Sesión no iniciada. Por favor inicie sesión primero.');
    }
  }

  void _showAddUserDialog() {
    _clearForm();
    _isEditMode = false;
    _editingUserId = null;
    showDialog(
      context: context,
      builder: (context) => _buildUserDialog(),
    );
  }

  void _showEditUserDialog(User user) {
    _clearForm();
    _emailController.text = user.email;
    _passwordController.text = ''; // La contraseña no se muestra para edición
    _fullNameController.text = user.fullName;
    _selectedRole = user.role;
    _selectedIsActive = user.isActive;
    _selectedProfilePicture = user.profilePicture;

    // Reset profile image variables
    _profileImageBytes = null;
    _profileImageBase64 = null;

    // Set date of birth if available
    if (user.dateOfBirth != null && user.dateOfBirth!.isNotEmpty) {
      try {
        _selectedDate = DateTime.parse(user.dateOfBirth!);
      } catch (e) {
        // Use default date if parsing fails
        _selectedDate = DateTime.now();
      }
    }

    // Set security question if available
    if (user.securityQuestion != null && user.securityQuestion!.isNotEmpty) {
      if (securityQuestions.contains(user.securityQuestion)) {
        _selectedSecurityQuestion = user.securityQuestion!;
      }
    }

    _isEditMode = true;
    _editingUserId = user.id;

    showDialog(
      context: context,
      builder: (context) => _buildUserDialog(),
    );
  }

  void _clearForm() {
    _emailController.clear();
    _passwordController.clear();
    _fullNameController.clear();
    _securityAnswerController.clear();
    _selectedRole = 'user';
    _selectedIsActive = true;
    _selectedProfilePicture = null;
    _profileImageBytes = null;
    _profileImageBase64 = null;
    _selectedDate = DateTime.now();
    _selectedSecurityQuestion = securityQuestions.first;
    if (_formKey.currentState != null) {
      _formKey.currentState!.reset();
    }
  }

  // --- NUEVO: Validación de contraseña ---
  String? _validatePassword(String? value) {
    if (_isEditMode && (value == null || value.isEmpty))
      return null; // No obligatorio en edición
    if (value == null || value.isEmpty)
      return 'Por favor ingresa una contraseña';
    if (value.length < 6) return 'Debe tener al menos 6 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(value))
      return 'Debe tener al menos una mayúscula';
    if (!RegExp(r'[a-z]').hasMatch(value))
      return 'Debe tener al menos una minúscula';
    if (!RegExp(r'[0-9]').hasMatch(value))
      return 'Debe tener al menos un número';
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value))
      return 'Debe tener al menos un carácter especial';
    return null;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF0277BD), // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .color!, // Calendar text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Método para seleccionar una imagen
  Future<void> _pickImage(StateSetter setDialogState) async {
    try {
      final result = await ImagePickerHelper.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (result != null) {
        setDialogState(() {
          _profileImageBytes = result.bytes;
          _profileImageBase64 = result.base64String;
        });
      }
    } catch (e) {
      ToastService.showError(context, 'Error al seleccionar imagen: $e');
    }
  }

  Widget _buildUserDialog() {
    return StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        title: Text(_isEditMode ? 'Editar Usuario' : 'Agregar Usuario'),
        content: SizedBox(
          width: 650, // Más ancho aún
          height: 650, // Más alto para que no se vea aplastado
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Ingresa el correo electrónico',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa un email';
                      }
                      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value)) {
                        return 'Por favor ingresa un email válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // --- CAMPO DE CONTRASEÑA CON OJITO Y VALIDACIÓN ---
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      hintText: _isEditMode
                          ? 'Dejar en blanco para no cambiar'
                          : 'Ingresa la contraseña',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () {
                          setDialogState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      helperText:
                          'Mín. 6 caracteres, mayúscula, minúscula, número y especial',
                      errorText: _passwordValidationMessage,
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      final msg = _validatePassword(value);
                      setDialogState(() {
                        _passwordValidationMessage = msg;
                      });
                      return msg;
                    },
                    onChanged: (value) {
                      setDialogState(() {
                        _passwordValidationMessage = _validatePassword(value);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo',
                      hintText: 'Ingresa el nombre completo',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa un nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date of birth field
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha de nacimiento',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(_selectedDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Security question dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedSecurityQuestion,
                    decoration: const InputDecoration(
                      labelText: 'Pregunta de seguridad',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.security),
                    ),
                    items: securityQuestions.map((String question) {
                      return DropdownMenuItem<String>(
                        value: question,
                        child: Text(
                          question,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setDialogState(() {
                          _selectedSecurityQuestion = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Security answer field
                  TextFormField(
                    controller: _securityAnswerController,
                    decoration: const InputDecoration(
                      labelText: 'Respuesta de seguridad',
                      hintText: 'Ingresa tu respuesta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.question_answer),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                    validator: (value) {
                      if (!_isEditMode && (value == null || value.isEmpty)) {
                        return 'Por favor ingresa una respuesta de seguridad';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Profile picture section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Imagen de perfil',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Center(
                        child: Stack(
                          children: [
                            // Profile Image Preview
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey[400]!,
                                  width: 1,
                                ),
                                image: _profileImageBytes != null
                                    ? DecorationImage(
                                        image: MemoryImage(_profileImageBytes!),
                                        fit: BoxFit.cover,
                                      )
                                    : (_selectedProfilePicture != null &&
                                            _selectedProfilePicture!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(
                                                _selectedProfilePicture!),
                                            fit: BoxFit.cover,
                                          )
                                        : null),
                              ),
                              child: _profileImageBytes == null &&
                                      (_selectedProfilePicture == null ||
                                          _selectedProfilePicture!.isEmpty)
                                  ? const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),

                            // Edit button overlay
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0277BD),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.white, size: 20),
                                  onPressed: () => _pickImage(setDialogState),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Clear button
                      if (_profileImageBytes != null ||
                          (_selectedProfilePicture != null &&
                              _selectedProfilePicture!.isNotEmpty))
                        Center(
                          child: TextButton.icon(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Quitar imagen'),
                            onPressed: () {
                              setDialogState(() {
                                _profileImageBytes = null;
                                _profileImageBase64 = null;
                                _selectedProfilePicture = null;
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Rol',
                      border: OutlineInputBorder(),
                    ),
                    items: ['admin', 'user'].map((String role) {
                      return DropdownMenuItem<String>(
                        value: role,
                        child:
                            Text(role == 'admin' ? 'Administrador' : 'Usuario'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          _selectedRole = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<bool>(
                    value: _selectedIsActive,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<bool>(
                        value: true,
                        child: Text(
                          'Activo',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : null,
                          ),
                        ),
                      ),
                      DropdownMenuItem<bool>(
                        value: false,
                        child: Text(
                          'Inactivo',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : null,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          _selectedIsActive = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final authController =
                    Provider.of<AuthController>(context, listen: false);
                final userController =
                    Provider.of<UserController>(context, listen: false);

                final email = _emailController.text;
                final password = _passwordController.text;
                final fullName = _fullNameController.text;
                final role = _selectedRole;
                final isActive = _selectedIsActive;
                final dateOfBirth =
                    DateFormat('yyyy-MM-dd').format(_selectedDate);
                final securityQuestion = _selectedSecurityQuestion;
                final securityAnswer = _securityAnswerController.text;

                bool success = false;

                // Primero subir la imagen si se seleccionó una nueva
                String? profilePictureUrl = _selectedProfilePicture;

                // --- VALIDACIÓN: No permitir que el único admin se cambie a user o se inhabilite ---
                if (_isEditMode) {
                  final admins = userController.users
                      .where((u) => u.role == 'admin' && u.isActive)
                      .toList();
                  final editingUser = userController.users
                      .firstWhere((u) => u.id == _editingUserId);
                  final isCurrentUserAdmin = editingUser.role == 'admin';
                  final isChangingToUser = role == 'user';
                  final isChangingToInactive = isCurrentUserAdmin && !isActive;
                  if (isCurrentUserAdmin &&
                      admins.length == 1 &&
                      (isChangingToUser || isChangingToInactive)) {
                    ToastService.showWarning(context,
                        'Debe haber al menos un administrador activo en el sistema. Agregue otro administrador antes de cambiar este rol o desactivar este usuario.');
                    return;
                  }
                }

                if (_profileImageBase64 != null) {
                  try {
                    // Mostrar indicador de carga
                    ToastService.showInfo(context, 'Subiendo imagen...');

                    // Subir la imagen al servidor
                    final response = await http.post(
                      Uri.parse(
                          'http://localhost:8000/api/users/profile/picture/upload/web'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer ${authController.token}',
                      },
                      body: jsonEncode({
                        'image_base64': _profileImageBase64,
                      }),
                    );

                    if (response.statusCode == 200) {
                      final responseData = jsonDecode(response.body);
                      profilePictureUrl = responseData['profile_picture_url'];
                    } else {
                      ToastService.showError(
                          context, 'Error al subir la imagen');
                    }
                  } catch (e) {
                    ToastService.showError(
                        context, 'Error de conexión al subir imagen: $e');
                  }
                }

                if (_isEditMode && _editingUserId != null) {
                  final originalUser = userController.users
                      .firstWhere((u) => u.id == _editingUserId);

                  final updatedUser = originalUser.copyWith(
                    email: email,
                    fullName: fullName,
                    role: role,
                    isActive: isActive,
                    dateOfBirth: dateOfBirth,
                    securityQuestion: securityQuestion,
                    profilePicture: profilePictureUrl,
                  );

                  success = await userController.updateUser(
                    authController.token!,
                    updatedUser,
                    password: password.isNotEmpty ? password : null,
                    securityAnswer:
                        securityAnswer.isNotEmpty ? securityAnswer : null,
                  );
                } else {
                  int? rifInt;
                  final rifStr = authController.currentUser?.rif;
                  if (rifStr != null) {
                    rifInt = int.tryParse(rifStr);
                  }
                  success = await userController.addUser(
                    authController.token!,
                    email: email,
                    password: password,
                    fullName: fullName,
                    role: role,
                    isActive: isActive,
                    dateOfBirth: dateOfBirth,
                    securityQuestion: securityQuestion,
                    securityAnswer: securityAnswer,
                    profilePicture: profilePictureUrl,
                    rif: rifInt,
                  );
                }

                if (success) {
                  Navigator.of(context).pop();
                  ToastService.showSuccess(context,
                      'Usuario ${_isEditMode ? 'actualizado' : 'agregado'} con éxito');
                } else {
                  ToastService.showError(
                      context,
                      userController.error ??
                          'Error al ${_isEditMode ? 'actualizar' : 'agregar'} usuario');
                }
              }
            },
            child: Text(_isEditMode ? 'Actualizar' : 'Agregar'),
          ),
        ],
      );
    });
  }

  void _confirmDeleteUser(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content:
            Text('¿Estás seguro que deseas eliminar al usuario "$userName"?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final authController =
                  Provider.of<AuthController>(context, listen: false);
              final userController =
                  Provider.of<UserController>(context, listen: false);

              final success = await userController.deleteUser(
                authController.token!,
                userId,
              );

              Navigator.of(context).pop(); // Cerrar el diálogo de confirmación

              if (success) {
                ToastService.showSuccess(
                    context, 'Usuario eliminado con éxito');
              } else {
                ToastService.showError(context,
                    userController.error ?? 'Error al eliminar usuario');
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  List<User> _getFilteredUsers(List<User> users) {
    List<User> filtered = users;

    // Filter by status
    if (_selectedStatus != UserStatusFilter.todos) {
      bool isActiveFilter = _selectedStatus == UserStatusFilter.activo;
      filtered =
          filtered.where((user) => user.isActive == isActiveFilter).toList();
    }

    // Filter by role
    if (_selectedRoleFilter != UserRoleFilter.todos) {
      String roleFilter =
          _selectedRoleFilter == UserRoleFilter.admin ? 'admin' : 'user';
      filtered = filtered.where((user) => user.role == roleFilter).toList();
    }

    // Filter by search term
    if (_searchTerm.isNotEmpty) {
      String lowerSearchTerm = _searchTerm.toLowerCase();
      filtered = filtered.where((user) {
        return user.fullName.toLowerCase().contains(lowerSearchTerm) ||
            user.email.toLowerCase().contains(lowerSearchTerm);
      }).toList();
    }

    // Store total filtered results for display
    int totalFilteredCount = filtered.length;

    // Update total pages based on filtered list
    _updateTotalPages(totalFilteredCount);

    // Apply pagination
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (startIndex >= filtered.length) {
      // If current page is now invalid (e.g., after filtering), reset to page 1
      _currentPage = 1;
      startIndex = 0;
      endIndex = _itemsPerPage;
    }

    if (endIndex > filtered.length) {
      endIndex = filtered.length;
    }

    return filtered.sublist(startIndex, endIndex);
  }

  void _updateTotalPages(int totalItems) {
    _totalPages = (totalItems / _itemsPerPage).ceil();
    if (_totalPages < 1) _totalPages = 1;
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final userController = Provider.of<UserController>(context, listen: false);

    if (authController.token == null) {
      ToastService.showError(context, 'Error: No autenticado.');
      return;
    }

    // --- VALIDACIÓN: No permitir que el único admin se cambie a user o se inhabilite desde el switch ---
    final user = userController.users.firstWhere((u) => u.id == userId);
    if (user.role == 'admin' && user.isActive && !currentStatus) {
      final admins = userController.users
          .where((u) => u.role == 'admin' && u.isActive)
          .toList();
      if (admins.length == 1) {
        ToastService.showWarning(context,
            'Debe haber al menos un administrador activo en el sistema. Agregue otro administrador antes de desactivar este usuario.');
        return;
      }
    }

    setState(() {
      _loadingUserIds.add(userId);
    });

    final updatedUser = user.copyWith(isActive: !currentStatus);

    final success = await userController.updateUser(
      authController.token!,
      updatedUser,
    );

    setState(() {
      _loadingUserIds.remove(userId);
    });

    if (success) {
      ToastService.showSuccess(
          context,
          'Estado de usuario actualizado a ' +
              (!currentStatus ? 'activo' : 'inactivo'));
    } else {
      ToastService.showError(
          context, userController.error ?? 'Error al actualizar estado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userController = Provider.of<UserController>(context);
    // Use listen: false for actions/data fetching, listen: true for UI updates
    final authController = Provider.of<AuthController>(context, listen: false);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Get all filtered users before pagination
    List<User> allFilteredUsers =
        _getFilteredUsersWithoutPagination(userController.users);
    // Get paginated users for display
    final filteredUsers = _getFilteredUsers(userController.users);

    return Scaffold(
      // No AppBar here, it's handled by HomeView
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        tooltip: 'Agregar Usuario',
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header and Filters
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Roles y Privilegios',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF223A5E),
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                                labelText: 'Búsqueda de Usuarios',
                                hintText: 'Ingrese nombre o correo para buscar',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surfaceVariant
                                    .withOpacity(0.5),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<UserStatusFilter>(
                              focusColor: Colors.transparent,
                              value: _selectedStatus,
                              icon: const Icon(Icons.filter_list),
                              items: const [
                                DropdownMenuItem(
                                  value: UserStatusFilter.todos,
                                  child: Text('Estado: Todos'),
                                ),
                                DropdownMenuItem(
                                  value: UserStatusFilter.activo,
                                  child: Text('Estado: Activo'),
                                ),
                                DropdownMenuItem(
                                  value: UserStatusFilter.inactivo,
                                  child: Text('Estado: Inactivo'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedStatus = value;
                                    _currentPage =
                                        1; // Reset to first page on filter change
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<UserRoleFilter>(
                              focusColor: Colors.transparent,
                              value: _selectedRoleFilter,
                              icon: const Icon(Icons.person_outline),
                              items: const [
                                DropdownMenuItem(
                                  value: UserRoleFilter.todos,
                                  child: Text('Rol: Todos'),
                                ),
                                DropdownMenuItem(
                                  value: UserRoleFilter.admin,
                                  child: Text('Rol: Admin'),
                                ),
                                DropdownMenuItem(
                                  value: UserRoleFilter.user,
                                  child: Text('Rol: Usuario'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedRoleFilter = value;
                                    _currentPage =
                                        1; // Reset to first page on filter change
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // User Table
            Expanded(
              child: userController.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : userController.error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red, size: 50),
                              const SizedBox(height: 10),
                              Text(
                                userController.error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                                onPressed: _loadUsers,
                              ),
                              if (userController.error!
                                      .contains('autorizada') ||
                                  userController.error!
                                      .contains('iniciar sesión'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.login),
                                    label: const Text('Ir a Login'),
                                    onPressed: () {
                                      // Navigate to login page - You may need to adjust this
                                      // depending on your navigation structure
                                      Navigator.of(context)
                                          .pushReplacementNamed('/login');
                                    },
                                  ),
                                ),
                            ],
                          ),
                        )
                      : filteredUsers.isEmpty
                          ? Center(
                              child: Text(
                              _searchTerm.isEmpty &&
                                      _selectedStatus == UserStatusFilter.todos
                                  ? 'No hay usuarios registrados.'
                                  : 'No se encontraron usuarios que coincidan.',
                              style: theme.textTheme.titleMedium,
                            ))
                          : Column(
                              children: [
                                Expanded(
                                  child: _buildUserTable(
                                      filteredUsers, theme, authController),
                                ),
                                // Pagination controls
                                _buildPaginationControls(
                                    theme, allFilteredUsers.length),
                              ],
                            ),
            ),
            // Footer Text (optional)
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Center(
                  child: Text('Lista de usuarios y sus estados',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.secondary))),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUserTable(
      List<User> users, ThemeData theme, AuthController authController) {
    final Color azulOscuro = const Color(0xFF223A5E);
    final Color grisClaro = const Color(0xFFE0E0E0);
    return Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 24,
                headingRowHeight: 48,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 60,
                headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                  (states) =>
                      theme.colorScheme.primaryContainer.withOpacity(0.1),
                ),
                columns: const [
                  DataColumn(
                      label: Text('Foto',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Nombre',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Correo',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Rol',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Estado',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Acciones',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: users.map((user) {
                  return DataRow(
                    cells: [
                      // Foto cell
                      DataCell(
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: user.profilePicture != null &&
                                  user.profilePicture!.isNotEmpty
                              ? NetworkImage(user.profilePicture!)
                              : null,
                          child: (user.profilePicture == null ||
                                  user.profilePicture!.isEmpty)
                              ? Icon(Icons.person_outline,
                                  size: 20, color: theme.colorScheme.primary)
                              : null,
                          backgroundColor: theme.colorScheme.surfaceVariant,
                        ),
                      ),
                      // Nombre cell
                      DataCell(Text(user.fullName)),
                      // Correo cell
                      DataCell(Text(user.email)),
                      // Rol cell
                      DataCell(
                          Text(user.role == 'admin' ? 'Admin' : 'Usuario')),
                      // Estado cell - replaced with Switch
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(minWidth: 140),
                          child: Row(
                            children: [
                              _loadingUserIds.contains(user.id)
                                  ? const SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : Switch(
                                      value: user.isActive,
                                      onChanged: (authController
                                                      .currentUser?.id ==
                                                  user.id ||
                                              _loadingUserIds.contains(user.id))
                                          ? null // Disable switch for current user or while loading
                                          : (newValue) {
                                              _toggleUserStatus(
                                                  user.id, user.isActive);
                                            },
                                      activeColor: Colors.white,
                                      activeTrackColor: azulOscuro,
                                      inactiveThumbColor: Colors.white,
                                      inactiveTrackColor: grisClaro,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      splashRadius: 18,
                                    ),
                              const SizedBox(width: 8),
                              Text(user.isActive ? 'Activo' : 'Inactivo',
                                  style: TextStyle(
                                      color: user.isActive
                                          ? azulOscuro
                                          : Colors.red.shade700,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      // Acciones cell
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Edit Button - Remove border, keep blue icon
                            Tooltip(
                              message: 'Editar Usuario',
                              child: IconButton(
                                icon: Icon(Icons.edit,
                                    color: Colors.blue.shade600),
                                iconSize: 22,
                                padding: const EdgeInsets.all(8),
                                tooltip: 'Editar',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _showEditUserDialog(user),
                              ),
                            ),
                            // Delete Button - Remove border, keep red icon
                            Tooltip(
                              message: 'Eliminar Usuario',
                              child: IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: Colors.red.shade600),
                                iconSize: 22,
                                padding: const EdgeInsets.all(8),
                                tooltip: 'Eliminar',
                                visualDensity: VisualDensity.compact,
                                onPressed:
                                    (authController.currentUser?.id == user.id)
                                        ? null
                                        : () => _confirmDeleteUser(
                                            user.id, user.fullName),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        }));
  }

  // Update the status chip to be more compact
  Widget _buildStatusChip(bool isActive, ThemeData theme) {
    return Chip(
      label: Text(
        isActive ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: isActive ? Colors.green.shade900 : Colors.grey.shade700,
          fontSize: 13,
        ),
      ),
      backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade300,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildPaginationControls(ThemeData theme, int totalItems) {
    final Color primaryColor = const Color(0xFF0277BD);

    // Calculate current range being displayed
    int startItem = (_currentPage - 1) * _itemsPerPage + 1;
    int endItem = _currentPage * _itemsPerPage;
    if (endItem > totalItems) endItem = totalItems;
    if (totalItems == 0) startItem = 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        children: [
          // Record count text
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Mostrando ${startItem}-${endItem} de ${totalItems} registros',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
          // Pagination buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_double_arrow_left),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage = 1;
                        });
                      }
                    : null,
                tooltip: 'Primera página',
                color: _currentPage > 1 ? primaryColor : Colors.grey,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_left),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                      }
                    : null,
                tooltip: 'Página anterior',
                color: _currentPage > 1 ? primaryColor : Colors.grey,
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Página $_currentPage de $_totalPages',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_right),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                      }
                    : null,
                tooltip: 'Página siguiente',
                color: _currentPage < _totalPages ? primaryColor : Colors.grey,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_double_arrow_right),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() {
                          _currentPage = _totalPages;
                        });
                      }
                    : null,
                tooltip: 'Última página',
                color: _currentPage < _totalPages ? primaryColor : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to get all filtered users without pagination
  List<User> _getFilteredUsersWithoutPagination(List<User> users) {
    List<User> filtered = users;

    // Filter by status
    if (_selectedStatus != UserStatusFilter.todos) {
      bool isActiveFilter = _selectedStatus == UserStatusFilter.activo;
      filtered =
          filtered.where((user) => user.isActive == isActiveFilter).toList();
    }

    // Filter by role
    if (_selectedRoleFilter != UserRoleFilter.todos) {
      String roleFilter =
          _selectedRoleFilter == UserRoleFilter.admin ? 'admin' : 'user';
      filtered = filtered.where((user) => user.role == roleFilter).toList();
    }

    // Filter by search term
    if (_searchTerm.isNotEmpty) {
      String lowerSearchTerm = _searchTerm.toLowerCase();
      filtered = filtered.where((user) {
        return user.fullName.toLowerCase().contains(lowerSearchTerm) ||
            user.email.toLowerCase().contains(lowerSearchTerm);
      }).toList();
    }

    return filtered;
  }
}
