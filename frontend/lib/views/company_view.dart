import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/auth_controller.dart';
import '../widgets/toast_notification.dart';
import '../config.dart'; // Import the config file

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
        Uri.parse(AppConfig.getApiUrl('delete-company')),
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
        title: const Align(
          alignment: Alignment.centerLeft,
          child: Text('Informacion de la empresa'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 32, horizontal: 24),
                        child: Column(
                          children: [
                            Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.business,
                                  size: 56,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              currentUser.empresa ?? 'Mi Empresa',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (currentUser.rif != null)
                              Text(
                                'RIF: ${currentUser.rif}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final Uri url = Uri.parse(
                                    'https://sites.google.com/farmatodo.com/storesense/p%C3%A1gina-principal');
                                if (!await launchUrl(url,
                                    mode: LaunchMode.externalApplication)) {
                                  ToastService.showError(
                                      context, 'No se pudo abrir el enlace');
                                }
                              },
                              icon: const Icon(Icons.search),
                              label:
                                  const Text('Búsqueda acerca de la empresa'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Eliminar empresa (más elegante)
                  Card(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.red.shade900.withOpacity(0.3)
                        : Colors.red[50],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.delete_forever,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.red[300]
                                      : Colors.red[400]),
                              const SizedBox(width: 8),
                              Text(
                                'Eliminar empresa',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.red[300]
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Esta acción eliminará permanentemente todos los datos asociados a la empresa. Por favor, confirma para continuar.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!_showDeleteConfirmation) ...[
                            Center(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isLoading ? null : _showDeleteDialog,
                                icon: const Icon(Icons.delete_forever,
                                    color: Colors.white),
                                label: const Text('Eliminar Empresa',
                                    style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ] else ...[
                            // Delete confirmation
                            Text(
                              'Para confirmar, escriba el nombre de la empresa:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _confirmController,
                              decoration: InputDecoration(
                                labelText: 'Nombre de la empresa',
                                hintText:
                                    'Ingrese el nombre exacto para confirmar',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
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
                                          style:
                                              TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.red[300]
                                    : Colors.red[700],
                              ),
                            ),
                          ],
                        ],
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
