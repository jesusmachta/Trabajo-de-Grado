import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/user_controller.dart';
import '../controllers/auth_controller.dart';

class UsersView extends StatefulWidget {
  final Function toggleTheme;

  const UsersView({super.key, required this.toggleTheme});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers for input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  String _selectedRole = 'user';

  bool _isEditMode = false;
  String? _editingUserId;

  @override
  void initState() {
    super.initState();
    // Load users when the view is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  @override
  void dispose() {
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
    // Reset form fields
    _emailController.text = '';
    _passwordController.text = '';
    _fullNameController.text = '';
    _selectedRole = 'user';
    _isEditMode = false;
    _editingUserId = null;

    showDialog(
      context: context,
      builder: (context) => _buildUserDialog(),
    );
  }

  void _showEditUserDialog(dynamic user) {
    // Fill form with user data
    _emailController.text = user.email;
    _passwordController.text = ''; // Password is not displayed
    _fullNameController.text = user.fullName;
    _selectedRole = user.role;
    _isEditMode = true;
    _editingUserId = user.id;

    showDialog(
      context: context,
      builder: (context) => _buildUserDialog(),
    );
  }

  Widget _buildUserDialog() {
    return AlertDialog(
      title: Text(_isEditMode ? 'Editar Usuario' : 'Agregar Usuario'),
      content: Form(
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
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
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
                      ? 'Dejar en blanco para mantener la actual'
                      : 'Ingresa la contraseña',
                ),
                obscureText: true,
                validator: (value) {
                  if (!_isEditMode && (value == null || value.isEmpty)) {
                    return 'Por favor ingresa una contraseña';
                  }
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
                ),
                items: ['admin', 'user'].map((String role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role == 'admin' ? 'Administrador' : 'Usuario'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
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

              if (_isEditMode) {
                // Update existing user
                final user = userController.users
                    .firstWhere((u) => u.id == _editingUserId);
                final updatedUser = user.copyWith(
                  email: _emailController.text,
                  fullName: _fullNameController.text,
                  role: _selectedRole,
                );

                final success = await userController.updateUser(
                  authController.token!,
                  updatedUser,
                );

                if (success) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Usuario actualizado con éxito')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(userController.error ??
                            'Error al actualizar usuario')),
                  );
                }
              } else {
                // Add new user
                final success = await userController.addUser(
                  authController.token!,
                  email: _emailController.text,
                  password: _passwordController.text,
                  fullName: _fullNameController.text,
                  role: _selectedRole,
                );

                if (success) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Usuario agregado con éxito')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(userController.error ??
                            'Error al agregar usuario')),
                  );
                }
              }
            }
          },
          child: Text(_isEditMode ? 'Actualizar' : 'Agregar'),
        ),
      ],
    );
  }

  void _confirmDeleteUser(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content:
            Text('¿Estás seguro que deseas eliminar al usuario $userName?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authController =
                  Provider.of<AuthController>(context, listen: false);
              final userController =
                  Provider.of<UserController>(context, listen: false);

              final success = await userController.deleteUser(
                authController.token!,
                userId,
              );

              Navigator.of(context).pop();

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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final userController = Provider.of<UserController>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: _loadUsers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        tooltip: 'Agregar Usuario',
        child: const Icon(Icons.add),
      ),
      body: userController.isLoading
          ? const Center(child: CircularProgressIndicator())
          : userController.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(userController.error!,
                          style: TextStyle(color: Colors.red)),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : userController.users.isEmpty
                  ? const Center(child: Text('No hay usuarios registrados'))
                  : ListView.builder(
                      itemCount: userController.users.length,
                      itemBuilder: (context, index) {
                        final user = userController.users[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: user.role == 'admin'
                                  ? Colors.red[100]
                                  : Colors.blue[100],
                              child: Icon(
                                user.role == 'admin'
                                    ? Icons.admin_panel_settings
                                    : Icons.person,
                                color: user.role == 'admin'
                                    ? Colors.red
                                    : Colors.blue,
                              ),
                            ),
                            title: Text(user.fullName),
                            subtitle: Text(user.email),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Editar',
                                  onPressed: () => _showEditUserDialog(user),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  tooltip: 'Eliminar',
                                  onPressed: () => _confirmDeleteUser(
                                      user.id, user.fullName),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
