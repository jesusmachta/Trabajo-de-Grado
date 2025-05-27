import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class ForgotPasswordView extends StatefulWidget {
  final Function toggleTheme;

  const ForgotPasswordView({super.key, required this.toggleTheme});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _securityAnswerController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Estado del flujo de recuperación
  int _currentStep = 0;
  String? _resetToken;
  String? _userId;
  String? _error;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedSecurityQuestion = securityQuestions.first;

  // Lista de preguntas de seguridad
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
  void dispose() {
    _emailController.dispose();
    _securityAnswerController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifySecurityInfo() async {
    // Validar el formulario primero
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/forgot-password/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': _emailController.text,
          'date_of_birth': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'security_question': _selectedSecurityQuestion,
          'security_answer': _securityAnswerController.text,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _resetToken = responseData['reset_token'];
          _userId = responseData['user_id'];
          _currentStep = 1; // Avanzar al siguiente paso
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = responseData['detail'] ?? 'Error al verificar información';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión. Intente de nuevo más tarde.';
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    // Validar el formulario primero
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/reset-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reset_token': _resetToken,
          'new_password': _newPasswordController.text,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Restablecimiento exitoso
        setState(() {
          _currentStep = 2; // Avanzar al paso final
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = responseData['detail'] ?? 'Error al restablecer contraseña';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión. Intente de nuevo más tarde.';
        _isLoading = false;
      });
    }
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

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu correo electrónico';
    }
    if (!RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Por favor ingresa un correo electrónico válido';
    }
    return null;
  }

  String? _validateSecurityAnswer(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu respuesta de seguridad';
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
      return 'La contraseña debe contener al menos una letra mayúscula';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'La contraseña debe contener al menos una letra minúscula';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'La contraseña debe contener al menos un número';
    }
    if (!RegExp(r'[!@#\$%\^&\*\(\)_\+\-=\[\]\{\};:"\\|,\.<>\/\?]')
        .hasMatch(value)) {
      return 'La contraseña debe contener al menos un carácter especial';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor confirma tu contraseña';
    }
    if (value != _newPasswordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
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
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildContentForStep(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
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

  Widget _buildContentForStep() {
    switch (_currentStep) {
      case 0:
        return _buildVerificationStep();
      case 1:
        return _buildPasswordResetStep();
      case 2:
        return _buildSuccessStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Verificación de identidad',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Por favor, proporciona la siguiente información para verificar tu identidad.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Email field
        const Text(
          'Correo electrónico',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
          decoration: InputDecoration(
            hintText: 'correo@ejemplo.com',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Date of birth field
        const Text(
          'Fecha de nacimiento',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: 'Selecciona tu fecha de nacimiento',
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
        const Text(
          'Pregunta de seguridad',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedSecurityQuestion,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.security),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
        const Text(
          'Respuesta de seguridad',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _securityAnswerController,
          validator: _validateSecurityAnswer,
          decoration: InputDecoration(
            hintText: 'Tu respuesta',
            prefixIcon: const Icon(Icons.question_answer),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Continue button
        ElevatedButton(
          onPressed: _isLoading ? null : _verifySecurityInfo,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF223A5E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : const Text(
                  'Verificar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPasswordResetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Restablecer contraseña',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Por favor, ingresa tu nueva contraseña.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // New password field
        const Text(
          'Nueva contraseña',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscurePassword,
          validator: _validatePassword,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            helperText:
                'Mínimo 6 caracteres, incluyendo mayúscula, minúscula, número y carácter especial',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 16),

        // Confirm password field
        const Text(
          'Confirmar contraseña',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          validator: _validateConfirmPassword,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Reset button
        ElevatedButton(
          onPressed: _isLoading ? null : _resetPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF223A5E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : const Text(
                  'Cambiar contraseña',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: Colors.green,
          size: 100,
        ),
        const SizedBox(height: 24),
        const Text(
          '¡Contraseña actualizada!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Tu contraseña ha sido actualizada correctamente. Ya puedes iniciar sesión con tu nueva contraseña.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(); // Volver a la pantalla de login
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF223A5E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Volver al login',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
