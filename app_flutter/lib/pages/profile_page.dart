import 'package:flutter/material.dart';
import 'package:app_flutter/core/services/pacientes_service.dart';
import 'package:app_flutter/core/models/paciente.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final PacientesService _pacientesService = PacientesService();

  // Controladores de formulario
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _apellido = TextEditingController();
  final TextEditingController _fechaNacimiento = TextEditingController();
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _telefono = TextEditingController();
  final TextEditingController _direccion = TextEditingController();
  final TextEditingController _nacionalidad = TextEditingController();
  final TextEditingController _ocupacion = TextEditingController();
  final TextEditingController _prevision = TextEditingController();
  final TextEditingController _tipoSangre = TextEditingController();

  // Estado
  Paciente? _pacienteGuardado;
  bool _isLoading = false;
  String _sexoSeleccionado = 'masculino';

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _fechaNacimiento.dispose();
    _correo.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _nacionalidad.dispose();
    _ocupacion.dispose();
    _prevision.dispose();
    _tipoSangre.dispose();
    super.dispose();
  }

  /// Seleccionar fecha de nacimiento
  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    
    if (picked != null) {
      setState(() {
        _fechaNacimiento.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  /// Guardar paciente en la base de datos
  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Validar que se haya seleccionado una fecha
    if (_fechaNacimiento.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione la fecha de nacimiento'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Parsear fecha de DD/MM/YYYY a DateTime
      final partes = _fechaNacimiento.text.split('/');
      final fechaNac = DateTime(
        int.parse(partes[2]), // año
        int.parse(partes[1]), // mes
        int.parse(partes[0]), // día
      );

      // Crear objeto Paciente
      final nuevoPaciente = Paciente(
        nombrePaciente: '${_nombre.text.trim()} ${_apellido.text.trim()}',
        fechaNacimiento: fechaNac,
        correo: _correo.text.trim().isEmpty ? null : _correo.text.trim(),
        telefono: _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
        direccion: _direccion.text.trim().isEmpty ? null : _direccion.text.trim(),
        sexo: _sexoSeleccionado,
        nacionalidad: _nacionalidad.text.trim().isEmpty ? null : _nacionalidad.text.trim(),
        ocupacion: _ocupacion.text.trim().isEmpty ? null : _ocupacion.text.trim(),
        prevision: _prevision.text.trim().isEmpty ? null : _prevision.text.trim(),
        tipoSangre: _tipoSangre.text.trim().isEmpty ? null : _tipoSangre.text.trim(),
      );

      // Llamar al servicio para crear paciente
      final pacienteCreado = await _pacientesService.createPaciente(nuevoPaciente);

      setState(() {
        _pacienteGuardado = pacienteCreado;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Paciente guardado con ID: ${pacienteCreado.idPaciente}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Limpiar formulario
  void _limpiarFormulario() {
    _formKey.currentState?.reset();
    _nombre.clear();
    _apellido.clear();
    _fechaNacimiento.clear();
    _correo.clear();
    _telefono.clear();
    _direccion.clear();
    _nacionalidad.clear();
    _ocupacion.clear();
    _prevision.clear();
    _tipoSangre.clear();
    
    setState(() {
      _pacienteGuardado = null;
      _sexoSeleccionado = 'masculino';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Paciente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Ver todos los pacientes',
            onPressed: () {
              Navigator.of(context).pushNamed('/lista-pacientes');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Guardando paciente...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre
                        TextFormField(
                          controller: _nombre,
                          decoration: const InputDecoration(
                            labelText: 'Nombre *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre' : null,
                        ),
                        const SizedBox(height: 12),

                        // Apellido
                        TextFormField(
                          controller: _apellido,
                          decoration: const InputDecoration(
                            labelText: 'Apellido *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el apellido' : null,
                        ),
                        const SizedBox(height: 12),

                        // Fecha de Nacimiento
                        TextFormField(
                          controller: _fechaNacimiento,
                          decoration: const InputDecoration(
                            labelText: 'Fecha de Nacimiento *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                            hintText: 'DD/MM/AAAA',
                          ),
                          readOnly: true,
                          onTap: _seleccionarFecha,
                        ),
                        const SizedBox(height: 12),

                        // Sexo
                        const Text('Sexo *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Masculino'),
                                value: 'masculino',
                                groupValue: _sexoSeleccionado,
                                onChanged: (value) {
                                  setState(() => _sexoSeleccionado = value!);
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Femenino'),
                                value: 'femenino',
                                groupValue: _sexoSeleccionado,
                                onChanged: (value) {
                                  setState(() => _sexoSeleccionado = value!);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Correo
                        TextFormField(
                          controller: _correo,
                          decoration: const InputDecoration(
                            labelText: 'Correo Electrónico',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),

                        // Teléfono
                        TextFormField(
                          controller: _telefono,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),

                        // Dirección
                        TextFormField(
                          controller: _direccion,
                          decoration: const InputDecoration(
                            labelText: 'Dirección',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.home),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),

                        // Nacionalidad
                        TextFormField(
                          controller: _nacionalidad,
                          decoration: const InputDecoration(
                            labelText: 'Nacionalidad',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.flag),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Ocupación
                        TextFormField(
                          controller: _ocupacion,
                          decoration: const InputDecoration(
                            labelText: 'Ocupación',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.work),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Previsión
                        TextFormField(
                          controller: _prevision,
                          decoration: const InputDecoration(
                            labelText: 'Previsión (FONASA/ISAPRE)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.medical_services),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tipo de Sangre
                        TextFormField(
                          controller: _tipoSangre,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de Sangre',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.bloodtype),
                            hintText: 'Ej: O+, A-, AB+',
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Botones
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _onSave,
                                icon: const Icon(Icons.save),
                                label: const Text('Guardar en BD'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _limpiarFormulario,
                                icon: const Icon(Icons.clear),
                                label: const Text('Limpiar'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Mostrar datos guardados
                  if (_pacienteGuardado != null) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      '✅ Último paciente guardado:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('ID', _pacienteGuardado!.idPaciente.toString(), Icons.tag),
                            _buildInfoRow('Nombre', _pacienteGuardado!.nombrePaciente, Icons.person),
                            _buildInfoRow('Fecha Nac.', _pacienteGuardado!.fechaNacimientoFormatted, Icons.cake),
                            _buildInfoRow('Sexo', _pacienteGuardado!.sexo, Icons.wc),
                            if (_pacienteGuardado!.correo != null)
                              _buildInfoRow('Correo', _pacienteGuardado!.correo!, Icons.email),
                            if (_pacienteGuardado!.telefono != null)
                              _buildInfoRow('Teléfono', _pacienteGuardado!.telefono!, Icons.phone),
                            if (_pacienteGuardado!.prevision != null)
                              _buildInfoRow('Previsión', _pacienteGuardado!.prevision!, Icons.medical_services),
                            if (_pacienteGuardado!.tipoSangre != null)
                              _buildInfoRow('Tipo Sangre', _pacienteGuardado!.tipoSangre!, Icons.bloodtype),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}
