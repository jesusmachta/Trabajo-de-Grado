import 'package:flutter/material.dart';

class HelpView extends StatelessWidget {
  const HelpView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda'),
        centerTitle: false,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Cómo usar StoreSense?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 24),
            _buildHelpSection(
              context,
              title: 'Navegación básica',
              content:
                  'Utiliza el menú lateral para acceder a las diferentes secciones de la aplicación. Puedes abrirlo deslizando desde el borde izquierdo de la pantalla o tocando el icono de menú en la esquina superior izquierda.',
              icon: Icons.menu,
            ),
            _buildHelpSection(
              context,
              title: 'Dashboard',
              content:
                  'El Dashboard te muestra un resumen de las métricas más importantes de tu tienda, como el número de visitantes, distribución por sexo y edad, y las emociones detectadas en tiempo real.',
              icon: Icons.dashboard,
            ),
            _buildHelpSection(
              context,
              title: 'Estadísticas',
              content:
                  'La sección de Estadísticas te permite analizar datos detallados sobre tus clientes. Utiliza los selectores para elegir el tipo de estadística y periodo que deseas visualizar. Puedes ver información sobre horas pico, días más concurridos, categorías más visitadas y más.',
              icon: Icons.bar_chart,
            ),
            _buildHelpSection(
              context,
              title: 'Gestión de Usuarios',
              content:
                  'Los administradores pueden crear, editar y eliminar usuarios del sistema, así como asignar diferentes roles y permisos.',
              icon: Icons.people,
            ),
            _buildHelpSection(
              context,
              title: 'Categorías',
              content:
                  'Administra las categorías de productos de tu tienda. Puedes crear nuevas categorías, editar las existentes o eliminarlas según sea necesario.',
              icon: Icons.category,
            ),
            _buildHelpSection(
              context,
              title: 'Gestión de Cámaras',
              content:
                  'Configura y administra las cámaras de tu tienda para monitorear a los clientes y recopilar datos analíticos.',
              icon: Icons.videocam,
            ),
            _buildHelpSection(
              context,
              title: 'Chat IA',
              content:
                  'Utiliza nuestro asistente de IA para hacer preguntas sobre tus datos o recibir sugerencias basadas en el análisis de tus clientes. Simplemente haz clic en el ícono del chat en la barra superior.',
              icon: Icons.auto_awesome,
            ),
            _buildHelpSection(
              context,
              title: 'Cambio de tema',
              content:
                  'Puedes cambiar entre el tema claro y oscuro utilizando el botón en el menú lateral. Esto te permite personalizar la apariencia de la aplicación según tus preferencias.',
              icon: Icons.brightness_6,
            ),
            const SizedBox(height: 32),
            Text(
              'Preguntas frecuentes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            _buildFAQItem(
              context,
              question: '¿Cómo se recopilan los datos de los clientes?',
              answer:
                  'StoreSense utiliza visión artificial avanzada a través de las cámaras instaladas en la tienda para detectar y analizar a los clientes. El sistema reconoce características como edad, sexo y emociones, todo sin almacenar imágenes de las personas para proteger su privacidad.',
            ),
            _buildFAQItem(
              context,
              question: '¿Los datos son precisos?',
              answer:
                  'El sistema utiliza modelos de IA entrenados para proporcionar estimaciones con un alto grado de precisión. Sin embargo, como toda tecnología de visión artificial, puede haber pequeñas variaciones en las predicciones. Los datos son más fiables cuando se analizan tendencias a lo largo del tiempo.',
            ),
            _buildFAQItem(
              context,
              question: '¿Cómo puedo obtener ayuda adicional?',
              answer:
                  'Si necesitas asistencia técnica o tienes preguntas específicas, puedes contactar al equipo de soporte a través del correo electrónico: soporte@storesense.com',
            ),
            const SizedBox(height: 40),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.support_agent,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¿Necesitas más ayuda?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contacta a nuestro equipo de soporte',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        // Implementar funcionalidad de contacto aquí
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Correo de soporte: catalina.matheus@correo.unimet.edu.ve'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.email),
                      label: const Text('Contactar soporte'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection(BuildContext context,
      {required String title,
      required String content,
      required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 44.0),
            child: Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context,
      {required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.help_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: Text(
              answer,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
