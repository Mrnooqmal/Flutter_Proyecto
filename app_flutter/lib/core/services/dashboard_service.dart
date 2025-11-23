// lib/core/services/dashboard_service.dart

import 'api_service.dart';

class DashboardService {
  final ApiService _apiService = ApiService();

  // GET /api/dashboard/stats - Estadísticas principales
  Future<Map<String, dynamic>> getEstadisticas() async {
    final response = await _apiService.get('/dashboard/stats');
    return Map<String, dynamic>.from(response.data);
  }

  // GET /api/dashboard/consultas-por-dia - Consultas por día
  Future<List<Map<String, dynamic>>> getConsultasPorDia({int dias = 30}) async {
    final response = await _apiService.get('/dashboard/consultas-por-dia?dias=$dias');
    return List<Map<String, dynamic>>.from(response.data);
  }

  // GET /api/dashboard/pacientes-por-edad - Distribución por edad
  Future<List<Map<String, dynamic>>> getPacientesPorEdad() async {
    final response = await _apiService.get('/dashboard/pacientes-por-edad');
    return List<Map<String, dynamic>>.from(response.data);
  }

  // GET /api/dashboard/top-examenes - Top 5 exámenes
  Future<List<Map<String, dynamic>>> getTopExamenes() async {
    final response = await _apiService.get('/dashboard/top-examenes');
    return List<Map<String, dynamic>>.from(response.data);
  }

  // GET /api/dashboard/top-medicamentos - Top 5 medicamentos
  Future<List<Map<String, dynamic>>> getTopMedicamentos() async {
    final response = await _apiService.get('/dashboard/top-medicamentos');
    return List<Map<String, dynamic>>.from(response.data);
  }

  // GET /api/dashboard/ultimas-consultas - Últimas 5 consultas
  Future<List<Map<String, dynamic>>> getUltimasConsultas() async {
    final response = await _apiService.get('/dashboard/ultimas-consultas');
    return List<Map<String, dynamic>>.from(response.data);
  }

  // GET /api/dashboard/alertas-signos-vitales - Alertas de signos vitales
  Future<List<Map<String, dynamic>>> getAlertasSignosVitales() async {
    final response = await _apiService.get('/dashboard/alertas-signos-vitales');
    return List<Map<String, dynamic>>.from(response.data);
  }
}
