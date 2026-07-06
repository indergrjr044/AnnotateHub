
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/document.dart';
import '../models/annotation.dart';

class ApiService {
  static const String defaultBaseUrl = 'http://localhost:5000';
  String baseUrl = defaultBaseUrl;

  String? _token;
  User? _currentUser;

  ApiService() {
    _loadAuthData();
  }

  void setBaseUrl(String url) {
    baseUrl = url;
  }

  String? get token => _token;
  User? get currentUser => _currentUser;

  Future<void> _loadAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userJson = prefs.getString('current_user');
    if (userJson != null) {
      _currentUser = User.fromJson(jsonDecode(userJson));
    }
  }

  Future<void> _saveAuthData(String token, User user) async {
    _token = token;
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('current_user', jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('current_user');
  }

  Map<String, String> _getHeaders({String? socketId}) {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    if (socketId != null) {
      headers['X-Socket-ID'] = socketId;
    }
    return headers;
  }

  Future<List<User>> fetchUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/api/auth/users'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load users: ${response.body}');
    }
  }

  Future<User> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final user = User.fromJson(data['user']);
      await _saveAuthData(data['token'], user);
      return user;
    } else {
      try {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Login failed');
      } catch (_) {
        throw Exception('Login failed: ${response.body}');
      }
    }
  }

  Future<User> signUp(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final user = User.fromJson(data['user']);
      await _saveAuthData(data['token'], user);
      return user;
    } else {
      try {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Sign up failed');
      } catch (_) {
        throw Exception('Sign up failed: ${response.body}');
      }
    }
  }

  Future<void> deleteDocument(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/documents/$id'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to delete document');
      } catch (_) {
        throw Exception('Failed to delete document');
      }
    }
  }

  Future<List<Document>> fetchDocuments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/documents'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Document.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch documents: ${response.body}');
    }
  }

  Future<Document> fetchDocumentDetail(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/documents/$id'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return Document.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch document: ${response.body}');
    }
  }

  Future<Document> uploadDocument(String title, List<int> bytes, String filename) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/documents/upload'),
    );

    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.fields['title'] = title;
    final mimeType = filename.toLowerCase().endsWith('.pdf')
        ? MediaType('application', 'pdf')
        : MediaType('text', 'plain');

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: mimeType,
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return Document.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to upload document: ${response.body}');
    }
  }

  Future<List<Annotation>> fetchAnnotations(String documentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/documents/$documentId/annotations'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> list = data['annotations'] ?? [];
      return list.map((json) => Annotation.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch annotations: ${response.body}');
    }
  }

  Future<Annotation> createAnnotation({
    required String documentId,
    required int startOffset,
    required int endOffset,
    required String selectedText,
    required String comment,
    int? pageNumber,
    String? socketId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/documents/$documentId/annotations'),
      headers: _getHeaders(socketId: socketId),
      body: jsonEncode({
        'startOffset': startOffset,
        'endOffset': endOffset,
        'selectedText': selectedText,
        'comment': comment,
        'pageNumber': pageNumber,
      }),
    );

    if (response.statusCode == 201) {
      return Annotation.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create annotation: ${response.body}');
    }
  }

  Future<Annotation> updateAnnotation(
    String annotationId,
    String comment, {
    String? socketId,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/annotations/$annotationId'),
      headers: _getHeaders(socketId: socketId),
      body: jsonEncode({'comment': comment}),
    );

    if (response.statusCode == 200) {
      return Annotation.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update annotation: ${response.body}');
    }
  }

  Future<void> deleteAnnotation(
    String annotationId, {
    String? socketId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/annotations/$annotationId'),
      headers: _getHeaders(socketId: socketId),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete annotation: ${response.body}');
    }
  }
}
