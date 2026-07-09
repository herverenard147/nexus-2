import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/prediction.dart';
import '../models/segment.dart';
import '../models/weather_alert.dart';

const String _kProdUrl = 'https://cityflow-backend-vhz5.onrender.com';
const String _kDevUrl = 'http://10.0.2.2:8000';
const _storage = FlutterSecureStorage();
const _keyAccess = 'cf_access';
const _keyRefresh = 'cf_refresh';

class ApiService {
  final String baseUrl;
  String? _accessToken;
  String? _refreshToken;

  ApiService({String? baseUrl})
      : baseUrl = baseUrl ?? (kIsWeb ? _kProdUrl : _kDevUrl);

  bool get isAuthenticated => _accessToken != null;

  void setToken(String token) => _accessToken = token;
  void clearToken() {
    _accessToken = null;
    _refreshToken = null;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<void> restoreSession() async {
    _accessToken = await _storage.read(key: _keyAccess);
    _refreshToken = await _storage.read(key: _keyRefresh);
    if (_accessToken != null && _refreshToken != null) {
      final ok = await _tryRefresh();
      if (!ok) await logout();
    }
  }

  Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refreshToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _accessToken = data['access'] as String;
        await _storage.write(key: _keyAccess, value: _accessToken);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _accessToken = data['access'] as String;
      _refreshToken = data['refresh'] as String?;
      await _storage.write(key: _keyAccess, value: _accessToken);
      if (_refreshToken != null) {
        await _storage.write(key: _keyRefresh, value: _refreshToken);
      }
      return data;
    }
    throw ApiException(res.statusCode, 'Identifiants incorrects');
  }

  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(res.statusCode, _parseError(res.body));
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
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
    if (res.statusCode == 200) {
      return Prediction.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiException(res.statusCode, 'Prédiction introuvable');
  }

  Future<RoadSegment> getSegment(int id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/segments/$id/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return RoadSegment.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
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

  Future<List<Map<String, dynamic>>> getReports({String? statut}) async {
    final uri = Uri.parse('$baseUrl/api/reports/').replace(
      queryParameters: {'statut': statut},
    );
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    throw ApiException(res.statusCode, 'Erreur chargement signalements');
  }

  Future<List<Map<String, dynamic>>> getDashboardCriticalZones() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/dashboard/critical-zones/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    throw ApiException(res.statusCode, 'Erreur dashboard');
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/dashboard/stats/'),
      headers: _headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(res.statusCode, 'Erreur stats');
  }

  Future<String> downloadCsvExport() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/dashboard/export/'),
      headers: _headers,
    );
    if (res.statusCode == 200) return res.body;
    throw ApiException(res.statusCode, 'Erreur export CSV');
  }

  String? get accessToken => _accessToken;

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
