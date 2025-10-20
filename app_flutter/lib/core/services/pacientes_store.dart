import 'dart:async';

import 'pacientes_service.dart';
import '../models/paciente.dart';

/// Store/singleton that expone la lista de pacientes como un Stream
/// y provee métodos para refrescar/crear/actualizar/eliminar que
/// automáticamente actualizan el stream.
class PacientesStore {
  final PacientesService _service = PacientesService();

  final StreamController<List<Paciente>> _controller = StreamController.broadcast();
  Timer? _timer;

  List<Paciente> _current = [];

  PacientesStore._internal();
  static final PacientesStore instance = PacientesStore._internal();

  Stream<List<Paciente>> get stream => _controller.stream;

  /// Fuerza una carga desde el servidor y emite el resultado.
  Future<void> refresh() async {
    try {
      final pacientes = await _service.getPacientes();
      _current = pacientes;
      if (!_controller.isClosed) _controller.add(_current);
    } catch (e) {
      if (!_controller.isClosed) _controller.addError(e);
    }
  }

  /// Inicia polling periódico. Llamar a [stopAutoRefresh] para detener.
  void startAutoRefresh({Duration interval = const Duration(seconds: 10)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  void stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> eliminarPaciente(int id) async {
    await _service.eliminarPaciente(id);
    await refresh();
  }

  Future<Paciente> createPaciente(Paciente paciente) async {
    final created = await _service.createPaciente(paciente);
    await refresh();
    return created;
  }

  Future<Paciente> actualizarPaciente(int id, Paciente paciente) async {
    final updated = await _service.actualizarPaciente(id, paciente);
    await refresh();
    return updated;
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
