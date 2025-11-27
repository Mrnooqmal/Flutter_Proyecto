import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/services/dashboard_service.dart';
import '../core/config/app_theme.dart';
import 'ficha_medica_detalle_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService _dashboardService = DashboardService();
  
  bool _isLoading = true;
  String? _error;
  
  // Datos del dashboard
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _consultasPorDia = [];
  List<Map<String, dynamic>> _pacientesPorEdad = [];
  List<Map<String, dynamic>> _topExamenes = [];
  List<Map<String, dynamic>> _topMedicamentos = [];
  List<Map<String, dynamic>> _ultimasConsultas = [];
  List<Map<String, dynamic>> _alertas = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _dashboardService.getEstadisticas(),
        _dashboardService.getConsultasPorDia(dias: 30),
        _dashboardService.getPacientesPorEdad(),
        _dashboardService.getTopExamenes(),
        _dashboardService.getTopMedicamentos(),
        _dashboardService.getUltimasConsultas(),
        _dashboardService.getAlertasSignosVitales(),
      ]);

      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _consultasPorDia = results[1] as List<Map<String, dynamic>>;
        _pacientesPorEdad = results[2] as List<Map<String, dynamic>>;
        _topExamenes = results[3] as List<Map<String, dynamic>>;
        _topMedicamentos = results[4] as List<Map<String, dynamic>>;
        _ultimasConsultas = results[5] as List<Map<String, dynamic>>;
        _alertas = results[6] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos del dashboard: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppTheme.buildAppBar(
        title: 'Dashboard Medico',
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_circle, size: 60, color: AppTheme.red),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      AppTheme.buildPrimaryButton(
                        text: 'Reintentar',
                        icon: CupertinoIcons.refresh,
                        onPressed: _cargarDatos,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  color: AppTheme.primaryPurple,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildConsultasPorDiaChart(),
                              const SizedBox(height: 24),
                        
                              _buildPacientesPorEdadChart(),
                              const SizedBox(height: 24),
                              
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildTopExamenes()),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildTopMedicamentos()),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              _buildUltimasConsultas(),
                              const SizedBox(height: 24),
                              
                              _buildAlertas(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.purpleGradient,
        boxShadow: AppTheme.lightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.chart_bar_alt_fill, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Dashboard Medico',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Resumen general del sistema',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildCompactStat(
                    'Pacientes',
                    _stats['totalPacientes']?.toString() ?? '0',
                    Icons.people_outline,
                    Colors.blue,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Expanded(
                  child: _buildCompactStat(
                    'Ultimos 7d',
                    _stats['consultasHoy']?.toString() ?? '0',
                    Icons.calendar_today,
                    Colors.green,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Expanded(
                  child: _buildCompactStat(
                    'Con Alertas',
                    _stats['pacientesCriticos']?.toString() ?? '0',
                    Icons.warning_amber,
                    Colors.red,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Expanded(
                  child: _buildCompactStat(
                    'Examenes 30d',
                    _stats['examenesPendientes']?.toString() ?? '0',
                    Icons.assessment,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildConsultasPorDiaChart() {
    if (_consultasPorDia.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No hay datos de consultas')),
        ),
      );
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consultas últimos 30 días',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _consultasPorDia.length) {
                            final fecha = DateTime.parse(_consultasPorDia[value.toInt()]['fecha']);
                            return Text('${fecha.day}/${fecha.month}', style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _consultasPorDia.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          (entry.value['cantidad'] as int).toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.teal,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
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

  Widget _buildPacientesPorEdadChart() {
    if (_pacientesPorEdad.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No hay datos de distribución por edad')),
        ),
      );
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribución por Edad',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: _pacientesPorEdad.map((item) {
                    final rangoEdad = item['rangoEdad'] as String;
                    final cantidad = (item['cantidad'] as int).toDouble();
                    Color color;
                    switch (rangoEdad) {
                      case '0-17':
                        color = Colors.blue;
                        break;
                      case '18-40':
                        color = Colors.green;
                        break;
                      case '41-65':
                        color = Colors.orange;
                        break;
                      case '65+':
                        color = Colors.red;
                        break;
                      default:
                        color = Colors.grey;
                    }
                    return PieChartSectionData(
                      value: cantidad,
                      title: '$rangoEdad\n${cantidad.toInt()}',
                      color: color,
                      radius: 80,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopExamenes() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Exámenes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_topExamenes.isEmpty)
              const Center(child: Text('Sin datos'))
            else
              ..._topExamenes.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['examen'],
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item['cantidad'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMedicamentos() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Medicamentos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_topMedicamentos.isEmpty)
              const Center(child: Text('Sin datos'))
            else
              ..._topMedicamentos.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['medicamento'],
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item['cantidad'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildUltimasConsultas() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Últimas Consultas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_ultimasConsultas.isEmpty)
              const Center(child: Text('No hay consultas registradas'))
            else
              ..._ultimasConsultas.map((consulta) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: const Icon(Icons.medical_services, color: Colors.teal),
                    ),
                    title: Text(consulta['nombrePaciente']),
                    subtitle: Text(consulta['motivo'] ?? 'Sin motivo especificado'),
                    trailing: Text(
                      _formatearFecha(consulta['fechaIngreso']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FichaMedicaDetallePage(
                            idPaciente: consulta['idPaciente'],
                          ),
                        ),
                      );
                    },
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertas() {
    if (_alertas.isEmpty) {
      return Card(
        color: Colors.green.shade50,
        elevation: 3,
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 40),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'No hay alertas de signos vitales en los ultimos 7 dias',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.red.shade50,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 30),
                const SizedBox(width: 8),
                Text(
                  'Alertas de Signos Vitales (${_alertas.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._alertas.map((alerta) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alerta['nombrePaciente'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              alerta['alerta'],
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PA: ${alerta['presionArterial'] ?? 'N/A'} | '
                        'Temp: ${alerta['temperatura'] ?? 'N/A'}°C | '
                        'Glucosa: ${alerta['glucosa'] ?? 'N/A'} mg/dL',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatearFecha(alerta['fechaMedicion']),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null) return '';
    try {
      final dt = DateTime.parse(fecha);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return fecha;
    }
  }
}
