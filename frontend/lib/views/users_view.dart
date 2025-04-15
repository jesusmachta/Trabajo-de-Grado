import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/user_controller.dart';
// Hide the User class from auth_controller to avoid conflict
import '../controllers/auth_controller.dart' hide User;
import '../models/user_model.dart'; // Use this User model

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
      userController.fetchUsers(authController.token!);
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
                    if (value != null && value.isNotEmpty && value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
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
                                style:
                                    TextStyle(color: Colors.red, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                                onPressed: _loadUsers,
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
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.dividerColor, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection:
              Axis.horizontal, // Enable horizontal scroll for smaller screens
          child: DataTable(
            // Set a specific background color for the header row
            headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) {
              // Use a slightly lighter/different color for the header
              return theme.colorScheme.secondaryContainer.withOpacity(0.3);
            }),
            headingTextStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSecondaryContainer),
            columnSpacing: 24, // Adjust spacing between columns
            columns: const [
              DataColumn(
                  label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Foto'))),
              DataColumn(
                  label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Nombre'))),
              DataColumn(
                  label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Correo'))),
              DataColumn(
                  label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Rol'))),
              DataColumn(
                  label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Estado'))),
              DataColumn(
                  label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Acciones'))),
            ],
            rows: users.map((user) {
              return DataRow(
                color: MaterialStateProperty.resolveWith<Color?>(
                    (Set<MaterialState> states) {
                  // Alternating row colors can be added here if desired
                  return null; // Default row color
                }),
                cells: [
                  DataCell(
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 8.0), // Add padding around CircleAvatar
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage: user.profilePicture != null &&
                                user.profilePicture!.isNotEmpty
                            ? NetworkImage(user.profilePicture!)
                            : null, // Handle null/empty profile picture URL
                        child: (user.profilePicture == null ||
                                user.profilePicture!.isEmpty)
                            ? Icon(Icons.person_outline,
                                size: 20, color: theme.colorScheme.primary)
                            : null,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                      ),
                    ),
                  ),
                  DataCell(Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(user.fullName))), // Add padding
                  DataCell(Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(user.email))), // Add padding
                  DataCell(Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(user.role == 'admin'
                          ? 'Admin'
                          : 'Usuario'))), // Add padding
                  DataCell(Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: _buildStatusChip(
                          user.isActive, theme))), // Add padding
                  DataCell(
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0), // Add padding
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                color: theme.colorScheme.primary, size: 20),
                            tooltip: 'Editar Usuario',
                            onPressed: () => _showEditUserDialog(user),
                            visualDensity: VisualDensity
                                .compact, // Make IconButton smaller
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 8),
                          // Optional: Toggle status directly from the table
                          // IconButton(
                          //   icon: Icon(user.isActive ? Icons.toggle_off_outlined : Icons.toggle_on_outlined, color: user.isActive ? Colors.grey : Colors.green, size: 20),
                          //   tooltip: user.isActive ? 'Desactivar Usuario' : 'Activar Usuario',
                          //   onPressed: () => _toggleUserStatus(user, authController.token!),
                          //   visualDensity: VisualDensity.compact,
                          //   padding: EdgeInsets.zero,
                          // ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: theme.colorScheme.error, size: 20),
                            tooltip: 'Eliminar Usuario',
                            // Disable delete for self, use null check for currentUser
                            onPressed: (authController.currentUser?.id ==
                                    user.id)
                                ? null
                                : () =>
                                    _confirmDeleteUser(user.id, user.fullName),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ));
  }

  Widget _buildStatusChip(bool isActive, ThemeData theme) {
    return Chip(
      avatar: Icon(
        isActive ? Icons.check_circle : Icons.cancel,
        color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
        size: 16,
      ),
      label: Text(isActive ? 'Activo' : 'Inactivo'),
      labelStyle: TextStyle(
          fontSize: 12,
          color: isActive ? Colors.green.shade900 : Colors.grey.shade700,
          fontWeight: FontWeight.w600),
      backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade300,
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 0), // Reduced vertical padding
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
