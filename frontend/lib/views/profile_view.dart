import 'dart:convert';
import 'dart:typed_data';
// Use conditional imports to avoid linting errors
// ignore: unused_import
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/auth_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../utils/image_picker_helper.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isUploading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // For image selection
  XFile? _selectedImageFile;
  Uint8List? _selectedImagePreview;

  @override
  void initState() {
    super.initState();
    // Initialize form fields with current user data
    _initializeFormFields();

    // Forzar una actualización de datos de usuario al cargar la vista
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      authController.refreshUserData().then((success) {
        if (success) {
          setState(() {
            // Reinicializar campos con los datos actualizados
            _initializeFormFields();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Initialize form fields with current user data
  void _initializeFormFields() {
    final authController = Provider.of<AuthController>(context, listen: false);
    final currentUser = authController.currentUser;

    if (currentUser != null) {
      // Split full name into first and last name
      List<String> nameParts = currentUser.fullName.split(' ');
      String firstName = nameParts.isNotEmpty ? nameParts[0] : '';
      String lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';

      _firstNameController.text = firstName;
      _lastNameController.text = lastName;
      _emailController.text = currentUser.email;
      // Password field is left empty for security
    }
  }

  // Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      // Initialize the image picker helper just before using it
      await ImagePickerHelper.initialize();

      final result = await ImagePickerHelper.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (result != null) {
        setState(() {
          _selectedImageFile = result.file;
          _selectedImagePreview = result.bytes;
          _errorMessage = null; // Clear any previous error messages
        });
      }
    } catch (e) {
      setState(() {
        if (e is ImagePickerException) {
          _errorMessage = e.toString();
        } else {
          _errorMessage = 'Error al seleccionar imagen: $e';
        }
      });
    }
  }

  // Upload profile picture
  Future<void> _uploadProfilePicture() async {
    if (_selectedImageFile == null) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('Usuario no autenticado');
      }

      // Handle file upload differently based on platform
      http.Response response;

      if (kIsWeb) {
        // For web platform, convert the image back to base64
        // Web doesn't have direct file access
        final apiUrl =
            'http://localhost:8000/api/users/profile/picture/upload/web';
        response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'image_base64': base64Encode(_selectedImagePreview!),
            'file_name': path.basename(_selectedImageFile!.path),
          }),
        );
      } else {
        // For mobile platforms, use multipart form
        final apiUrl = 'http://localhost:8000/api/users/profile/picture/upload';
        // Create a multipart request for file upload
        final request = http.MultipartRequest('POST', Uri.parse(apiUrl));

        // Add authorization header
        request.headers.addAll({
          'Authorization': 'Bearer $token',
        });

        // Get file extension
        final fileExtension =
            path.extension(_selectedImageFile!.path).toLowerCase();
        final mimeType = fileExtension == '.png' ? 'image/png' : 'image/jpeg';

        // Add the file to the request
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            _selectedImageFile!.path,
            contentType: MediaType.parse(mimeType),
          ),
        );

        // Send the request
        final streamedResponse = await request.send();

        // Get the response
        response = await http.Response.fromStream(streamedResponse);
      }

      // Process the response
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Update auth controller with new profile picture URL
        final profilePictureUrl = responseData['profile_picture_url'];
        await authController.updateProfilePicture(profilePictureUrl);

        setState(() {
          _successMessage = 'Foto de perfil actualizada correctamente';
        });
      } else {
        setState(() {
          _errorMessage =
              responseData['detail'] ?? 'Error al actualizar la foto de perfil';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  // Save profile changes
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('Usuario no autenticado');
      }

      // Prepare data
      Map<String, dynamic> updateData = {};

      // Only include fields that have changed
      final currentUser = authController.currentUser;
      List<String> nameParts = currentUser?.fullName.split(' ') ?? [];
      String currentFirstName = nameParts.isNotEmpty ? nameParts[0] : '';
      String currentLastName =
          nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';

      if (_firstNameController.text != currentFirstName) {
        updateData['first_name'] = _firstNameController.text;
      }

      if (_lastNameController.text != currentLastName) {
        updateData['last_name'] = _lastNameController.text;
      }

      if (_emailController.text != currentUser?.email) {
        updateData['email'] = _emailController.text;
      }

      if (_passwordController.text.isNotEmpty) {
        updateData['password'] = _passwordController.text;
      }

      // Only proceed if there are changes
      if (updateData.isNotEmpty) {
        final apiUrl = 'http://localhost:8000/api/users/profile';

        print('Sending request to: $apiUrl');
        print('Request data: ${jsonEncode(updateData)}');

        final response = await http.put(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(updateData),
        );

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        final responseData = jsonDecode(response.body);

        if (response.statusCode == 200) {
          // Update auth controller with new user data
          if (responseData['data'] != null) {
            await authController.updateUserInfo(responseData['data']);
          }

          setState(() {
            _successMessage = 'Perfil actualizado correctamente';
            _passwordController.clear(); // Clear password field for security
          });
        } else {
          setState(() {
            _errorMessage =
                responseData['detail'] ?? 'Error al actualizar el perfil';
          });
        }
      } else {
        setState(() {
          _successMessage = 'No hay cambios para guardar';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Helper to properly encode profile picture URLs
  String _encodeProfilePictureUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    try {
      // Check if it's an S3 URL
      if (url.contains('s3.amazonaws.com')) {
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
          return 'https://s3.amazonaws.com/$bucketName/$objectKey';
        }
      }

      // If not an S3 URL or already in the right format, just encode it properly
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments.map(Uri.encodeComponent).join('/');
      return '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}/$pathSegments';
    } catch (e) {
      // If URL parsing fails, fall back to basic space encoding
      print('Error encoding URL: $e');
      return url.replaceAll(' ', '%20');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final currentUser = authController.currentUser;
    final theme = Theme.of(context);

    // Encode profile picture URL if exists
    final String? encodedProfilePictureUrl = currentUser?.profilePicture != null
        ? _encodeProfilePictureUrl(currentUser!.profilePicture)
        : null;

    // User must be logged in to access profile
    if (currentUser == null) {
      return const Center(child: Text('Usuario no autenticado'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de Usuario'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile image section
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      // Profile picture
                      CircleAvatar(
                        radius: 60,
                        backgroundColor:
                            theme.colorScheme.primary.withOpacity(0.2),
                        backgroundImage: _selectedImagePreview != null
                            ? MemoryImage(_selectedImagePreview!)
                            : (encodedProfilePictureUrl != null &&
                                    encodedProfilePictureUrl.isNotEmpty
                                ? NetworkImage(encodedProfilePictureUrl,
                                    headers: {'Accept': '*/*'})
                                : null) as ImageProvider<Object>?,
                        child: (_selectedImagePreview == null &&
                                (encodedProfilePictureUrl == null ||
                                    encodedProfilePictureUrl.isEmpty))
                            ? Icon(Icons.person,
                                size: 80,
                                color:
                                    theme.colorScheme.primary.withOpacity(0.7))
                            : null,
                        onBackgroundImageError:
                            encodedProfilePictureUrl != null &&
                                    encodedProfilePictureUrl.isNotEmpty
                                ? (exception, stackTrace) {
                                    print(
                                        'Error loading profile image: $exception');
                                    print(
                                        'URL that failed: $encodedProfilePictureUrl');
                                    // Use setState to force rebuild with fallback icon
                                    if (mounted) {
                                      setState(() {
                                        // Try to refresh user data from server to get updated profile URL
                                        final authController =
                                            Provider.of<AuthController>(context,
                                                listen: false);
                                        print(
                                            'Refreshing user data after image load failure');
                                        authController.refreshUserData();
                                      });
                                    }
                                  }
                                : null,
                      ),
                      // Camera icon to change picture
                      Material(
                        elevation: 4,
                        shape: const CircleBorder(),
                        color: theme.colorScheme.primary,
                        child: InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Seleccionar foto de perfil',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 20),
                                    ListTile(
                                      leading: const Icon(Icons.photo_camera),
                                      title: const Text('Tomar foto'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickImage(ImageSource.camera);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title:
                                          const Text('Seleccionar de galería'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickImage(ImageSource.gallery);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.camera_alt,
                                color: theme.colorScheme.onPrimary, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Upload button for profile picture
                  if (_selectedImageFile != null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadProfilePicture,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload),
                      label: Text(_isUploading ? 'Subiendo...' : 'Subir foto'),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // User info form
                  const Text('Perfil de Usuario',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 24),

                  // First name field
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu nombre';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Last name field
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Apellido',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu apellido';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu correo';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Por favor ingresa un correo válido';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Cambiar Contraseña',
                      prefixIcon: Icon(Icons.lock),
                      helperText:
                          'Dejar en blanco para mantener la contraseña actual',
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value != null &&
                          value.isNotEmpty &&
                          value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),

                  // Error and success messages
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],

                  if (_successMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _successMessage!,
                      style: TextStyle(color: Colors.green),
                    ),
                  ],

                  // Save button
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Guardar Cambios'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
