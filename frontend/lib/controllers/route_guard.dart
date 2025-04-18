import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_controller.dart';
import '../views/login_view.dart';

class RouteGuard {
  static Widget protect(Widget page, {required Function toggleTheme}) {
    return Builder(
      builder: (context) {
        final authController = Provider.of<AuthController>(context);

        // Si no está autenticado, redirigir al login
        if (!authController.isAuthenticated) {
          // Usar Future.microtask para evitar errores de setState durante el build
          Future.microtask(() {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => LoginView(toggleTheme: toggleTheme),
              ),
              (route) => false,
            );
          });

          // Mientras tanto, mostrar un indicador de carga
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Si está autenticado, mostrar la página solicitada
        return page;
      },
    );
  }
}
