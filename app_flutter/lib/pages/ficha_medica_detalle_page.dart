import 'package:flutter/material.dart';
import 'package:app_flutter/core/models/paciente.dart';
import 'package:app_flutter/core/services/pacientes_service.dart';
import 'package:app_flutter/pages/archivo_examen_viewer.dart';
import 'package:app_flutter/pages/subir_archivo_examen_page.dart';

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
  
  // Datos reales desde la BD
  List<Map<String, dynamic>> _consultas = [];
  List<Map<String, dynamic>> _signosVitales = [];
  List<Map<String, dynamic>> _medicamentosCronicos = [];
  List<Map<String, dynamic>> _habitos = [];
  List<Map<String, dynamic>> _alergias = [];
  List<Map<String, dynamic>> _vacunas = [];
  List<Map<String, dynamic>> _examenes = [];

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
      // Cargar paciente
      final paciente = await _pacientesService.getPacienteById(widget.idPaciente);
      
      // Cargar consultas
      final consultas = await _pacientesService.getConsultasPaciente(widget.idPaciente);
      
      // Cargar signos vitales
      final signosVitales = await _pacientesService.getSignosVitalesPaciente(widget.idPaciente);
      
      // cargar medicamentos cronicos
      final medicamentos = await _pacientesService.getMedicamentosCronicosPaciente(widget.idPaciente);

      // cargar habitos
      final habitos = await _pacientesService.getHabitosPaciente(widget.idPaciente);
      
      // Cargar alergias
      final alergias = await _pacientesService.getAlergiasPaciente(widget.idPaciente);
      
      // Cargar vacunas
      final vacunas = await _pacientesService.getVacunasPaciente(widget.idPaciente);
      
      // cargar examenes
      final examenes = await _pacientesService.getExamenesPaciente(widget.idPaciente);

      setState(() {
        _paciente = paciente;
        _consultas = consultas;
        _signosVitales = signosVitales;
        _medicamentosCronicos = medicamentos;
        _habitos = habitos;
        _alergias = alergias;
        _vacunas = vacunas;
        _examenes = examenes;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Subir Examen',
            onPressed: () async {
              final resultado = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubirArchivoExamenPage(
                    idPacientePreseleccionado: widget.idPaciente,
                    nombrePacientePreseleccionado: _paciente?.nombrePaciente,
                  ),
                ),
              );
              
              // si se subio exitosamente recargar datos
              if (resultado == true) {
                _cargarPaciente();
              }
            },
          ),
        ],
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
                            if (_consultas.isNotEmpty) ...[
                              _buildConsultasSection(),
                              const SizedBox(height: 16),
                            ],
                            if (_signosVitales.isNotEmpty) ...[
                              _buildVitalsSection(),
                              const SizedBox(height: 16),
                            ],
                            if (_medicamentosCronicos.isNotEmpty) ...[
                              _buildMedicamentosSection(),
                              const SizedBox(height: 16),
                            ],
                            if (_habitos.isNotEmpty) ...[
                              _buildHabitosSection(),
                              const SizedBox(height: 16),
                            ],
                            if (_alergias.isNotEmpty) ...[
                              _buildAlergiasSection(),
                              const SizedBox(height: 16),
                            ],
                            if (_vacunas.isNotEmpty) ...[
                              _buildVacunasSection(),
                              const SizedBox(height: 16),
                            ],
                            if (_examenes.isNotEmpty) ...[
                              _buildExamenesSection(),
                              const SizedBox(height: 16),
                            ],
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
            if (_consultas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay consultas registradas', style: TextStyle(color: Colors.grey)),
              )
            else
              ..._consultas.map((c) {
                final fecha = c['fechaIngreso'] ?? '-';
                final motivo = c['motivo'] ?? 'Sin motivo';
                final observacion = c['observacion'] ?? '-';
                final profesional = c['nombreProfesional'] ?? 'No especificado';
                final especialidad = c['especialidad'] ?? '';
                
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.medical_information, color: Colors.blue),
                  title: Text(motivo),
                  subtitle: Text(
                    '$fecha\n$observacion\nDr. $profesional${especialidad.isNotEmpty ? ' - $especialidad' : ''}',
                  ),
                  isThreeLine: true,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsSection() {
    // Agrupar signos vitales por fecha/consulta
    final Map<String, Map<String, String>> vitalesPorFecha = {};
    
    for (var signo in _signosVitales) {
      final fecha = signo['fechaRegistro'] ?? signo['fechaIngreso'] ?? '-';
      if (!vitalesPorFecha.containsKey(fecha)) {
        vitalesPorFecha[fecha] = {};
      }
      
      final tipo = signo['tipoDato'] ?? '';
      final valor = signo['valor'] ?? '-';
      
      if (tipo.contains('Peso')) {
        vitalesPorFecha[fecha]!['peso'] = valor;
      } else if (tipo.contains('Presi')) {
        vitalesPorFecha[fecha]!['presion'] = valor;
      } else if (tipo.contains('Temperatura')) {
        vitalesPorFecha[fecha]!['temperatura'] = valor;
      }
    }

    final vitalesAgrupados = vitalesPorFecha.entries.take(10).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Signos vitales (histórico)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (vitalesAgrupados.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay signos vitales registrados', style: TextStyle(color: Colors.grey)),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: vitalesAgrupados.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final entry = vitalesAgrupados[index];
                    final fecha = entry.key;
                    final valores = entry.value;
                    
                    return Container(
                      width: 140,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fecha.length > 12 ? fecha.substring(0, 10) : fecha, 
                            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (valores['peso'] != null)
                            Flexible(
                              child: Text(
                                'Peso: ${valores['peso']}', 
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (valores['presion'] != null)
                            Flexible(
                              child: Text(
                                'PA: ${valores['presion']}', 
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (valores['temperatura'] != null)
                            Flexible(
                              child: Text(
                                'T: ${valores['temperatura']}', 
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
            const Text('Medicamentos crónicos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_medicamentosCronicos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay medicamentos crónicos registrados', style: TextStyle(color: Colors.grey)),
              )
            else
              ..._medicamentosCronicos.map((m) {
                final nombre = m['nombreMedicamento'] ?? 'Sin nombre';
                final empresa = m['empresa'] ?? '';
                final fechaInicio = m['fechaInicio'] ?? '-';
                final cronico = m['cronico'] == 1 || m['cronico'] == true;
                
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.local_pharmacy, color: cronico ? Colors.deepPurple : Colors.orange),
                  title: Text(nombre),
                  subtitle: Text('${empresa.isNotEmpty ? '$empresa • ' : ''}Desde: $fechaInicio${cronico ? ' (Crónico)' : ''}'),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitosSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hábitos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            ..._habitos.map((habito) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_getHabitoIcon(habito['nombreHabito']), color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habito['nombreHabito'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (habito['observacion'] != null)
                          Text(
                            habito['observacion'],
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  IconData _getHabitoIcon(String? nombre) {
    if (nombre == null) return Icons.info;
    if (nombre.toLowerCase().contains('tabaco') || nombre.toLowerCase().contains('fumar')) {
      return Icons.smoking_rooms;
    }
    if (nombre.toLowerCase().contains('alcohol')) {
      return Icons.local_bar;
    }
    if (nombre.toLowerCase().contains('ejercicio') || nombre.toLowerCase().contains('deporte')) {
      return Icons.fitness_center;
    }
    if (nombre.toLowerCase().contains('dieta') || nombre.toLowerCase().contains('alimenta')) {
      return Icons.restaurant;
    }
    if (nombre.toLowerCase().contains('café') || nombre.toLowerCase().contains('cafeína')) {
      return Icons.coffee;
    }
    return Icons.assignment;
  }

  Widget _buildAlergiasSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alergias',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            ..._alergias.map((alergia) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.red[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alergia['nombreAlergia'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red[900]),
                        ),
                        if (alergia['observacion'] != null)
                          Text(
                            alergia['observacion'],
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        if (alergia['fechaRegistro'] != null)
                          Text(
                            'Registrada: ${alergia['fechaRegistro']}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildVacunasSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vacunas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            ..._vacunas.map((vacuna) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.vaccines, color: Colors.green[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vacuna['nombreVacuna'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (vacuna['dosis'] != null)
                          Text(
                            vacuna['dosis'],
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        if (vacuna['fecha'] != null)
                          Text(
                            'Fecha: ${vacuna['fecha']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        if (vacuna['observacion'] != null)
                          Text(
                            vacuna['observacion'],
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildExamenesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exámenes Médicos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            ..._examenes.map((examen) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          examen['nombreExamen'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue[900]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (examen['tipoExamen'] != null)
                    Text(
                      'Tipo: ${examen['tipoExamen']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  if (examen['fecha'] != null)
                    Text(
                      'Fecha: ${examen['fecha']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  if (examen['valorReferencia'] != null)
                    Text(
                      'Valor referencia: ${examen['valorReferencia']}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  if (examen['observacion'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        examen['observacion'],
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  // botones de accion si tiene archivo
                  if (examen['archivoNombre'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ArchivoExamenViewer(
                                    idExamen: examen['idExamen'],
                                    idConsulta: examen['idConsulta'],
                                    nombreExamen: examen['nombreExamen'] ?? 'Examen',
                                    archivoTipo: examen['archivoTipo'],
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('Ver', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.attach_file, size: 14, color: Colors.green[700]),
                              const SizedBox(width: 4),
                              Text(
                                _formatFileSize(examen['archivoSize']),
                                style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(dynamic bytes) {
    if (bytes == null) return '';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }
}

