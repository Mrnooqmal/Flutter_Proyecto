import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_flutter/pages/profile_page.dart';
import 'package:app_flutter/pages/dashboard_page.dart';
import 'package:app_flutter/pages/lista_pacientes_page.dart';
import 'package:app_flutter/pages/ficha_medica_detalle_page.dart';
import 'package:app_flutter/core/services/pacientes_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediTrack - Fichas Médicas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'ES'),
      routes: {
        '/': (context) => const MyHomePage(title: 'MediTrack - Inicio'),
        '/profile': (context) => const ProfilePage(),
        '/dashboard': (context) => const DashboardPage(),
        '/lista-pacientes': (context) => const ListaPacientesPage(),
      },
      onGenerateRoute: (settings) {
        // Ruta dinámica para ficha médica detallada
        if (settings.name?.startsWith('/ficha-medica/') ?? false) {
          final idPaciente = int.tryParse(settings.name!.split('/').last);
          if (idPaciente != null) {
            return MaterialPageRoute(
              builder: (context) => FichaMedicaDetallePage(idPaciente: idPaciente),
            );
          }
        }
        return null;
      },
      initialRoute: '/',
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PacientesService _pacientesService = PacientesService();
  Map<String, dynamic>? _estadisticas;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() => _isLoading = true);
    
    try {
      final pacientes = await _pacientesService.getPacientes();
      
      setState(() {
        _estadisticas = {
          'totalPacientes': pacientes.length,
          'pacientesActivos': pacientes.length,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando estadísticas: $e');
      // Usar valores por defecto en caso de error
      setState(() {
        _estadisticas = {
          'totalPacientes': 0,
          'pacientesActivos': 0,
        };
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargarEstadisticas,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarEstadisticas,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 24),

              // Estadísticas rápidas
              const Text(
                'Resumen General',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildEstadisticasGrid(),
              const SizedBox(height: 24),

              // Accesos rápidos
              const Text(
                'Accesos Rápidos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildAccesosRapidos(),
              const SizedBox(height: 24),

              // Acciones principales
              const Text(
                'Gestión de Pacientes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildAccionesPrincipales(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.medical_services,
                size: 48,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MediTrack',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sistema de Gestión de Fichas Médicas',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bienvenido al panel de control',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticasGrid() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard(
          'Total Pacientes',
          '${_estadisticas?['totalPacientes'] ?? 0}',
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Pacientes Activos',
          '${_estadisticas?['pacientesActivos'] ?? 0}',
          Icons.person,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              flex: 0,
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 4),
            Flexible(
              fit: FlexFit.loose,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              fit: FlexFit.loose,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccesosRapidos() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickAccessCard(
            'Ver Pacientes',
            Icons.list_alt,
            Colors.blue,
            () => Navigator.of(context).pushNamed('/lista-pacientes'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickAccessCard(
            'Dashboard',
            Icons.dashboard,
            Colors.red,
            () => Navigator.of(context).pushNamed('/dashboard'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccionesPrincipales() {
    return Column(
      children: [
        _buildActionButton(
          'Crear Nuevo Paciente',
          'Registrar un nuevo paciente en el sistema',
          Icons.person_add,
          Colors.green,
          () => Navigator.of(context).pushNamed('/profile'),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Lista de Pacientes',
          'Ver y gestionar todos los pacientes registrados',
          Icons.people,
          Colors.blue,
          () => Navigator.of(context).pushNamed('/lista-pacientes'),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Dashboard Médico',
          'Estadísticas, gráficos y alertas del sistema',
          Icons.dashboard,
          Colors.red,
          () => Navigator.of(context).pushNamed('/dashboard'),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
}
