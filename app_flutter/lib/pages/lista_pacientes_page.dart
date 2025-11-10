import 'package:flutter/material.dart';
import 'package:app_flutter/core/services/pacientes_service.dart';
import 'package:app_flutter/core/models/paciente.dart';
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
    _pacientesService.dispose();
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
        _previsionOptions = ['Todos', ...prevs.toList()];
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
    
    // Normalizar el valor del sexo - usar el método del modelo
    String sexoSeleccionado = Paciente.normalizarSexo(paciente.sexo);

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
                    value: sexoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Sexo *',
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'masculino', child: Text('Masculino')),
                      DropdownMenuItem(value: 'femenino', child: Text('Femenino')),
                      DropdownMenuItem(value: 'otro', child: Text('Otro')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          sexoSeleccionado = value;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Seleccione un sexo';
                      }
                      return null;
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
          nombrePaciente: nombreController.text.trim(),
          fechaNacimiento: fechaNacimiento,
          sexo: sexoSeleccionado,
          correo: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
          telefono: telefonoController.text.trim().isEmpty ? null : telefonoController.text.trim(),
          direccion: direccionController.text.trim().isEmpty ? null : direccionController.text.trim(),
          nacionalidad: nacionalidadController.text.trim().isEmpty ? null : nacionalidadController.text.trim(),
          ocupacion: ocupacionController.text.trim().isEmpty ? null : ocupacionController.text.trim(),
          prevision: previsionController.text.trim().isEmpty ? null : previsionController.text.trim(),
          tipoSangre: tipoSangreController.text.trim().isEmpty ? null : tipoSangreController.text.trim(),
        );

        print('>>> Enviando actualización para paciente ID: ${paciente.idPaciente}');
        print('>>> Sexo a enviar: $sexoSeleccionado');
        
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
      } catch (e, stackTrace) {
        print('>>> Error al actualizar paciente: $e');
        print('>>> Stack trace: $stackTrace');
        
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
                              Chip(label: Text(paciente.sexoDisplay, style: const TextStyle(fontSize: 12))),
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
      appBar: AppBar(
        title: const Text('Lista de Pacientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _cargarPacientes,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Crear paciente',
            onPressed: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando pacientes...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error al cargar pacientes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _cargarPacientes,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
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
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay pacientes registrados',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Crea tu primer paciente usando el botón +',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/profile'),
              icon: const Icon(Icons.add),
              label: const Text('Crear Paciente'),
            ),
          ],
        ),
      );
    }

    // Build search + filtered list
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por ID, nombre o email',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedPrevision,
                items: _previsionOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedPrevision = v;
                    _applyFilter();
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarPacientes,
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _filteredPacientes.length,
              itemBuilder: (context, index) {
                final paciente = _filteredPacientes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: paciente.sexo == 'masculino' ? Colors.blue[300] : Colors.pink[300],
                      child: Text(
                        paciente.nombrePaciente[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(paciente.nombrePaciente, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${paciente.idPaciente}'),
                        Text('Nacimiento: ${paciente.fechaNacimientoFormatted}'),
                        if (paciente.correo != null) Text('📧 ${paciente.correo}'),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'ver',
                          child: Row(children: [Icon(Icons.visibility, size: 20), SizedBox(width: 8), Text('Ver detalle')]),
                        ),
                        const PopupMenuItem(
                          value: 'ficha',
                          child: Row(children: [Icon(Icons.medical_information, size: 20, color: Colors.blue), SizedBox(width: 8), Text('Ficha médica', style: TextStyle(color: Colors.blue))]),
                        ),
                        const PopupMenuItem(
                          value: 'editar',
                          child: Row(children: [Icon(Icons.edit, size: 20, color: Colors.orange), SizedBox(width: 8), Text('Editar', style: TextStyle(color: Colors.orange))]),
                        ),
                        const PopupMenuItem(
                          value: 'eliminar',
                          child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))]),
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
                    onTap: () => Navigator.of(context).pushNamed('/ficha-medica/${paciente.idPaciente}'),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}