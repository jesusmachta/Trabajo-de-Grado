import 'package:flutter/material.dart';

class OnboardingView extends StatefulWidget {
  final Function toggleTheme;
  final VoidCallback onFinish;
  const OnboardingView(
      {Key? key, required this.toggleTheme, required this.onFinish})
      : super(key: key);

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  int _currentStep = 0;

  final List<_OnboardingStepData> _steps = [
    _OnboardingStepData(
      image: 'assets/images/onboarding/Dashboard.png',
      title: 'Comienza a entender mejor a tus clientes con StoreSense',
      subtitle:
          'Una aplicación web que te permitirá conocer a las personas que visitan tu tienda física.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('¿Qué puedes hacer en StoreSense?',
              style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 12),
          _OnboardingListItem(
            title: '1. Estadísticas y métricas',
            description:
                'Conoce horarios pico, emociones, qué zonas son más visitadas y mucho más.',
          ),
          _OnboardingListItem(
            title: '2. Configuración de categorías',
            description: 'Define las secciones de tu tienda para el análisis.',
          ),
          _OnboardingListItem(
            title: '3. Configuración de cámaras',
            description: 'Asocia cada cámara con una categoría específica.',
          ),
          _OnboardingListItem(
            title: '4. Roles y privilegios',
            description:
                'Controla quién accede y qué puede ver dentro del sistema.',
          ),
          // El botón de volver al inicio de sesión se agrega dinámicamente en build
        ],
      ),
    ),
    _OnboardingStepData(
      image: 'assets/images/onboarding/Dashboard.png',
      title: 'Estadísticas y métricas',
      subtitle:
          'Obtén una visión completa del comportamiento en tu tienda física. Analiza en tiempo real datos clave como el flujo de visitantes, las emociones predominantes, los productos más vistos y los momentos de mayor afluencia.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('¿Qué tipo de estadísticas tendrás disponibles?',
              style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 12),
          _OnboardingListText('Categorías más vistas por día y hora'),
          _OnboardingListText('Emociones predominantes por categoría'),
          _OnboardingListText('Categoría preferida por sexo'),
          _OnboardingListText('Días y horarios de mayor tráfico'),
        ],
      ),
    ),
    _OnboardingStepData(
      image: 'assets/images/onboarding/Categorias.png',
      title: 'Configuración de categorías',
      subtitle:
          'Crea, edita o desactiva las categorías de productos para facilitar el análisis y la visualización de datos.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('¿Qué puedes hacer desde aquí?',
              style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 12),
          _OnboardingListText('Crear nuevas categorías personalizadas'),
          _OnboardingListText('Editar nombres e íconos'),
          _OnboardingListText(
              'Activar o desactivar categorías según disponibilidad'),
          _OnboardingListText('Buscar y filtrar categorías existentes'),
        ],
      ),
    ),
    _OnboardingStepData(
      image: 'assets/images/onboarding/Camaras.png',
      title: 'Configuración de cámaras',
      subtitle:
          'Asocia cada cámara a una categoría de productos para organizar mejor los datos que se capturan. Desde esta sección podrás gestionar el estado y la asignación de cada dispositivo en tu tienda.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('¿Qué puedes hacer desde aquí?',
              style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 12),
          _OnboardingListText('Asignar cámaras a categorías específicas'),
          _OnboardingListText(
              'Activar o desactivar cámaras según disponibilidad'),
          _OnboardingListText('Editar o eliminar cámaras'),
          _OnboardingListText('Filtrar y buscar cámaras registradas'),
        ],
      ),
    ),
    _OnboardingStepData(
      image: 'assets/images/onboarding/Usuarios.png',
      title: 'Configuración de roles y privilegios',
      subtitle:
          'Gestiona los accesos de cada usuario según sus funciones dentro del sistema. Desde esta sección podrás asignar roles, activar o desactivar usuarios y definir quién puede ver o modificar información sensible.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('¿Qué puedes hacer desde aquí?',
              style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 12),
          _OnboardingListText('Crear y gestionar usuarios'),
          _OnboardingListText('Asignar roles'),
          _OnboardingListText('Activar o desactivar cuentas según necesidad'),
          _OnboardingListText('Filtrar usuarios por rol o estado'),
        ],
      ),
    ),
  ];

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      widget.onFinish();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final progress = (_currentStep + 1) / _steps.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('StoreSense'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Progress indicator at the top, centered
          Center(
            child: SizedBox(
              width: 300, // Fixed width for the progress bar
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF0277BD)),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Main content
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Row(
                    children: [
                      // Left: Texts and content
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              step.subtitle,
                              style: const TextStyle(
                                  fontSize: 18, color: Colors.black87),
                            ),
                            step.content,
                            if (_currentStep == 0) ...[
                              const SizedBox(height: 24),
                              Align(
                                alignment: Alignment.centerLeft,
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
                            ],
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                if (_currentStep > 0)
                                  ElevatedButton(
                                    onPressed: _previousStep,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[400],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 16),
                                    ),
                                    child: const Text('Anterior',
                                        style: TextStyle(fontSize: 16)),
                                  ),
                                if (_currentStep > 0) const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: _nextStep,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0277BD),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 16),
                                  ),
                                  child: Text(
                                      _currentStep == _steps.length - 1
                                          ? 'Siguiente'
                                          : 'Siguiente',
                                      style: const TextStyle(fontSize: 16)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      // Right: Image
                      Expanded(
                        flex: 6,
                        child: Container(
                          width: double.infinity,
                          height:
                              400, // Tamaño estándar para todas las imágenes
                          alignment: Alignment.center,
                          // Quitar decoración de fondo y sombra
                          child: Image.asset(
                            step.image,
                            fit: BoxFit.contain, // No recorta la imagen
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStepData {
  final String image;
  final String title;
  final String subtitle;
  final Widget content;
  _OnboardingStepData(
      {required this.image,
      required this.title,
      required this.subtitle,
      required this.content});
}

class _OnboardingListItem extends StatelessWidget {
  final String title;
  final String description;
  const _OnboardingListItem({required this.title, required this.description});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          children: [
            TextSpan(
                text: '$title\n',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(
                text: description,
                style: const TextStyle(fontSize: 15, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _OnboardingListText extends StatelessWidget {
  final String text;
  const _OnboardingListText(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
      ),
    );
  }
}
