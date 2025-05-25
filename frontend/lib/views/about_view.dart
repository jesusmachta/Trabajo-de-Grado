import 'package:flutter/material.dart';
import 'package:frontend/widgets/toast_notification.dart';

class AboutView extends StatelessWidget {
  const AboutView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de'),
        centerTitle: false,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.analytics,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Nombre de la aplicación
            Text(
              'StoreSense',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),

            Text(
              'Versión 1.0.0',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),

            const SizedBox(height: 32),

            // Descripción del proyecto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acerca del proyecto',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'StoreSense es una aplicación de análisis de clientes para tiendas físicas desarrollada como trabajo de grado para la Universidad Metropolitana (UNIMET).',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'El sistema utiliza visión artificial e inteligencia artificial para proporcionar información valiosa sobre los patrones de comportamiento de los clientes, lo que permite a los propietarios de tiendas tomar decisiones más informadas para mejorar la experiencia del cliente y optimizar sus operaciones.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Desarrolladores
            Text(
              'Desarrollado por',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),

            _buildDeveloperCard(
              context,
              name: 'Jesús Machta',
              role: 'Desarrollador Frontend & Backend',
              imageUrl: null, // Puedes agregar una URL de imagen si lo deseas
            ),

            _buildDeveloperCard(
              context,
              name: 'Catalina Matheus',
              role: 'Desarrolladora Frontend & Backend',
              imageUrl: null,
            ),

            const SizedBox(height: 32),

            // Tecnologías utilizadas
            Text(
              'Tecnologías utilizadas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildTechChip(context, 'Flutter'),
                _buildTechChip(context, 'Python'),
                _buildTechChip(context, 'Flask'),
                _buildTechChip(context, 'OpenCV'),
                _buildTechChip(context, 'TensorFlow'),
                _buildTechChip(context, 'PostMan'),
                _buildTechChip(context, 'MongoDB'),
                _buildTechChip(context, 'AWS'),
                _buildTechChip(context, 'ArduinoIDE'),
                _buildTechChip(context, 'ESP32-CAM'),
                _buildTechChip(context, 'Visual Studio Code'),
                _buildTechChip(context, 'Figma'),
                _buildTechChip(context, 'GitHub'),
                _buildTechChip(context, 'Render'),
                _buildTechChip(context, 'Dart'),
                _buildTechChip(context, 'Google Material Design'),
              ],
            ),

            const SizedBox(height: 32),

            // Agradecimientos
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agradecimientos',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Queremos expresar nuestro sincero agradecimiento a nuestro tutor académico Luis Eduardo Bello, a Luis Sánchez y a todos los profesores de la Universidad Metropolitana que nos brindaron su apoyo y orientación durante el desarrollo de este proyecto.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'También agradecemos a la Frutería Los Pomelos por permitirnos implementar y probar nuestro sistema en su establecimiento.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Y no olvidemos a nuestros padres: Nelly, Gefry, Gabriel y Rodolfo. Nuestro hermanos: María Paula y Adib. Y obviamente a nuestros amigos: Christian, Diana, Giovanna, Frank, Victoria y Luis por su apoyo incondicional y por estar siempre con nosotros.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Información de contacto
            Text(
              'Contacto',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildContactButton(
                  context,
                  icon: Icons.email,
                  label: 'Email',
                  onPressed: () {
                    ToastService.showInfo(
                      context,
                      'Contacto: jesus.machta@correo.unimet.edu.ve',
                    );
                  },
                ),
                const SizedBox(width: 16),
                _buildContactButton(
                  context,
                  icon: Icons.web,
                  label: 'Web',
                  onPressed: () {
                    ToastService.showInfo(
                      context,
                      'Sitio web: www.storesense.com',
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            Text(
              '© 2025 StoreSense - Todos los derechos reservados',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperCard(BuildContext context,
      {required String name, required String role, String? imageUrl}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: imageUrl == null
                  ? Icon(
                      Icons.person,
                      size: 30,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Información
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechChip(BuildContext context, String label) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildContactButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
}
