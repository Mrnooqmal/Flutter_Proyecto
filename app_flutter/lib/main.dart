import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_flutter/pages/profile_page.dart';
import 'package:app_flutter/pages/dashboard_page.dart';
import 'package:app_flutter/pages/lista_pacientes_page.dart';
import 'package:app_flutter/pages/ficha_medica_detalle_page.dart';
import 'package:app_flutter/core/services/pacientes_service.dart';
import 'package:app_flutter/core/services/dashboard_service.dart';
import 'package:intl/intl.dart';

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
        // ruta dinamica para ficha medica detallada
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
  final DashboardService _dashboardService = DashboardService();
  
  Map<String, dynamic>? _estadisticas;
  List<Map<String, dynamic>> _pacientesRecientes = [];
  List<Map<String, dynamic>> _alertas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    // Conectar SSE al inicio de la app
    _pacientesService.connectToSSE();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      // cargar estadisticas del dashboard
      final stats = await _dashboardService.getEstadisticas();
      
      // cargar ultimas consultas para pacientes recientes
      final consultas = await _dashboardService.getUltimasConsultas();
      
      // cargar alertas de signos vitales
      final alertas = await _dashboardService.getAlertasSignosVitales();
      
      setState(() {
        _estadisticas = stats;
        _pacientesRecientes = consultas;
        _alertas = alertas;
        _isLoading = false;
      });
    } catch (e) {
      print('error cargando datos: $e');
      setState(() {
        _estadisticas = {
          'totalPacientes': 0,
          'consultasHoy': 0,
          'pacientesCriticos': 0,
          'examenesPendientes': 0,
        };
        _pacientesRecientes = [];
        _alertas = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // encabezado superior
              _buildEncabezado(),
              
              const SizedBox(height: 20),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // metricas rapidas
                    _buildMetricasRapidas(),
                    
                    const SizedBox(height: 24),
                    
                    // acciones principales
                    _buildAccionesPrincipales(),
                    
                    const SizedBox(height: 24),
                    
                    // pacientes recientes
                    _buildPacientesRecientes(),
                    
                    const SizedBox(height: 24),
                    
                    // alertas y recordatorios
                    _buildAlertasRecordatorios(),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildEncabezado() {
    final now = DateTime.now();
    final dateFormat = DateFormat('d \'de\' MMMM \'de\' yyyy', 'es_ES');
    final fechaActual = dateFormat.format(now);
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFC9B7F5),
            const Color(0xFFE0D5FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.heart_fill,
                  size: 32,
                  color: Color(0xFFC9B7F5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MediTrack',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sistema de Gestion Medica',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Bienvenido, Dr. Garcia',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fechaActual,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricasRapidas() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC9B7F5)),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Total\nPacientes',
            '${_estadisticas?['totalPacientes'] ?? 0}',
            CupertinoIcons.person_2_fill,
            const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Pacientes\nActivos',
            '${_estadisticas?['totalPacientes'] ?? 0}',
            CupertinoIcons.circle_fill,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Consultas\nesta semana',
            '${_estadisticas?['consultasHoy'] ?? 0}',
            CupertinoIcons.doc_text_fill,
            const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Docs\nsubidos',
            '${_estadisticas?['examenesPendientes'] ?? 0}',
            CupertinoIcons.doc_fill,
            const Color(0xFFEC4899),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionesPrincipales() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              'Crear\nPaciente',
              CupertinoIcons.add_circled_solid,
              const Color(0xFFC9B7F5),
              () => Navigator.of(context).pushNamed('/profile'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              'Buscar\nPaciente',
              CupertinoIcons.search_circle_fill,
              const Color(0xFF6366F1),
              () => Navigator.of(context).pushNamed('/lista-pacientes'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              'Dashboard',
              CupertinoIcons.chart_bar_alt_fill,
              const Color(0xFFEC4899),
              () => Navigator.of(context).pushNamed('/dashboard'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPacientesRecientes() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.person_2,
                  size: 20,
                  color: Color(0xFFC9B7F5),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pacientes Recientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _pacientesRecientes.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No hay consultas recientes',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pacientesRecientes.length > 5 
                          ? 5 
                          : _pacientesRecientes.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final consulta = _pacientesRecientes[index];
                        return _buildPacienteRecenteItem(consulta);
                      },
                    ),
          const Divider(height: 1),
          InkWell(
            onTap: () => Navigator.of(context).pushNamed('/lista-pacientes'),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ver todos',
                    style: TextStyle(
                      color: const Color(0xFFC9B7F5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: const Color(0xFFC9B7F5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPacienteRecenteItem(Map<String, dynamic> consulta) {
    final nombrePaciente = consulta['nombrePaciente'] ?? 'Sin nombre';
    final fechaIngreso = consulta['fechaIngreso'];
    
    String fechaTexto = 'Sin fecha';
    if (fechaIngreso != null) {
      try {
        final fecha = DateTime.parse(fechaIngreso.toString());
        final format = DateFormat('d MMM yyyy', 'es_ES');
        fechaTexto = 'Ultima consulta: ${format.format(fecha)}';
      } catch (e) {
        fechaTexto = 'Fecha invalida';
      }
    }
    
    return InkWell(
      onTap: () {
        final idPaciente = consulta['idPaciente'];
        if (idPaciente != null) {
          Navigator.of(context).pushNamed('/ficha-medica/$idPaciente');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFC9B7F5).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                CupertinoIcons.person_fill,
                color: Color(0xFFC9B7F5),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombrePaciente,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fechaTexto,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertasRecordatorios() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.bell_fill,
                  size: 20,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Alertas / Recordatorios',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _alertas.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildAlertaItem(
                        CupertinoIcons.checkmark_circle_fill,
                        'No hay alertas pendientes',
                        'Todo se ve bien por ahora',
                        const Color(0xFF10B981),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _alertas.length > 3 ? 3 : _alertas.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final alerta = _alertas[index];
                        return _buildAlertaFromData(alerta);
                      },
                    ),
        ],
      ),
    );
  }

  Widget _buildAlertaFromData(Map<String, dynamic> alerta) {
    final nombrePaciente = alerta['nombrePaciente'] ?? 'Paciente';
    final alertaTipo = alerta['alerta'] ?? 'Otro';
    
    IconData icon;
    Color color;
    
    switch (alertaTipo.toLowerCase()) {
      case 'fiebre':
        icon = CupertinoIcons.thermometer;
        color = const Color(0xFFEF4444);
        break;
      case 'hipotermia':
        icon = CupertinoIcons.snow;
        color = const Color(0xFF3B82F6);
        break;
      case 'glucosa alta':
      case 'glucosa baja':
        icon = CupertinoIcons.drop_fill;
        color = const Color(0xFFF59E0B);
        break;
      default:
        icon = CupertinoIcons.exclamationmark_triangle_fill;
        color = const Color(0xFFF59E0B);
    }
    
    return _buildAlertaItem(
      icon,
      nombrePaciente,
      alertaTipo,
      color,
    );
  }

  Widget _buildAlertaItem(IconData icon, String titulo, String subtitulo, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
