import 'package:dio/dio.dart';
import '../models/post.dart';
import 'api_service.dart';

class PostsService {
  final ApiService _api = ApiService();

  /// Obtiene posts desde JSONPlaceholder (ejemplo de API pública)
  Future<List<Post>> getPosts() async {
    try {
      // Usamos URL absoluta para no tocar Environment.apiBaseUrl
      final Response response = await _api.get('https://jsonplaceholder.typicode.com/posts');
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }
}
