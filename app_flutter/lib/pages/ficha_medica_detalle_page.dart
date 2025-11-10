import 'package:flutter/material.dart';
import 'package:app_flutter/core/models/paciente.dart';
import 'package:app_flutter/core/services/pacientes_service.dart';

class FichaMedicaDetallePage extends StatefulWidget {
  final int idPaciente;

  const FichaMedicaDetallePage({super.key, required this.idPaciente});

  @override
  State<FichaMedicaDetallePage> createState() => _FichaMedicaDetallePageState();
}

class _FichaMedicaDetallePageState extends State<FichaMedicaDetallePage> {
  final PacientesService _pacientesService = PacientesService();
  Paciente? _paciente;
  bool _isLoading = true;
  String? _error;
  // Mocked placeholder data to simulate DB-backed details
  List<Map<String, String>> _consultasMock = [];
  List<Map<String, String>> _vitalsMock = [];
  List<Map<String, String>> _medicamentosMock = [];
  List<Map<String, String>> _documentosMock = [];

  @override
  void initState() {
    super.initState();
    _cargarPaciente();
  }

  Future<void> _cargarPaciente() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final paciente = await _pacientesService.getPacienteById(widget.idPaciente);
      // generar datos de ejemplo (placeholders) para simular que vienen de la BDD
      _consultasMock = List.generate(3, (i) {
        final daysAgo = (i + 1) * 30;
        final fecha = DateTime.now().subtract(Duration(days: daysAgo));
        return {
          'fecha': '${fecha.day}/${fecha.month}/${fecha.year}',
          'motivo': i == 0 ? 'Control general' : 'Revisión seguimiento',
          'diagnostico': i == 0 ? 'Estable' : 'Mejoría progresiva',
        };
      });

      _vitalsMock = List.generate(5, (i) {
        final fecha = DateTime.now().subtract(Duration(days: i * 7));
        return {
          'fecha': '${fecha.day}/${fecha.month}',
          'peso': '${70 + i}.${i} kg',
          'presion': '${120 + i}/${80 + i}',
        };
      });

      _medicamentosMock = [
        {'nombre': 'Paracetamol', 'dosis': '500 mg - 1 cada 8h', 'desde': '01/01/2025'},
        {'nombre': 'Omeprazol', 'dosis': '20 mg - 1 diario', 'desde': '15/02/2025'},
      ];

      _documentosMock = [
        {'nombre': 'Ecografía Abdominal.pdf', 'fecha': '12/03/2025'},
        {'nombre': 'Análisis Hematológico.pdf', 'fecha': '05/09/2024'},
      ];
      setState(() {
        _paciente = paciente;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos del paciente: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ficha Médica del Paciente'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargarPaciente,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _paciente == null
                  ? const Center(child: Text('Paciente no encontrado'))
                  : RefreshIndicator(
                      onRefresh: _cargarPaciente,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSeccionPersonal(),
                            const SizedBox(height: 16),
                            _buildSeccionContacto(),
                            const SizedBox(height: 16),
                            _buildSeccionMedica(),
                            const SizedBox(height: 16),
                            _buildConsultasSection(),
                            const SizedBox(height: 16),
                            _buildVitalsSection(),
                            const SizedBox(height: 16),
                            _buildMedicamentosSection(),
                            const SizedBox(height: 16),
                            _buildDocumentosSection(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildSeccionPersonal() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.teal[100],
                  child: Text(
                    _paciente!.nombrePaciente[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[700],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _paciente!.nombrePaciente,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateTime.now().year - _paciente!.fechaNacimiento.year} años',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionContacto() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contact_mail, color: Colors.teal[700]),
                const SizedBox(width: 8),
                const Text(
                  'Información de Contacto',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.email, 'Email', _paciente!.correo ?? 'No especificado'),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone, 'Teléfono', _paciente!.telefono ?? 'No especificado'),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, 'Dirección', _paciente!.direccion ?? 'No especificada'),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionMedica() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_services, color: Colors.teal[700]),
                const SizedBox(width: 8),
                const Text(
                  'Información Médica',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.bloodtype,
              'Tipo de Sangre',
              _paciente!.tipoSangre ?? 'No especificado',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.health_and_safety,
              'Previsión',
              _paciente!.prevision ?? 'No especificada',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConsultasSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Consultas recientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._consultasMock.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.medical_information, color: Colors.blue),
                  title: Text(c['motivo'] ?? '-'),
                  subtitle: Text('${c['fecha']} • ${c['diagnostico']}'),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Signos vitales (histórico)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _vitalsMock.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final v = _vitalsMock[index];
                  return Container(
                    width: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(v['fecha'] ?? '-', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Text(v['peso'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('PA: ${v['presion'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicamentosSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Medicamentos actuales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._medicamentosMock.map((m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.local_pharmacy, color: Colors.deepPurple),
                  title: Text(m['nombre'] ?? '-'),
                  subtitle: Text('${m['dosis']} • Desde: ${m['desde']}'),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentosSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Documentos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._documentosMock.map((d) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(d['nombre'] ?? '-'),
                  subtitle: Text(d['fecha'] ?? '-'),
                  trailing: IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Descargando ${d['nombre']}')));
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
