// lib/core/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'api_service.dart';
import '../models/paciente.dart';
import 'package:http/http.dart' as http;

class PacientesService {
  final ApiService _apiService = ApiService();
  late final StreamController<Map<String, dynamic>> _sseController;
  http.Client? _sseClient;
  
  PacientesService() {
    _sseController = StreamController<Map<String, dynamic>>.broadcast();
  }
  
  // stream para escuchar los eventos del servidor
  Stream<Map<String, dynamic>> get sseStream => _sseController.stream;

  // conectar al endpoint sse del backend
  void connectToSSE() async {
    final String sseUrl = 'http://localhost:3001/api/pacientes/stream';
    
    print('>>> conectando a sse: $sseUrl');

    try {
      _sseClient = http.Client();
      final request = http.Request('GET', Uri.parse(sseUrl));
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      print('>>> enviando request sse...');
      final response = await _sseClient!.send(request);
      
      print('>>> respuesta sse status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('>>> conexion sse ok, escuchando eventos...');
        
        String? currentEvent;
        
        response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (line) {
            print('>>> linea sse: $line');
            
            if (line.startsWith('event:')) {
              currentEvent = line.substring(6).trim();
              print('>>> tipo evento: $currentEvent');
            } else if (line.startsWith('data:')) {
              final jsonData = line.substring(5).trim();
              print('>>> data json: $jsonData');
              try {
                final data = jsonDecode(jsonData);
                print('>>> agregando al stream: event=$currentEvent, data=$data');
                _sseController.add({
                  'event': currentEvent ?? 'message',
                  'data': data,
                });
                currentEvent = null;
              } catch (e) {
                print('>>> error parseando data: $e');
              }
            }
          },
          onError: (error) {
            print('>>> error en sse stream: $error');
          },
          onDone: () {
            print('>>> conexion sse cerrada por servidor');
          },
        );
      } else {
        print('>>> error status code: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('>>> excepcion en sse: $e');
      print('>>> stack: $stackTrace');
    }
  }

  // cerrar conexion sse
  void dispose() {
    _sseController.close();
    _sseClient?.close();
  }

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