import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prediction.dart';
import '../models/segment.dart';
import '../models/weather_alert.dart';

class ApiService {
  final String baseUrl;
  String? _accessToken;

  ApiService({this.baseUrl = 'http://10.0.2.2:8000'});

  void setToken(String token) => _accessToken = token;
  void clearToken() => _accessToken = null;
  bool get isAuthenticated => _accessToken != null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _accessToken = data['access'] as String;
      return data;
    }
    throw ApiException(res.statusCode, 'Identifiants incorrects');
  }

  Future<Map<String, dynamic>> register(
      String username, String email, String password, String role) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'role': role,
      }),
    );
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(res.statusCode, _parseError(res.body));
  }

  Future<List<Prediction>> getPredictions() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/predictions/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => Prediction.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(res.statusCode, 'Erreur chargement prédictions');
  }

  Future<Prediction> getPrediction(int segmentId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/predictions/$segmentId/'),
      headers: _headers,
    );
    if (res.statusCode == 200) return Prediction.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    throw ApiException(res.statusCode, 'Prédiction introuvable');
  }

  Future<RoadSegment> getSegment(int id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/segments/$id/'),
      headers: _headers,
    );
    if (res.statusCode == 200) return RoadSegment.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    throw ApiException(res.statusCode, 'Segment introuvable');
  }

  Future<List<WeatherAlert>> getWeatherAlerts() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/weather/alerts/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => WeatherAlert.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(res.statusCode, 'Erreur alertes météo');
  }

  Future<Map<String, dynamic>> createReport(int segmentId, String type) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/reports/'),
      headers: _headers,
      body: jsonEncode({'segment': segmentId, 'type': type}),
    );
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(res.statusCode, _parseError(res.body));
  }

  String _parseError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) return data.values.first.toString();
    } catch (_) {}
    return 'Erreur inconnue';
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
