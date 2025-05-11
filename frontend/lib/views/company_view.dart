import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../widgets/toast_notification.dart';

class CompanyView extends StatefulWidget {
  const CompanyView({Key? key}) : super(key: key);

  @override
  State<CompanyView> createState() => _CompanyViewState();
}

class _CompanyViewState extends State<CompanyView> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _showDeleteConfirmation = false;
  final TextEditingController _confirmController = TextEditingController();

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  // Helper function to show delete confirmation dialog
  void _showDeleteDialog() {
    setState(() {
      _showDeleteConfirmation = true;
      _confirmController.clear();
    });
  }

  // Function to delete the company
  Future<void> _deleteCompany() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final String? token = authController.token;
    final String? empresa = authController.currentUser?.empresa;

    if (token == null || empresa == null) {
      ToastService.showError(context, 'Error de autenticación');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.delete(
        Uri.parse('http://localhost:8000/api/delete-company'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Company deleted successfully, log out the user
        await authController.logout();

        // Show success notification (though it might not be visible long as we're logging out)
        ToastService.showSuccess(context, 'Empresa eliminada correctamente');
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              responseData['detail'] ?? 'Error al eliminar la empresa';
        });

        ToastService.showError(context, _errorMessage!);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de conexión: $e';
      });

      ToastService.showError(context, 'Error de conexión: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final currentUser = authController.currentUser;
    final theme = Theme.of(context);

    // User must be logged in and an admin to access this view
    if (currentUser == null || currentUser.role != 'admin') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('StoreSense'),
        ),
        body: const Center(
          child: Text('Acceso denegado. Solo disponible para administradores.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Información de la Empresa'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company icon and name
                  Center(
                    child: Column(
                      children: [
                        Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.business,
                              size: 64,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          currentUser.empresa ?? 'Mi Empresa',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (currentUser.rif != null)
                          Text(
                            'RIF: ${currentUser.rif}',
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Danger Zone
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Zona de Peligro',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Eliminar empresa',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Esta acción eliminará permanentemente todos los datos de la empresa, incluyendo usuarios, cámaras, categorías y estadísticas. Esta acción no puede ser revertida.',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_showDeleteConfirmation) ...[
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _showDeleteDialog,
                            icon: const Icon(Icons.delete_forever,
                                color: Colors.white),
                            label: const Text('Eliminar Empresa',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ] else ...[
                          // Delete confirmation
                          const Text(
                            'Para confirmar, escriba el nombre de la empresa:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _confirmController,
                            decoration: InputDecoration(
                              hintText: currentUser.empresa,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showDeleteConfirmation = false;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                ),
                                child: const Text('Cancelar',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _isLoading ||
                                        _confirmController.text !=
                                            (currentUser.empresa ?? '')
                                    ? null
                                    : _deleteCompany,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Confirmar eliminación',
                                        style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ],
                      ],
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
