import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:app_flutter/core/models/paciente.dart';
import 'package:app_flutter/core/services/pacientes_service.dart';
import 'package:app_flutter/core/config/app_theme.dart';
import 'package:app_flutter/core/config/environment.dart';

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
  final TextEditingController _searchController = TextEditingController();
  
  List<Paciente> _pacientes = [];
  List<Paciente> _pacientesFiltrados = [];
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
    _searchController.addListener(_filtrarPacientes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarPacientes() {
    final query = _searchController.text.trim().toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _pacientesFiltrados = List.from(_pacientes);
      } else {
        _pacientesFiltrados = _pacientes.where((paciente) {
          // buscar por id
          final idStr = paciente.idPaciente?.toString() ?? '';
          if (idStr.contains(query)) return true;
          
          // buscar por nombre
          if (paciente.nombrePaciente.toLowerCase().contains(query)) return true;
          
          return false;
        }).toList();
      }
    });
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pacientes = await _pacientesService.getPacientes();
      
      // tipos de examenes hardcodeados
      final tiposExamenes = [
        {'id': 1, 'nombre': 'Hemograma completo'},
        {'id': 2, 'nombre': 'Glicemia en ayunas'},
        {'id': 3, 'nombre': 'Perfil lipidico'},
        {'id': 4, 'nombre': 'Creatinina'},
        {'id': 5, 'nombre': 'Urea'},
        {'id': 6, 'nombre': 'Transaminasas (GOT/GPT)'},
        {'id': 7, 'nombre': 'TSH'},
        {'id': 8, 'nombre': 'Orina completa'},
        {'id': 9, 'nombre': 'Radiografia de torax'},
        {'id': 10, 'nombre': 'Electrocardiograma'},
      ];

      setState(() {
        _pacientes = pacientes;
        _pacientesFiltrados = pacientes;
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
        '${Environment.apiBaseUrl}/examenes/upload',
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
        Navigator.pop(context, true); // retornar true para indicar exito
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
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppTheme.buildAppBar(
        title: 'Subir Examen Medico',
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
                      Text(_error!, style: const TextStyle(color: AppTheme.red)),
                      const SizedBox(height: 16),
                      AppTheme.buildPrimaryButton(
                        text: 'Reintentar',
                        icon: CupertinoIcons.refresh,
                        onPressed: _cargarDatos,
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
                        // Seleccionar paciente con busqueda
                        if (widget.idPacientePreseleccionado == null) ...[
                          AppTheme.buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppTheme.buildSectionHeader(
                                  title: 'Seleccionar Paciente',
                                  icon: CupertinoIcons.person_fill,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _searchController,
                                  decoration: AppTheme.buildInputDecoration(
                                    label: 'Buscar por ID o nombre',
                                    hint: 'Ej: 123 o Juan Perez',
                                    prefixIcon: CupertinoIcons.search,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 300),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppTheme.textLight.withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                                  ),
                                  child: _pacientesFiltrados.isEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Center(
                                            child: Text(
                                              _searchController.text.isEmpty
                                                  ? 'No hay pacientes registrados'
                                                  : 'No se encontraron pacientes',
                                              style: const TextStyle(color: AppTheme.textGrey),
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          shrinkWrap: true,
                                          itemCount: _pacientesFiltrados.length,
                                          separatorBuilder: (context, index) => const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final paciente = _pacientesFiltrados[index];
                                            final isSelected = _pacienteSeleccionado == paciente.idPaciente;
                                            
                                            return ListTile(
                                              selected: isSelected,
                                              selectedTileColor: AppTheme.primaryPurple.withOpacity(0.1),
                                              leading: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: isSelected 
                                                      ? AppTheme.primaryPurple.withOpacity(0.2)
                                                      : AppTheme.blue.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    paciente.nombrePaciente.isNotEmpty
                                                        ? paciente.nombrePaciente[0].toUpperCase()
                                                        : '?',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: isSelected ? AppTheme.primaryPurple : AppTheme.blue,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              title: Text(
                                                paciente.nombrePaciente,
                                                style: TextStyle(
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                              subtitle: Text('ID: ${paciente.idPaciente}'),
                                              trailing: isSelected
                                                  ? const Icon(CupertinoIcons.checkmark_circle_fill, color: AppTheme.primaryPurple)
                                                  : null,
                                              onTap: () {
                                                setState(() => _pacienteSeleccionado = paciente.idPaciente);
                                              },
                                            );
                                          },
                                        ),
                                ),
                                if (_pacienteSeleccionado == null) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Debe seleccionar un paciente',
                                    style: TextStyle(color: AppTheme.red, fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ] else
                          AppTheme.buildCard(
                            child: ListTile(
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(CupertinoIcons.person_fill, color: AppTheme.primaryPurple),
                              ),
                              title: Text(
                                widget.nombrePacientePreseleccionado!,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text('Paciente seleccionado'),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Seleccionar tipo de examen
                        AppTheme.buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppTheme.buildSectionHeader(
                                title: 'Tipo de Examen',
                                icon: CupertinoIcons.lab_flask_solid,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                decoration: AppTheme.buildInputDecoration(
                                  label: 'Seleccione el tipo de examen',
                                  prefixIcon: CupertinoIcons.list_bullet,
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Observaciones
                        AppTheme.buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppTheme.buildSectionHeader(
                                title: 'Observaciones',
                                icon: CupertinoIcons.text_alignleft,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                decoration: AppTheme.buildInputDecoration(
                                  label: 'Observaciones (opcional)',
                                  hint: 'Agregue notas o comentarios sobre el examen',
                                  prefixIcon: CupertinoIcons.pencil,
                                ),
                                maxLines: 3,
                                onSaved: (value) => _observacion = value,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Seleccionar archivo
                        AppTheme.buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppTheme.buildSectionHeader(
                                title: 'Archivo del Examen',
                                icon: CupertinoIcons.doc_fill,
                              ),
                              const SizedBox(height: 12),
                              if (_archivoSeleccionado == null)
                                AppTheme.buildPrimaryButton(
                                  text: 'Seleccionar archivo (PDF o imagen)',
                                  icon: CupertinoIcons.paperclip,
                                  onPressed: _seleccionarArchivo,
                                  color: AppTheme.blue,
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                                    border: Border.all(color: AppTheme.green),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _archivoSeleccionado!.extension == 'pdf'
                                            ? CupertinoIcons.doc_fill
                                            : CupertinoIcons.photo_fill,
                                        color: AppTheme.green,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _archivoSeleccionado!.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textDark,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatFileSize(_archivoSeleccionado!.size),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppTheme.red),
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
                        const SizedBox(height: 24),

                        // boton de subir
                        AppTheme.buildPrimaryButton(
                          text: _subiendo ? 'Subiendo...' : 'Subir Examen',
                          icon: CupertinoIcons.cloud_upload_fill,
                          onPressed: _pacienteSeleccionado == null ? () {} : _subirArchivo,
                          isLoading: _subiendo,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
