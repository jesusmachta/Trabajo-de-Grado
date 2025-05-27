import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../controllers/auth_controller.dart';
import 'home_view.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:frontend/widgets/toast_notification.dart';

class RegisterCompanyView extends StatefulWidget {
  final Function toggleTheme;

  const RegisterCompanyView({super.key, required this.toggleTheme});

  @override
  State<RegisterCompanyView> createState() => _RegisterCompanyViewState();
}

class _RegisterCompanyViewState extends State<RegisterCompanyView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Controllers for all fields
  final _companyNameController = TextEditingController();
  final _rifController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _securityAnswerController = TextEditingController();

  // Tab control
  late TabController _tabController;
  int _currentTab = 0;
  final List<String> _tabs = [
    'Información del Administrador',
    'Información de la Empresa',
    'Información de Seguridad'
  ];

  // New fields for security
  DateTime _selectedDate = DateTime.now();
  String _selectedSecurityQuestion = securityQuestions.first;

  // Security questions list
  static const List<String> securityQuestions = [
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _rifController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _securityAnswerController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Field validators
  String? _validateCompanyName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa el nombre de la empresa';
    }
    return null;
  }

  String? _validateRif(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa el RIF de la empresa';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'El RIF debe contener solo números';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Este campo es requerido';
    }

    // Verify that name starts with a letter, not with numbers or special characters
    if (!RegExp(r'^[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ]').hasMatch(value)) {
      return 'Debe comenzar con letras, no con números o caracteres especiales';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa un correo electrónico';
    }
    if (!RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Por favor ingresa un correo electrónico válido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa una contraseña';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'La contraseña debe tener al menos una letra mayúscula';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'La contraseña debe tener al menos una letra minúscula';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'La contraseña debe tener al menos un número';
    }
    if (!RegExp(r'[!@#\$%\^&\*\(\)_\+\-=\[\]\{\};:"\\\|,\.<>\/\?]')
        .hasMatch(value)) {
      return 'La contraseña debe tener al menos un carácter especial';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor confirma tu contraseña';
    }
    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  String? _validateSecurityAnswer(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu respuesta de seguridad';
    }
    return null;
  }

  // Add method to check if user is at least 18 years old
  bool _isAtLeast18YearsOld(DateTime birthDate) {
    final DateTime today = DateTime.now();
    final DateTime adultDate = DateTime(
      birthDate.year + 18,
      birthDate.month,
      birthDate.day,
    );
    return adultDate.compareTo(today) <= 0;
  }

  // Validate current tab before proceeding
  bool _validateCurrentTab() {
    switch (_currentTab) {
      case 0: // Admin information
        return _firstNameController.text.isNotEmpty &&
            _lastNameController.text.isNotEmpty &&
            _validateEmail(_emailController.text) == null &&
            _validatePassword(_passwordController.text) == null &&
            _validateConfirmPassword(_confirmPasswordController.text) == null;
      case 1: // Company information
        return _validateCompanyName(_companyNameController.text) == null &&
            _validateRif(_rifController.text) == null;
      case 2: // Security information
        return _validateSecurityAnswer(_securityAnswerController.text) ==
                null &&
            _isAtLeast18YearsOld(_selectedDate);
      default:
        return false;
    }
  }

  void _nextTab() {
    if (_validateCurrentTab()) {
      _tabController.animateTo(_currentTab + 1);
    } else {
      // Form validation will show errors
      _formKey.currentState?.validate();
    }
  }

  void _previousTab() {
    _tabController.animateTo(_currentTab - 1);
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
              primary: const Color(0xFF223A5E), // Header background color
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
      // Validate that the user is at least 18 years old
      if (!_isAtLeast18YearsOld(picked)) {
        ToastService.showWarning(
            context, 'El usuario debe tener al menos 18 años de edad.');
        return;
      }
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _registerCompany() async {
    // Validate all tabs
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate age before proceeding
    if (!_isAtLeast18YearsOld(_selectedDate)) {
      ToastService.showWarning(
          context, 'El usuario debe tener al menos 18 años de edad.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Make API call to register company
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/register-company'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombre_empresa': _companyNameController.text,
          'rif': _rifController.text,
          'nombre_responsable': _firstNameController.text,
          'apellido_responsable': _lastNameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'date_of_birth': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'security_question': _selectedSecurityQuestion,
          'security_answer': _securityAnswerController.text,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Registration successful - update auth state and navigate
        final authController =
            Provider.of<AuthController>(context, listen: false);

        final success = await authController.login(
            _emailController.text, _passwordController.text, true // Remember me
            );

        if (success && mounted) {
          // Navigate to home view
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeView(toggleTheme: widget.toggleTheme),
            ),
          );
        }
      } else {
        // Handle different error cases with user-friendly messages
        String errorMessage;

        if (response.statusCode == 409) {
          // Conflict - already exists
          errorMessage =
              data['detail'] ?? 'Ya existe una empresa con estos datos';

          // Highlight the specific field if possible
          if (data['detail'] != null) {
            if (data['detail'].contains('nombre')) {
              // Show error on company name field
              setState(() {
                _formKey.currentState?.validate();
              });
            } else if (data['detail'].contains('RIF')) {
              // Show error on RIF field
              setState(() {
                _formKey.currentState?.validate();
              });
            } else if (data['detail'].contains('correo')) {
              // Show error on email field
              setState(() {
                _formKey.currentState?.validate();
              });
            }
          }
        } else if (response.statusCode == 400) {
          // Bad request - validation error
          errorMessage =
              data['detail'] ?? 'Por favor revisa los datos ingresados';
        } else {
          // Other errors
          errorMessage =
              'Error al registrar la empresa: ${data['detail'] ?? 'Intenta nuevamente'}';
        }

        setState(() {
          _errorMessage = errorMessage;
        });

        // Show a snackbar with the error
        if (mounted) {
          ToastService.showError(
            context,
            _errorMessage ?? 'Error al registrar la empresa',
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión. Intente de nuevo más tarde: $e';
      });

      // Show a snackbar with the connection error
      if (mounted) {
        ToastService.showError(
          context,
          'Error de conexión al servidor',
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    const Text(
                      'Registra tu empresa',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Completa la información para crear tu cuenta empresarial',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Progress indicator
                    LinearProgressIndicator(
                      value: (_currentTab + 1) / 3,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF223A5E),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Step Tabs
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (int i = 0; i < 3; i++)
                          _buildStepIndicator(
                              i + 1, i == _currentTab, i < _currentTab),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tab title
                    Text(
                      _tabs[_currentTab],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Tab content
                    SizedBox(
                      height: 400, // Fixed height for the tab content
                      child: TabBarView(
                        controller: _tabController,
                        physics:
                            const NeverScrollableScrollPhysics(), // Disable swiping
                        children: [
                          // Tab 1: Admin Information
                          _buildAdminInfoTab(),

                          // Tab 2: Company Information
                          _buildCompanyInfoTab(),

                          // Tab 3: Security Information
                          _buildSecurityInfoTab(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              'Volver al inicio de sesión',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        // Add back button
                        _currentTab > 0
                            ? OutlinedButton(
                                onPressed: _previousTab,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_back, size: 16),
                                    SizedBox(width: 4),
                                    Text('Atrás'),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (_currentTab < 2 ? _nextTab : _registerCompany),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            backgroundColor: const Color(0xFF223A5E),
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_currentTab < 2
                                  ? 'Siguiente'
                                  : 'Registrar Empresa'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Step indicator widget
  Widget _buildStepIndicator(int step, bool isActive, bool isCompleted) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF223A5E)
                : (isCompleted ? Colors.green : Colors.grey[300]),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _tabs[step - 1].split(' ').last,
          style: TextStyle(
            color: isActive ? const Color(0xFF223A5E) : Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Tab 1: Admin Information
  Widget _buildAdminInfoTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Admin Information Fields
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Tu nombre',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: _validateName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: 'Apellido',
              hintText: 'Tu apellido',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: _validateName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Correo Electrónico',
              hintText: 'Ingresa tu correo electrónico',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              hintText: 'Ingresa tu contraseña',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              helperText:
                  'Debe tener al menos 6 caracteres, incluyendo mayúscula, minúscula, número y carácter especial',
              helperMaxLines: 2,
            ),
            validator: _validatePassword,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              hintText: 'Vuelve a ingresar tu contraseña',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            validator: _validateConfirmPassword,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // Tab 2: Company Information
  Widget _buildCompanyInfoTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Company Information Fields
          TextFormField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Nombre de la Empresa',
              hintText: 'Ingresa el nombre completo de la empresa',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
            validator: _validateCompanyName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _rifController,
            decoration: const InputDecoration(
              labelText: 'RIF',
              hintText: 'Ingresa el RIF (solo números)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
            keyboardType: TextInputType.number,
            validator: _validateRif,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // Tab 3: Security Information
  Widget _buildSecurityInfoTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Security Information Fields
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
                setState(() {
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
            ),
            validator: _validateSecurityAnswer,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
