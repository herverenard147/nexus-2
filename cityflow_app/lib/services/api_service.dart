import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/commune_stats.dart';
import '../models/prediction.dart';
import '../models/segment.dart';
import '../models/weather_alert.dart';

const String _kProdUrl = 'https://cityflow-backend-vhz5.onrender.com';
const String _kDevUrl = 'http://10.0.2.2:8000';
const _storage = FlutterSecureStorage();

// Permet de cibler un backend local en web dev :
// flutter run -d chrome --dart-define=BACKEND_URL=http://localhost:8000
const String _kEnvUrl = String.fromEnvironment('BACKEND_URL');
const _keyAccess = 'cf_access';
const _keyRefresh = 'cf_refresh';
const _keyRole = 'cf_role';

class ApiService {
  final String baseUrl;
  String? _accessToken;
  String? _refreshToken;
  String? _userRole;

  ApiService({String? baseUrl})
      : baseUrl = baseUrl ??
            (_kEnvUrl.isNotEmpty ? _kEnvUrl : kIsWeb ? _kProdUrl : _kDevUrl);

  bool get isAuthenticated => _accessToken != null;

  /// Decode role from JWT payload — fallback when secure-storage misses cf_role.
  static String _roleFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return 'citoyen';
      var payload = parts[1];
      switch (payload.length % 4) {
        case 2:
          payload += '==';
        case 3:
          payload += '=';
      }
      final claims =
          jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
      return claims['role'] as String? ?? 'citoyen';
    } catch (_) {
      return 'citoyen';
    }
  }

  String get userRole {
    if (_userRole != null && _userRole!.isNotEmpty) return _userRole!;
    if (_accessToken != null) return _roleFromJwt(_accessToken!);
    return 'citoyen';
  }

  void setToken(String token) => _accessToken = token;
  void clearToken() {
    _accessToken = null;
    _refreshToken = null;
    _userRole = null;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<void> restoreSession() async {
    _accessToken = await _storage.read(key: _keyAccess);
    _refreshToken = await _storage.read(key: _keyRefresh);
    _userRole = await _storage.read(key: _keyRole);
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
        _userRole = _roleFromJwt(_accessToken!);
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
      _userRole = data['role'] as String? ?? 'citoyen';
      await _storage.write(key: _keyAccess, value: _accessToken);
      if (_refreshToken != null) {
        await _storage.write(key: _keyRefresh, value: _refreshToken);
      }
      await _storage.write(key: _keyRole, value: _userRole);
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
    _userRole = null;
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
    await _storage.delete(key: _keyRole);
  }

  Future<List<CommuneStats>> getCommuneStats() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/communes/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => CommuneStats.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(res.statusCode, 'Erreur chargement communes');
  }

  Future<PredictionPage> getPredictions({int limit = 25, int offset = 0, String? zone}) async {
    final params = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (zone != null) params['zone'] = zone;
    final uri = Uri.parse('$baseUrl/api/predictions/').replace(
      queryParameters: params,
    );
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = data['results'] as List;
      return PredictionPage(
        results: list.map((e) => Prediction.fromJson(e as Map<String, dynamic>)).toList(),
        hasMore: data['next'] != null,
        count: (data['count'] as num).toInt(),
      );
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

  Future<void> updateReport(int id, String statut) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/reports/$id/'),
      headers: _headers,
      body: jsonEncode({'statut': statut}),
    );
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, _parseError(res.body));
    }
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

class PredictionPage {
  final List<Prediction> results;
  final bool hasMore;
  final int count;
  const PredictionPage({
    required this.results,
    required this.hasMore,
    required this.count,
  });
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
