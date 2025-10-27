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
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _sseSubscription;

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
    _conectarSSE();
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
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
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

  void _verDetallePaciente(Paciente paciente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(paciente.nombrePaciente),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetalleRow('ID', paciente.idPaciente.toString()),
              _buildDetalleRow('Fecha Nacimiento', paciente.fechaNacimientoFormatted),
              _buildDetalleRow('Sexo', paciente.sexo),
              if (paciente.correo != null)
                _buildDetalleRow('Correo', paciente.correo!),
              if (paciente.telefono != null)
                _buildDetalleRow('Teléfono', paciente.telefono!),
              if (paciente.direccion != null)
                _buildDetalleRow('Dirección', paciente.direccion!),
              if (paciente.nacionalidad != null)
                _buildDetalleRow('Nacionalidad', paciente.nacionalidad!),
              if (paciente.ocupacion != null)
                _buildDetalleRow('Ocupación', paciente.ocupacion!),
              if (paciente.prevision != null)
                _buildDetalleRow('Previsión', paciente.prevision!),
              if (paciente.tipoSangre != null)
                _buildDetalleRow('Tipo Sangre', paciente.tipoSangre!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
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

    return RefreshIndicator(
      onRefresh: _cargarPacientes,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _pacientes.length,
        itemBuilder: (context, index) {
          final paciente = _pacientes[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: paciente.sexo == 'masculino' 
                    ? Colors.blue[300] 
                    : Colors.pink[300],
                child: Text(
                  paciente.nombrePaciente[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                paciente.nombrePaciente,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${paciente.idPaciente}'),
                  Text('Nacimiento: ${paciente.fechaNacimientoFormatted}'),
                  if (paciente.correo != null)
                    Text('📧 ${paciente.correo}'),
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'ver',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 20),
                        SizedBox(width: 8),
                        Text('Ver detalle'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'eliminar',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'ver') {
                    _verDetallePaciente(paciente);
                  } else if (value == 'eliminar') {
                    _eliminarPaciente(paciente);
                  }
                },
              ),
              onTap: () => _verDetallePaciente(paciente),
            ),
          );
        },
      ),
    );
  }
}
