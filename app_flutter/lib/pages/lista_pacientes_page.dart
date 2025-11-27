import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:app_flutter/core/services/pacientes_service.dart';
import 'package:app_flutter/core/models/paciente.dart';
import 'package:app_flutter/pages/subir_archivo_examen_page.dart';
import 'package:app_flutter/core/config/app_theme.dart';
import 'dart:async';

class ListaPacientesPage extends StatefulWidget {
  const ListaPacientesPage({super.key});

  @override
  State<ListaPacientesPage> createState() => _ListaPacientesPageState();
}

class _ListaPacientesPageState extends State<ListaPacientesPage> {
  final PacientesService _pacientesService = PacientesService();
  List<Paciente> _pacientes = [];
  List<Paciente> _filteredPacientes = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedPrevision = 'Todos';
  List<String> _previsionOptions = ['Todos'];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _sseSubscription;

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
    _conectarSSE();
    _searchController.addListener(() {
      _applyFilter();
    });
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    // NO cerrar el servicio SSE - mantenerlo vivo para toda la app
    // _pacientesService.dispose();
    super.dispose();
  }

  // conectar a eventos sse del servidor
  void _conectarSSE() {
    print('>>> iniciando conexion sse desde lista pacientes');
    _pacientesService.connectToSSE();
    
    _sseSubscription = _pacientesService.sseStream.listen((evento) {
      print('>>> evento sse recibido en lista: ${evento['event']}');
      print('>>> datos del evento: ${evento['data']}');
      
      final eventType = evento['event'] as String;
      final data = evento['data'];

      switch (eventType) {
        case 'paciente_creado':
          _manejarPacienteCreado(data);
          break;
        case 'paciente_actualizado':
          _manejarPacienteActualizado(data);
          break;
        case 'paciente_eliminado':
          _manejarPacienteEliminado(data);
          break;
        default:
          print('evento desconocido: $eventType');
      }
    });
    
    print('>>> suscripcion al stream sse configurada');
  }

  void _manejarPacienteCreado(dynamic data) {
    print('nuevo paciente: $data');
    _cargarPacientes();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nuevo paciente: ${data['nombrePaciente'] ?? 'sin nombre'}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _manejarPacienteActualizado(dynamic data) {
    print('paciente actualizado: $data');
    _cargarPacientes();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paciente actualizado: ${data['nombrePaciente'] ?? 'sin nombre'}'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _manejarPacienteEliminado(dynamic data) {
    print('paciente eliminado: $data');
    _cargarPacientes();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paciente eliminado (ID: ${data['idPaciente']})'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _cargarPacientes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pacientes = await _pacientesService.getPacientes();
      setState(() {
        _pacientes = pacientes;
        _filteredPacientes = List.from(_pacientes);
        // build prevision options
        final prevs = <String>{};
        for (var p in _pacientes) {
          if (p.prevision != null && p.prevision!.isNotEmpty) prevs.add(p.prevision!);
        }
        _previsionOptions = ['Todos', ...prevs];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredPacientes = _pacientes.where((p) {
        if (_selectedPrevision != 'Todos') {
          if ((p.prevision ?? '') != _selectedPrevision) return false;
        }
        if (q.isEmpty) return true;
        final asInt = int.tryParse(q);
        if (asInt != null) return p.idPaciente == asInt;
        return p.nombrePaciente.toLowerCase().contains(q) || (p.correo ?? '').toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _eliminarPaciente(Paciente paciente) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar a ${paciente.nombrePaciente}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && paciente.idPaciente != null) {
      try {
        await _pacientesService.eliminarPaciente(paciente.idPaciente!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Paciente eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          _cargarPacientes(); // Recargar lista
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editarPaciente(Paciente paciente) async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: paciente.nombrePaciente);
    final emailController = TextEditingController(text: paciente.correo ?? '');
    final telefonoController = TextEditingController(text: paciente.telefono ?? '');
    final direccionController = TextEditingController(text: paciente.direccion ?? '');
    final nacionalidadController = TextEditingController(text: paciente.nacionalidad ?? '');
    final ocupacionController = TextEditingController(text: paciente.ocupacion ?? '');
    final previsionController = TextEditingController(text: paciente.prevision ?? '');
    final tipoSangreController = TextEditingController(text: paciente.tipoSangre ?? '');
    
    DateTime fechaNacimiento = paciente.fechaNacimiento;
    
    // Normalizar el valor del sexo para que coincida con el dropdown
    String sexoSeleccionado = paciente.sexo.toUpperCase();
    if (sexoSeleccionado != 'M' && sexoSeleccionado != 'F' && sexoSeleccionado != 'O') {
      // Si el valor en BD es "masculino", "femenino", etc., convertir a M/F/O
      if (paciente.sexo.toLowerCase().contains('masc')) {
        sexoSeleccionado = 'M';
      } else if (paciente.sexo.toLowerCase().contains('fem')) {
        sexoSeleccionado = 'F';
      } else {
        sexoSeleccionado = 'O';
      }
    }

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar Paciente'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Campo requerido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cake),
                    title: const Text('Fecha de Nacimiento'),
                    subtitle: Text('${fechaNacimiento.day}/${fechaNacimiento.month}/${fechaNacimiento.year}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final fecha = await showDatePicker(
                          context: context,
                          initialDate: fechaNacimiento,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (fecha != null) {
                          setState(() {
                            fechaNacimiento = fecha;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: sexoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Sexo *',
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'M', child: Text('Masculino')),
                      DropdownMenuItem(value: 'F', child: Text('Femenino')),
                      DropdownMenuItem(value: 'O', child: Text('Otro')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          sexoSeleccionado = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telefonoController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: direccionController,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nacionalidadController,
                    decoration: const InputDecoration(
                      labelText: 'Nacionalidad',
                      prefixIcon: Icon(Icons.flag),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: ocupacionController,
                    decoration: const InputDecoration(
                      labelText: 'Ocupación',
                      prefixIcon: Icon(Icons.work),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: previsionController,
                    decoration: const InputDecoration(
                      labelText: 'Previsión',
                      prefixIcon: Icon(Icons.health_and_safety),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: tipoSangreController,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Sangre',
                      prefixIcon: Icon(Icons.bloodtype),
                      hintText: 'Ej: O+, A-, B+',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (resultado == true && paciente.idPaciente != null) {
      try {
        final pacienteActualizado = Paciente(
          idPaciente: paciente.idPaciente,
          nombrePaciente: nombreController.text,
          fechaNacimiento: fechaNacimiento,
          sexo: sexoSeleccionado,
          correo: emailController.text.isEmpty ? null : emailController.text,
          telefono: telefonoController.text.isEmpty ? null : telefonoController.text,
          direccion: direccionController.text.isEmpty ? null : direccionController.text,
          nacionalidad: nacionalidadController.text.isEmpty ? null : nacionalidadController.text,
          ocupacion: ocupacionController.text.isEmpty ? null : ocupacionController.text,
          prevision: previsionController.text.isEmpty ? null : previsionController.text,
          tipoSangre: tipoSangreController.text.isEmpty ? null : tipoSangreController.text,
        );

        await _pacientesService.actualizarPaciente(paciente.idPaciente!, pacienteActualizado);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Paciente actualizado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          _cargarPacientes(); // Recargar lista
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al actualizar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    // Liberar controladores
    nombreController.dispose();
    emailController.dispose();
    telefonoController.dispose();
    direccionController.dispose();
    nacionalidadController.dispose();
    ocupacionController.dispose();
    previsionController.dispose();
    tipoSangreController.dispose();
  }

  void _verDetallePaciente(Paciente paciente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.teal[50],
              child: Text(
                paciente.nombrePaciente.isNotEmpty ? paciente.nombrePaciente[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 20, color: Colors.teal[700], fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paciente.nombrePaciente, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('ID: ${paciente.idPaciente ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top info card
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Nacimiento', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              Text(paciente.fechaNacimientoFormatted, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('Sexo', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              Chip(label: Text(paciente.sexo, style: const TextStyle(fontSize: 12))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Tipo sangre', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              Text(paciente.tipoSangre ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text('Previsión: ${paciente.prevision ?? 'N/D'}')),
                          Chip(label: Text('Ocupación: ${paciente.ocupacion ?? 'N/D'}')),
                          Chip(label: Text('Nacionalidad: ${paciente.nacionalidad ?? 'N/D'}')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Mini stats row
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: const [
                            Icon(Icons.calendar_today, color: Colors.blue),
                            SizedBox(height: 6),
                            Text('Última consulta', style: TextStyle(fontSize: 12, color: Colors.blue)),
                            SizedBox(height: 4),
                            Text('--', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: const [
                            Icon(Icons.receipt_long, color: Colors.green),
                            SizedBox(height: 6),
                            Text('Recetas', style: TextStyle(fontSize: 12, color: Colors.green)),
                            SizedBox(height: 4),
                            Text('--', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Medical summary placeholder
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Resumen médico', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('- Alergias: Ninguna registrada'),
                      SizedBox(height: 4),
                      Text('- Enfermedades crónicas: Ninguna registrada'),
                      SizedBox(height: 4),
                      Text('- Medicamentos actuales: Ninguno registrado'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Contact card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Contacto', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (paciente.correo != null)
                        Row(children: [const Icon(Icons.email, size: 16), const SizedBox(width: 8), Expanded(child: Text(paciente.correo!))]),
                      if (paciente.telefono != null)
                        Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [const Icon(Icons.phone, size: 16), const SizedBox(width: 8), Expanded(child: Text(paciente.telefono!))])),
                      if (paciente.direccion != null)
                        Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [const Icon(Icons.location_on, size: 16), const SizedBox(width: 8), Expanded(child: Text(paciente.direccion!))])),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _editarPaciente(paciente);
            },
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppTheme.buildAppBar(
        title: 'Lista de Pacientes',
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            tooltip: 'Recargar',
            onPressed: _cargarPacientes,
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.add),
            tooltip: 'Crear paciente',
            onPressed: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SubirArchivoExamenPage(),
            ),
          );
          if (resultado == true) {
            _cargarPacientes(); // recargar si se subio un archivo
          }
        },
        backgroundColor: AppTheme.primaryPurple,
        icon: const Icon(CupertinoIcons.arrow_up_doc),
        label: const Text('Subir Examen'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
            ),
            SizedBox(height: 16),
            Text(
              'Cargando pacientes...',
              style: TextStyle(color: AppTheme.textGrey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: AppTheme.pagePadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.exclamationmark_circle, size: 64, color: AppTheme.red),
              const SizedBox(height: 16),
              const Text(
                'Error al cargar pacientes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textGrey),
              ),
              const SizedBox(height: 24),
              AppTheme.buildPrimaryButton(
                text: 'Reintentar',
                icon: CupertinoIcons.refresh,
                onPressed: _cargarPacientes,
              ),
            ],
          ),
        ),
      );
    }

    if (_pacientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.person_2, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No hay pacientes registrados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea tu primer paciente usando el boton +',
              style: TextStyle(color: AppTheme.textGrey),
            ),
            const SizedBox(height: 24),
            AppTheme.buildPrimaryButton(
              text: 'Crear Paciente',
              icon: CupertinoIcons.add,
              onPressed: () => Navigator.of(context).pushNamed('/profile'),
            ),
          ],
        ),
      );
    }

    // Build search + filtered list
    return Column(
      children: [
        Container(
          color: AppTheme.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(CupertinoIcons.search, color: AppTheme.primaryPurple),
                  hintText: 'Buscar por ID, nombre o email',
                  filled: true,
                  fillColor: AppTheme.backgroundGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(CupertinoIcons.slider_horizontal_3, size: 20, color: AppTheme.textGrey),
                  const SizedBox(width: 8),
                  const Text('Filtrar por prevision:', style: TextStyle(color: AppTheme.textGrey)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundGrey,
                        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedPrevision,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _previsionOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _selectedPrevision = v;
                            _applyFilter();
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarPacientes,
            color: AppTheme.primaryPurple,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredPacientes.length,
              itemBuilder: (context, index) {
                final paciente = _filteredPacientes[index];
                return _buildPacienteCard(paciente);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPacienteCard(Paciente paciente) {
    Color avatarColor = AppTheme.primaryPurple;
    if (paciente.sexo.toLowerCase().contains('masc')) {
      avatarColor = AppTheme.blue;
    } else if (paciente.sexo.toLowerCase().contains('fem')) {
      avatarColor = AppTheme.pink;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/ficha-medica/${paciente.idPaciente}'),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: avatarColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    paciente.nombrePaciente.isNotEmpty 
                        ? paciente.nombrePaciente[0].toUpperCase() 
                        : '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paciente.nombrePaciente,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(CupertinoIcons.number, size: 14, color: AppTheme.textGrey),
                        const SizedBox(width: 4),
                        Text(
                          'ID: ${paciente.idPaciente}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
                        ),
                        const SizedBox(width: 12),
                        const Icon(CupertinoIcons.calendar, size: 14, color: AppTheme.textGrey),
                        const SizedBox(width: 4),
                        Text(
                          paciente.fechaNacimientoFormatted,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
                        ),
                      ],
                    ),
                    if (paciente.correo != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(CupertinoIcons.mail, size: 14, color: AppTheme.textGrey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              paciente.correo!,
                              style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (paciente.prevision != null) ...[
                      const SizedBox(height: 8),
                      AppTheme.buildChip(
                        label: paciente.prevision!,
                        color: AppTheme.blue,
                        icon: CupertinoIcons.briefcase,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(CupertinoIcons.ellipsis_vertical, color: AppTheme.textGrey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'ver',
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.eye, size: 20, color: AppTheme.primaryPurple),
                        SizedBox(width: 12),
                        Text('Ver detalle'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'ficha',
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.doc_text, size: 20, color: AppTheme.blue),
                        SizedBox(width: 12),
                        Text('Ficha medica'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.pencil, size: 20, color: AppTheme.orange),
                        SizedBox(width: 12),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'eliminar',
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.delete, size: 20, color: AppTheme.red),
                        SizedBox(width: 12),
                        Text('Eliminar'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'ver') {
                    _verDetallePaciente(paciente);
                  } else if (value == 'ficha') {
                    Navigator.of(context).pushNamed('/ficha-medica/${paciente.idPaciente}');
                  } else if (value == 'editar') {
                    _editarPaciente(paciente);
                  } else if (value == 'eliminar') {
                    _eliminarPaciente(paciente);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
