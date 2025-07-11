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
import '../widgets/toast_notification.dart';
import '../config.dart'; // Import the config file

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView>
    with SingleTickerProviderStateMixin {
  final _personalDataFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Controllers for password change
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Tab controller
  late TabController _tabController;

  bool _isUploading = false;
  bool _isSaving = false;
  bool _isChangingPassword = false;
  bool _isChangingSecurityQuestion = false;
  String? _errorMessage;
  String? _successMessage;
  String? _passwordErrorMessage;
  String? _passwordSuccessMessage;
  String? _securityQuestionErrorMessage;
  String? _securityQuestionSuccessMessage;

  // Password visibility toggles
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  // Security question controllers
  final TextEditingController _currentSecurityAnswerController =
      TextEditingController();
  final TextEditingController _newSecurityAnswerController =
      TextEditingController();

  // Security question form key
  final _securityQuestionFormKey = GlobalKey<FormState>();

  // Security answer visibility toggles
  bool _currentSecurityAnswerVisible = false;
  bool _newSecurityAnswerVisible = false;

  // Selected security questions
  String? _currentSecurityQuestion;
  String? _newSecurityQuestion;

  // List of security questions
  final List<String> _securityQuestions = [
    '¿Cuál es el nombre de tu primera mascota?',
    '¿En qué ciudad naciste?',
    '¿Cuál es el nombre de tu mejor amigo de la infancia?',
    '¿Cuál fue tu primer carro/moto?',
    '¿Cuál es tu película favorita?',
    '¿Cuál es el segundo nombre de tu madre?',
    '¿Cuál fue el nombre de tu primera escuela?',
    '¿Cuál es tu comida favorita?',
    '¿Cuál es tu equipo deportivo favorito?',
    '¿Cuál es el nombre de la calle donde creciste?',
  ];

  // For image selection
  XFile? _selectedImageFile;
  Uint8List? _selectedImagePreview;

  @override
  void initState() {
    super.initState();
    // Initialize tab controller
    _tabController = TabController(length: 3, vsync: this);

    // Initialize form fields with current user data
    _initializeFormFields();

    // Forzar una actualización de datos de usuario al cargar la vista
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authController =
          Provider.of<AuthController>(context, listen: false);

      // Show loading indicator
      setState(() {
        _isUploading = true;
      });

      authController.refreshUserData().then((success) {
        if (success) {
          print('ProfileView - Successfully refreshed user data');
          setState(() {
            // Reinicializar campos con los datos actualizados
            _initializeFormFields();
            _isUploading = false;
          });
        } else {
          print('ProfileView - Failed to refresh user data');
          setState(() {
            _errorMessage = 'No se pudieron cargar los datos del usuario';
            _isUploading = false;
          });
        }
      }).catchError((error) {
        print('ProfileView - Error refreshing user data: $error');
        setState(() {
          _errorMessage = 'Error al cargar los datos: $error';
          _isUploading = false;
        });
      });
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentSecurityAnswerController.dispose();
    _newSecurityAnswerController.dispose();
    _tabController.dispose();
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

      // Set the current security question if available
      if (currentUser.securityQuestion != null &&
          currentUser.securityQuestion!.isNotEmpty) {
        _currentSecurityQuestion = currentUser.securityQuestion;
      }

      // Password fields are left empty for security
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
        final apiUrl = AppConfig.getApiUrl('users/profile/picture/upload/web');
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
        final apiUrl = AppConfig.getApiUrl('users/profile/picture/upload');
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
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        // Update auth controller with new profile picture URL
        final profilePictureUrl = responseData['profile_picture_url'];
        await authController.updateProfilePicture(profilePictureUrl);

        setState(() {
          _successMessage = 'Foto de perfil actualizada correctamente';
          // Clear selected image after successful upload
          _selectedImageFile = null;
          _selectedImagePreview = null;
        });

        // Show toast notification
        ToastService.showSuccess(
            context, 'Foto de perfil actualizada correctamente');
      } else {
        setState(() {
          _errorMessage =
              responseData['detail'] ?? 'Error al actualizar la foto de perfil';
        });

        // Show toast notification
        ToastService.showError(context,
            responseData['detail'] ?? 'Error al actualizar la foto de perfil');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });

      // Show toast notification
      ToastService.showError(context, 'Error: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  // Save profile changes (personal data only)
  Future<void> _saveProfile() async {
    if (!_personalDataFormKey.currentState!.validate()) return;

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

      // Only proceed if there are changes
      if (updateData.isNotEmpty) {
        final apiUrl = AppConfig.getApiUrl('users/profile');

        final response = await http.put(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(updateData),
        );

        // Ensure proper UTF-8 decoding for Spanish characters
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));

        if (response.statusCode == 200) {
          // Update auth controller with new user data
          if (responseData['data'] != null) {
            await authController.updateUserInfo(responseData['data']);
          }

          setState(() {
            _successMessage = 'Perfil actualizado correctamente';
          });

          // Show toast notification
          ToastService.showSuccess(context, 'Perfil actualizado correctamente');
        } else {
          setState(() {
            _errorMessage =
                responseData['detail'] ?? 'Error al actualizar el perfil';
          });

          // Show toast notification
          ToastService.showError(context,
              responseData['detail'] ?? 'Error al actualizar el perfil');
        }
      } else {
        setState(() {
          _successMessage = 'No hay cambios para guardar';
        });

        // Show toast notification
        ToastService.showInfo(context, 'No hay cambios para guardar');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });

      // Show toast notification
      ToastService.showError(context, 'Error: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Change password
  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() {
      _isChangingPassword = true;
      _passwordErrorMessage = null;
      _passwordSuccessMessage = null;
    });

    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('Usuario no autenticado');
      }

      // Verify that new password and confirm password match
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(() {
          _passwordErrorMessage = 'Las contraseñas no coinciden';
          _isChangingPassword = false;
        });

        // Show toast notification
        ToastService.showError(context, 'Las contraseñas no coinciden');
        return;
      }

      final apiUrl = AppConfig.getApiUrl('users/profile');

      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'password': _newPasswordController.text,
          'current_password': _currentPasswordController.text,
        }),
      );

      // Ensure proper UTF-8 decoding for Spanish characters
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        setState(() {
          _passwordSuccessMessage = 'Contraseña actualizada correctamente';
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });

        // Show toast notification
        ToastService.showSuccess(
            context, 'Contraseña actualizada correctamente');
      } else {
        setState(() {
          _passwordErrorMessage =
              responseData['detail'] ?? 'Error al actualizar la contraseña';
        });

        // Show toast notification
        ToastService.showError(context,
            responseData['detail'] ?? 'Error al actualizar la contraseña');
      }
    } catch (e) {
      setState(() {
        _passwordErrorMessage = 'Error: $e';
      });

      // Show toast notification
      ToastService.showError(context, 'Error: $e');
    } finally {
      setState(() {
        _isChangingPassword = false;
      });
    }
  }

  // Change security question
  Future<void> _changeSecurityQuestion() async {
    if (!_securityQuestionFormKey.currentState!.validate()) return;

    setState(() {
      _isChangingSecurityQuestion = true;
      _securityQuestionErrorMessage = null;
      _securityQuestionSuccessMessage = null;
    });

    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final String? token = authController.token;

      if (token == null) {
        throw Exception('Usuario no autenticado');
      }

      if (_currentSecurityQuestion == null ||
          _currentSecurityQuestion!.isEmpty) {
        throw Exception('No se encontró tu pregunta de seguridad actual');
      }

      if (_newSecurityQuestion == null) {
        throw Exception('Selecciona tu nueva pregunta de seguridad');
      }

      final apiUrl = AppConfig.getApiUrl('users/profile');

      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'current_security_question': _currentSecurityQuestion,
          'current_security_answer': _currentSecurityAnswerController.text,
          'new_security_question': _newSecurityQuestion,
          'new_security_answer': _newSecurityAnswerController.text,
        }),
      );

      // Ensure proper UTF-8 decoding for Spanish characters
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        setState(() {
          _securityQuestionSuccessMessage =
              'Pregunta de seguridad actualizada correctamente';
          _currentSecurityQuestion = null;
          _currentSecurityAnswerController.clear();
          _newSecurityQuestion = null;
          _newSecurityAnswerController.clear();
        });

        // Show toast notification
        ToastService.showSuccess(
            context, 'Pregunta de seguridad actualizada correctamente');
      } else {
        setState(() {
          _securityQuestionErrorMessage = responseData['detail'] ??
              'Error al actualizar la pregunta de seguridad';
        });

        // Show toast notification
        ToastService.showError(
            context,
            responseData['detail'] ??
                'Error al actualizar la pregunta de seguridad');
      }
    } catch (e) {
      setState(() {
        _securityQuestionErrorMessage = 'Error: $e';
      });

      // Show toast notification
      ToastService.showError(context, 'Error: $e');
    } finally {
      setState(() {
        _isChangingSecurityQuestion = false;
      });
    }
  }

  // Validate password
  bool _validatePassword(String value) {
    // Minimum 6 characters
    if (value.length < 6) {
      return false;
    }

    // At least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return false;
    }

    // At least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return false;
    }

    // At least one special character
    if (!RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"\\|,.<>\/?]').hasMatch(value)) {
      return false;
    }

    // At least one number
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return false;
    }

    return true;
  }

  // Helper to properly encode profile picture URLs
  String _encodeProfilePictureUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    print('ProfileView - Original profile URL: $url');

    try {
      // Handle specific case for tesislospomelos bucket
      if (url.contains('tesislospomelos.s3.amazonaws.com')) {
        print('ProfileView - Detected tesislospomelos S3 URL');

        // Direct access format for S3 - no transformation needed for this bucket
        // Just ensure proper encoding
        final encodedUrl = url.replaceAll(' ', '%20');
        print('ProfileView - Encoded tesislospomelos URL: $encodedUrl');
        return encodedUrl;
      }
      // Check if it's an S3 URL
      else if (url.contains('s3.amazonaws.com')) {
        print('ProfileView - Detected other S3 URL');
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
          print('ProfileView - Reformatted S3 URL: $formattedUrl');
          return formattedUrl;
        }
      }

      // If not an S3 URL or already in the right format, just encode it properly
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments.map(Uri.encodeComponent).join('/');
      final encodedUrl =
          '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}/$pathSegments';
      print('ProfileView - Generally encoded URL: $encodedUrl');
      return encodedUrl;
    } catch (e) {
      // If URL parsing fails, fall back to basic space encoding
      print('ProfileView - Error encoding URL: $e');
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
        title: const Align(
          alignment: Alignment.centerLeft,
          child: Text('StoreSense'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Error display
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _errorMessage = null),
                          color: Colors.red.shade700,
                        ),
                      ],
                    ),
                  ),

                // Success message
                if (_successMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _successMessage = null),
                          color: Colors.green.shade700,
                        ),
                      ],
                    ),
                  ),

                // Profile image section
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    // Debug logs for profile picture URL
                    Builder(builder: (context) {
                      // Print profile picture URL info for debugging
                      print(
                          'ProfileView - Current user profile picture: ${currentUser.profilePicture}');
                      print(
                          'ProfileView - Encoded profile picture URL: $encodedProfilePictureUrl');
                      return const SizedBox.shrink();
                    }),

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
                              color: theme.brightness == Brightness.dark
                                  ? theme.colorScheme.primary.withOpacity(0.7)
                                  : const Color(0xFF223A5E))
                          : null,
                      onBackgroundImageError: encodedProfilePictureUrl !=
                                  null &&
                              encodedProfilePictureUrl.isNotEmpty
                          ? (exception, stackTrace) {
                              print('Error loading profile image: $exception');
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
                                    title: const Text('Seleccionar de galería'),
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

                const SizedBox(height: 20),
                Text(
                  currentUser.fullName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // Tab Bar
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      overlayColor: MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                          // Return transparent for hover state to remove the gray hover effect
                          if (states.contains(MaterialState.hovered)) {
                            return Colors.transparent;
                          }
                          return null; // Use default overlay color for other states
                        },
                      ),
                      indicator: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      dividerColor: Colors.transparent,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      tabs: [
                        SizedBox(
                          height: 48,
                          child: Tab(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.person),
                                  SizedBox(width: 8),
                                  Text('Datos personales'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 48,
                          child: Tab(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.lock),
                                  SizedBox(width: 8),
                                  Text('Cambiar contraseña'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 48,
                          child: Tab(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.security),
                                  SizedBox(width: 8),
                                  Text('Pregunta de seguridad'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Tab content
                SizedBox(
                  height: 500, // Set a fixed height for the tab content area
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Personal Data
                      _buildPersonalDataTab(theme),

                      // Tab 2: Change Password
                      _buildChangePasswordTab(theme),

                      // Tab 3: Security Question
                      _buildSecurityQuestionTab(theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalDataTab(ThemeData theme) {
    return Form(
      key: _personalDataFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              // Verify name starts with letters
              if (!RegExp(r'^[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ]').hasMatch(value)) {
                return 'Debe comenzar con letras, no con números o caracteres especiales';
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
              // Verify name starts with letters
              if (!RegExp(r'^[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ]').hasMatch(value)) {
                return 'Debe comenzar con letras, no con números o caracteres especiales';
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
    );
  }

  Widget _buildChangePasswordTab(ThemeData theme) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current password
          TextFormField(
            controller: _currentPasswordController,
            decoration: InputDecoration(
              labelText: 'Contraseña actual',
              prefixIcon: const Icon(Icons.lock_outline),
              hintText: 'Escribe tu contraseña actual...',
              suffixIcon: IconButton(
                icon: Icon(
                  _currentPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _currentPasswordVisible = !_currentPasswordVisible;
                  });
                },
              ),
            ),
            obscureText: !_currentPasswordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu contraseña actual';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // New password
          TextFormField(
            controller: _newPasswordController,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              prefixIcon: const Icon(Icons.lock),
              hintText: 'Escribe tu nueva contraseña...',
              suffixIcon: IconButton(
                icon: Icon(
                  _newPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _newPasswordVisible = !_newPasswordVisible;
                  });
                },
              ),
            ),
            obscureText: !_newPasswordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa una nueva contraseña';
              }

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

              return null;
            },
          ),

          const SizedBox(height: 16),

          // Confirm password
          TextFormField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: const Icon(Icons.lock),
              hintText: 'Confirma tu contraseña...',
              suffixIcon: IconButton(
                icon: Icon(
                  _confirmPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _confirmPasswordVisible = !_confirmPasswordVisible;
                  });
                },
              ),
            ),
            obscureText: !_confirmPasswordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor confirma tu nueva contraseña';
              }
              if (value != _newPasswordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),

          // Error and success messages for password change
          if (_passwordErrorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _passwordErrorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],

          if (_passwordSuccessMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _passwordSuccessMessage!,
              style: TextStyle(color: Colors.green),
            ),
          ],

          // Save button for password
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isChangingPassword ? null : _changePassword,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isChangingPassword
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
    );
  }

  Widget _buildSecurityQuestionTab(ThemeData theme) {
    return Form(
      key: _securityQuestionFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current security question (read-only text field)
          TextFormField(
            initialValue: _currentSecurityQuestion,
            readOnly: true,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Pregunta de seguridad actual',
              prefixIcon: Icon(Icons.question_answer),
              hintText: 'Tu pregunta de seguridad actual',
            ),
          ),

          const SizedBox(height: 16),

          // Current security answer
          TextFormField(
            controller: _currentSecurityAnswerController,
            decoration: InputDecoration(
              labelText: 'Respuesta de seguridad actual',
              prefixIcon: const Icon(Icons.security),
              hintText:
                  'Escribe la respuesta a tu pregunta de seguridad actual...',
              suffixIcon: IconButton(
                icon: Icon(
                  _currentSecurityAnswerVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _currentSecurityAnswerVisible =
                        !_currentSecurityAnswerVisible;
                  });
                },
              ),
            ),
            obscureText: !_currentSecurityAnswerVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa la respuesta a tu pregunta de seguridad actual';
              }
              return null;
            },
          ),

          const Divider(height: 32),
          const Text(
            'Nueva pregunta de seguridad',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),

          // New security question
          DropdownButtonFormField<String>(
            value: _newSecurityQuestion,
            decoration: const InputDecoration(
              labelText: 'Nueva pregunta de seguridad',
              prefixIcon: Icon(Icons.question_answer),
              hintText: 'Selecciona tu nueva pregunta de seguridad',
            ),
            items: _securityQuestions.map((String question) {
              return DropdownMenuItem<String>(
                value: question,
                child: Text(
                  question,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _newSecurityQuestion = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor selecciona tu nueva pregunta de seguridad';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // New security answer
          TextFormField(
            controller: _newSecurityAnswerController,
            decoration: InputDecoration(
              labelText: 'Nueva respuesta de seguridad',
              prefixIcon: const Icon(Icons.security),
              hintText:
                  'Escribe la respuesta a tu nueva pregunta de seguridad...',
              suffixIcon: IconButton(
                icon: Icon(
                  _newSecurityAnswerVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _newSecurityAnswerVisible = !_newSecurityAnswerVisible;
                  });
                },
              ),
            ),
            obscureText: !_newSecurityAnswerVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa la respuesta a tu nueva pregunta de seguridad';
              }
              return null;
            },
          ),

          // Error and success messages for security question change
          if (_securityQuestionErrorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _securityQuestionErrorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],

          if (_securityQuestionSuccessMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _securityQuestionSuccessMessage!,
              style: TextStyle(color: Colors.green),
            ),
          ],

          // Save button for security question
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  _isChangingSecurityQuestion ? null : _changeSecurityQuestion,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isChangingSecurityQuestion
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
    );
  }
}
