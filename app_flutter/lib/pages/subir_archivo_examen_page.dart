import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:app_flutter/core/models/paciente.dart';
import 'package:app_flutter/core/services/pacientes_service.dart';

class SubirArchivoExamenPage extends StatefulWidget {
  final int? idPacientePreseleccionado;
  final String? nombrePacientePreseleccionado;

  const SubirArchivoExamenPage({
    super.key,
    this.idPacientePreseleccionado,
    this.nombrePacientePreseleccionado,
  });

  @override
  State<SubirArchivoExamenPage> createState() => _SubirArchivoExamenPageState();
}

class _SubirArchivoExamenPageState extends State<SubirArchivoExamenPage> {
  final PacientesService _pacientesService = PacientesService();
  final _formKey = GlobalKey<FormState>();
  
  List<Paciente> _pacientes = [];
  List<Map<String, dynamic>> _tiposExamenes = [];
  
  int? _pacienteSeleccionado;
  int? _examenSeleccionado;
  String? _observacion;
  PlatformFile? _archivoSeleccionado;
  
  bool _isLoading = true;
  bool _subiendo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pacienteSeleccionado = widget.idPacientePreseleccionado;
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pacientes = await _pacientesService.getPacientes();
      
      // Obtener tipos de exámenes (simulado, en realidad deberías tener un endpoint)
      final tiposExamenes = [
        {'id': 1, 'nombre': 'Hemograma completo'},
        {'id': 2, 'nombre': 'Glicemia en ayunas'},
        {'id': 3, 'nombre': 'Perfil lipídico'},
        {'id': 4, 'nombre': 'Creatinina'},
        {'id': 5, 'nombre': 'Urea'},
        {'id': 6, 'nombre': 'Transaminasas (GOT/GPT)'},
        {'id': 7, 'nombre': 'TSH'},
        {'id': 8, 'nombre': 'Orina completa'},
        {'id': 9, 'nombre': 'Radiografía de tórax'},
        {'id': 10, 'nombre': 'Electrocardiograma'},
      ];

      setState(() {
        _pacientes = pacientes;
        _tiposExamenes = tiposExamenes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando datos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _seleccionarArchivo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _archivoSeleccionado = result.files.first;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error seleccionando archivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _subirArchivo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_archivoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un archivo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _formKey.currentState!.save();

    setState(() => _subiendo = true);

    try {
      final dio = Dio();
      
      FormData formData = FormData.fromMap({
        'idPaciente': _pacienteSeleccionado,
        'idExamen': _examenSeleccionado,
        'observacion': _observacion ?? '',
        'archivo': await MultipartFile.fromFile(
          _archivoSeleccionado!.path!,
          filename: _archivoSeleccionado!.name,
        ),
      });

      final response = await dio.post(
        'http://localhost:3001/api/examenes/upload',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      setState(() => _subiendo = false);

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Archivo subido exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Retornar true para indicar éxito
      }
    } catch (e) {
      setState(() => _subiendo = false);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error subiendo archivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir Examen Médico'),
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
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargarDatos,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Seleccionar paciente
                        if (widget.idPacientePreseleccionado == null)
                          DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              labelText: 'Paciente',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            value: _pacienteSeleccionado,
                            items: _pacientes.map((paciente) {
                              return DropdownMenuItem<int>(
                                value: paciente.idPaciente,
                                child: Text(paciente.nombrePaciente),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _pacienteSeleccionado = value);
                            },
                            validator: (value) =>
                                value == null ? 'Seleccione un paciente' : null,
                          )
                        else
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.person, color: Colors.teal),
                              title: Text(widget.nombrePacientePreseleccionado!),
                              subtitle: const Text('Paciente seleccionado'),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Seleccionar tipo de examen
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Tipo de Examen',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.science),
                          ),
                          value: _examenSeleccionado,
                          items: _tiposExamenes.map((examen) {
                            return DropdownMenuItem<int>(
                              value: examen['id'],
                              child: Text(examen['nombre']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _examenSeleccionado = value);
                          },
                          validator: (value) =>
                              value == null ? 'Seleccione un tipo de examen' : null,
                        ),
                        const SizedBox(height: 16),

                        // Observaciones
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Observaciones (opcional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.note),
                          ),
                          maxLines: 3,
                          onSaved: (value) => _observacion = value,
                        ),
                        const SizedBox(height: 16),

                        // Seleccionar archivo
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Archivo',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 12),
                                if (_archivoSeleccionado == null)
                                  ElevatedButton.icon(
                                    onPressed: _seleccionarArchivo,
                                    icon: const Icon(Icons.attach_file),
                                    label: const Text('Seleccionar archivo (PDF o imagen)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 48),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green[300]!),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _archivoSeleccionado!.extension == 'pdf'
                                              ? Icons.picture_as_pdf
                                              : Icons.image,
                                          color: Colors.green[700],
                                          size: 32,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _archivoSeleccionado!.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                _formatFileSize(_archivoSeleccionado!.size),
                                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            setState(() => _archivoSeleccionado = null);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Botón de subir
                        ElevatedButton.icon(
                          onPressed: _subiendo ? null : _subirArchivo,
                          icon: _subiendo
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: Text(_subiendo ? 'Subiendo...' : 'Subir Examen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 54),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
