import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/user_controller.dart';
// Hide the User class from auth_controller to avoid conflict
import '../controllers/auth_controller.dart' hide User;
import '../models/user_model.dart'; // Use this User model
import 'package:http/http.dart' as http;
import 'dart:convert';

class UsersView extends StatefulWidget {
  final Function toggleTheme;

  const UsersView({super.key, required this.toggleTheme});

  @override
  State<UsersView> createState() => _UsersViewState();
}

enum UserStatusFilter { todos, activo, inactivo }

class _UsersViewState extends State<UsersView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  UserStatusFilter _selectedStatus = UserStatusFilter.todos;

  // Text controllers for input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  String _selectedRole = 'user';
  bool _selectedIsActive = true;
  // TODO: Implement profile picture selection/upload
  String? _selectedProfilePicture;

  bool _isEditMode = false;
  String? _editingUserId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text;
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
    super.dispose();
  }

  void _loadUsers() {
    final authController = Provider.of<AuthController>(context, listen: false);
    final userController = Provider.of<UserController>(context, listen: false);

    if (authController.token != null) {
      try {
        userController.fetchUsers(authController.token!).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar usuarios: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        });
      } catch (e) {
        // Handle any synchronous errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error al iniciar carga de usuarios: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Inform user they need to login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión no iniciada. Por favor inicie sesión primero.'),
          backgroundColor: Colors.orange,
        ),
      );
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
    _passwordController.text = ''; // Password is not displayed for editing
    _fullNameController.text = user.fullName;
    _selectedRole = user.role;
    _selectedIsActive = user.isActive;
    _selectedProfilePicture = user.profilePicture;
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
    _selectedRole = 'user';
    _selectedIsActive = true;
    _selectedProfilePicture = null;
    if (_formKey.currentState != null) {
      _formKey.currentState!.reset();
    }
  }

  Widget _buildUserDialog() {
    // Need StatefulWidget for the dialog to manage Dropdown state correctly
    return StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        title: Text(_isEditMode ? 'Editar Usuario' : 'Agregar Usuario'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // TODO: Add profile picture upload/selection widget here
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Ingresa el correo electrónico',
                    border: OutlineInputBorder(),
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
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: _isEditMode
                        ? 'Dejar en blanco para no cambiar'
                        : 'Ingresa la contraseña',
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    // Password required only when adding a user
                    if (!_isEditMode && (value == null || value.isEmpty)) {
                      return 'Por favor ingresa una contraseña';
                    }

                    // Optional when editing, but if entered, must meet criteria
                    if (value != null && value.isNotEmpty) {
                      // Minimum 6 characters
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }

                      // At least one uppercase letter
                      if (!RegExp(r'[A-Z]').hasMatch(value)) {
                        return 'La contraseña debe contener al menos una letra mayúscula';
                      }

                      // At least one lowercase letter
                      if (!RegExp(r'[a-z]').hasMatch(value)) {
                        return 'La contraseña debe contener al menos una letra minúscula';
                      }

                      // At least one special character
                      if (!RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"\\|,.<>\/?]')
                          .hasMatch(value)) {
                        return 'La contraseña debe contener al menos un carácter especial';
                      }

                      // At least one number
                      if (!RegExp(r'[0-9]').hasMatch(value)) {
                        return 'La contraseña debe contener al menos un número';
                      }
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    hintText: 'Ingresa el nombre completo',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa un nombre';
                    }
                    return null;
                  },
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
                  items: const [
                    DropdownMenuItem<bool>(
                      value: true,
                      child: Text('Activo'),
                    ),
                    DropdownMenuItem<bool>(
                      value: false,
                      child: Text('Inactivo'),
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
                final profilePicture =
                    _selectedProfilePicture; // Use selected picture

                bool success = false;
                if (_isEditMode && _editingUserId != null) {
                  // Find the original user to copyWith
                  try {
                    final originalUser = userController.users
                        .firstWhere((u) => u.id == _editingUserId);

                    final updatedUser = originalUser.copyWith(
                      email: email,
                      fullName: fullName,
                      role: role,
                      isActive: isActive,
                      profilePicture: profilePicture,
                      // Password update needs separate handling if provided
                    );

                    // Handle password update separately if needed (backend logic)
                    success = await userController.updateUser(
                      authController.token!,
                      updatedUser,
                      // Optionally pass password if changed:
                      // password: password.isNotEmpty ? password : null,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Error: Usuario original no encontrado.')),
                    );
                  }
                } else {
                  // Add new user
                  success = await userController.addUser(
                    authController.token!,
                    email: email,
                    password: password,
                    fullName: fullName,
                    role: role,
                    isActive: isActive,
                    profilePicture: profilePicture,
                  );
                }

                if (success) {
                  Navigator.of(context).pop(); // Close dialog on success
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Usuario ${_isEditMode ? 'actualizado' : 'agregado'} con éxito')),
                  );
                } else {
                  // Error message is handled by the controller
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(userController.error ??
                            'Error al ${_isEditMode ? 'actualizar' : 'agregar'} usuario')),
                  );
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

              Navigator.of(context).pop(); // Close confirmation dialog

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Usuario eliminado con éxito')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          userController.error ?? 'Error al eliminar usuario')),
                );
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

  Future<bool> _toggleUserStatus(String userId, bool currentStatus) async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final userController = Provider.of<UserController>(context, listen: false);

    // Check if token is available
    if (authController.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No autenticado.')),
      );
      return false;
    }

    // Calculate the new status (opposite of current)
    final newStatus = !currentStatus;

    // Find the index of the user in the list
    final int userIndex =
        userController.users.indexWhere((u) => u.id == userId);
    if (userIndex == -1) {
      // User not found
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no encontrado.')),
      );
      return false;
    }

    // First update UI immediately (optimistic update)
    setState(() {
      // Create a new user object with updated status
      final updatedUser =
          userController.users[userIndex].copyWith(isActive: newStatus);
      // Replace the user in the list with the updated version
      userController.users[userIndex] = updatedUser;
    });

    try {
      // Call API to update status
      final response = await http.put(
        Uri.parse('http://127.0.0.1:8000/api/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authController.token!}',
        },
        body: jsonEncode({'is_active': newStatus}),
      );

      if (response.statusCode == 200) {
        // Success - UI already updated
        return true;
      } else {
        // API call failed, revert the UI change
        setState(() {
          final revertedUser =
              userController.users[userIndex].copyWith(isActive: currentStatus);
          userController.users[userIndex] = revertedUser;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error al actualizar estado. Código: ${response.statusCode}')),
        );
        return false;
      }
    } catch (e) {
      // Network or other error, revert the UI change
      setState(() {
        final revertedUser =
            userController.users[userIndex].copyWith(isActive: currentStatus);
        userController.users[userIndex] = revertedUser;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red: ${e.toString()}')),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userController = Provider.of<UserController>(context);
    // Use listen: false for actions/data fetching, listen: true for UI updates
    final authController = Provider.of<AuthController>(context, listen: false);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
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
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            // Navigate back or to home - adjust as needed
                            // This button might not be necessary if using the Drawer navigation
                            // Navigator.of(context).pop();
                            print("Volver al inicio pressed");
                          },
                          icon: Icon(Icons.arrow_back,
                              color: theme.colorScheme.secondary),
                          label: Text('Volver al inicio',
                              style: TextStyle(
                                  color: theme.colorScheme.secondary)),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                                hintText: 'Buscar usuario por nombre o correo',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surfaceVariant
                                    .withOpacity(0.5),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0, horizontal: 16)),
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
                          : _buildUserTable(
                              filteredUsers, theme, authController),
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
                              Switch(
                                value: user.isActive,
                                onChanged: (authController.currentUser?.id ==
                                        user.id)
                                    ? null // Disable switch for current user
                                    : (newValue) {
                                        _toggleUserStatus(
                                            user.id, user.isActive);
                                      },
                                activeColor: Colors.green,
                                inactiveThumbColor: Colors.grey,
                                inactiveTrackColor: Colors.grey.shade300,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 8),
                              Text(user.isActive ? 'Activo' : 'Inactivo',
                                  style: TextStyle(
                                      color: user.isActive
                                          ? Colors.green
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

  // Optional: Method to toggle status directly
  /*
   void _toggleUserStatus(User user, String token) async {
     final userController = Provider.of<UserController>(context, listen: false);
     // Check if token is available
     if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Error: No autenticado.')),
       );
       return;
     }
     final success = await userController.toggleUserStatus(token, user);
     if (success) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Estado de ${user.fullName} actualizado')),
       );
     } else {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(userController.error ?? 'Error al cambiar estado')),
       );
     }
   }
   */
}
