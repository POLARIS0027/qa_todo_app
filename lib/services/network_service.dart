import '../models/settings_model.dart';

class NetworkService {
  final SettingsModel _settings;

  NetworkService(this._settings);

  String get baseUrl => _settings.baseUrl;
  int get timeout => _settings.timeout;

  // HTTP 관련 공통 헤더 설정
  Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
      };

  Map<String, String> authHeaders(String token) => {
        ...defaultHeaders,
        'Authorization': 'Bearer $token',
      };
} 