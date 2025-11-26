// lib/core/services/api_service.dart

import 'package:dio/dio.dart';
import '../config/environment.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: Environment.apiBaseUrl,
      connectTimeout: Duration(seconds: Environment.timeoutSeconds),
      receiveTimeout: Duration(seconds: Environment.timeoutSeconds),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // log de requests
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  // GET
  Future<Response> get(String endpoint) async {
    try {
      return await _dio.get(endpoint);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // POST
  Future<Response> post(String endpoint, Map<String, dynamic> data) async {
    try {
      return await _dio.post(endpoint, data: data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // PUT
  Future<Response> put(String endpoint, Map<String, dynamic> data) async {
    try {
      return await _dio.put(endpoint, data: data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // DELETE
  Future<Response> delete(String endpoint) async {
    try {
      return await _dio.delete(endpoint);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Manejo de errores
  Exception _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return Exception('Timeout: el sv no responde');
        case DioExceptionType.receiveTimeout:
          return Exception('Timeout al recibir datos');
        case DioExceptionType.badResponse:
          return Exception('Error ${error.response?.statusCode}: ${error.response?.data}');
        default:
          return Exception('Error de conexion');
      }
    }
    return Exception('Error desconocido: $error');
  }

}