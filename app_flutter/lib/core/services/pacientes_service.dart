// lib/core/services/api_service.dart

import 'api_service.dart';
import '../models/paciente.dart';

class PacientesService {
  final ApiService _apiService = ApiService();

  // GET /api/pacientes - (obtener todos)
  Future<List<Paciente>> getPacientes() async {
    final response = await _apiService.get('/pacientes');
    final List<dynamic> data = response.data;
    return data.map((json) => Paciente.fromJson(json)).toList();
  }

  // GET /api/pacientes/:id - (obtener por id)
  Future<Paciente> getPacienteById(int id) async {
    final response = await _apiService.get('/pacientes/$id');
    return Paciente.fromJson(response.data);
  }

  // POST /api/pacientes - (crear nvo)
  Future<Paciente> createPaciente(Paciente paciente) async {
    final response = await _apiService.post('/pacientes', paciente.toJson());
    return Paciente.fromJson(response.data);
  }

  // PUT /api/pacientes/:id - (actualizar paciente)
  Future<Paciente> actualizarPaciente(int id, Paciente paciente) async {
    final response = await _apiService.put('/pacientes/$id', paciente.toJson());
    return Paciente.fromJson(response.data);
  }

  // DELETE /api/pacientes/:id - (eliminar paciente)
  Future<void> eliminarPaciente(int id) async {
    await _apiService.delete('/pacientes/$id');
  }
}