import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SettingsModel extends ChangeNotifier {
  String _serverAddress = 'localhost';
  String _serverPort = '3000';
  String _dnsServer = '8.8.8.8';
  String _protocol = 'http';
  bool _useHttps = false;
  int _timeout = 30;

  String get serverAddress => _serverAddress;
  String get serverPort => _serverPort;
  String get dnsServer => _dnsServer;
  String get protocol => _protocol;
  bool get useHttps => _useHttps;
  int get timeout => _timeout;

  String get baseUrl => '$_protocol://$_serverAddress:$_serverPort/api';

  SettingsModel() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _serverAddress = prefs.getString('server_address') ?? 'localhost';
    _serverPort = prefs.getString('server_port') ?? '3000';
    _dnsServer = prefs.getString('dns_server') ?? '8.8.8.8';
    _protocol = prefs.getString('protocol') ?? 'http';
    _useHttps = prefs.getBool('use_https') ?? false;
    _timeout = prefs.getInt('timeout') ?? 30;

    // HTTPS 설정과 protocol 동기화
    _protocol = _useHttps ? 'https' : 'http';

    notifyListeners();
  }

  Future<void> updateServerAddress(String address) async {
    final validation = _validateServerAddress(address);
    if (validation != null) {
      throw Exception(validation);
    }

    _serverAddress = address;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> updateServerPort(String port) async {
    final validation = _validatePort(port);
    if (validation != null) {
      throw Exception(validation);
    }

    _serverPort = port;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> updateDnsServer(String dns) async {
    final validation = _validateDnsServer(dns);
    if (validation != null) {
      throw Exception(validation);
    }

    _dnsServer = dns;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> updateProtocol(String protocol) async {
    _protocol = protocol;
    _useHttps = protocol == 'https';
    await _saveSettings();
    notifyListeners();
  }

  Future<void> updateTimeout(int timeout) async {
    final validation = _validateTimeout(timeout);
    if (validation != null) {
      throw Exception(validation);
    }

    _timeout = timeout;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('server_address', _serverAddress);
    await prefs.setString('server_port', _serverPort);
    await prefs.setString('dns_server', _dnsServer);
    await prefs.setString('protocol', _protocol);
    await prefs.setBool('use_https', _useHttps);
    await prefs.setInt('timeout', _timeout);
  }

  // 모든 설정을 기본값으로 초기화
  Future<void> resetToDefaults() async {
    _serverAddress = 'localhost';
    _serverPort = '3000';
    _dnsServer = '8.8.8.8';
    _protocol = 'http';
    _useHttps = false;
    _timeout = 30;

    await _saveSettings();
    notifyListeners();
  }

  // 실제 연결 테스트 기능
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: _timeout));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 완전한 설정 유효성 검사
  Map<String, String> validateSettings() {
    Map<String, String> errors = {};

    final addressError = _validateServerAddress(_serverAddress);
    if (addressError != null) {
      errors['server_address'] = addressError;
    }

    final portError = _validatePort(_serverPort);
    if (portError != null) {
      errors['server_port'] = portError;
    }

    final dnsError = _validateDnsServer(_dnsServer);
    if (dnsError != null) {
      errors['dns_server'] = dnsError;
    }

    final timeoutError = _validateTimeout(_timeout);
    if (timeoutError != null) {
      errors['timeout'] = timeoutError;
    }

    return errors;
  }

  // 개별 검증 메서드들
  String? _validateServerAddress(String address) {
    if (address.isEmpty) {
      return '서버 주소를 입력하세요';
    }

    // localhost 허용
    if (address.toLowerCase() == 'localhost') {
      return null;
    }

    // IP 주소 형식 검증 (간단한 버전)
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (ipRegex.hasMatch(address)) {
      final parts = address.split('.');
      for (String part in parts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) {
          return '올바른 IP 주소 형식이 아닙니다';
        }
      }
      return null;
    }

    // 도메인 이름 형식 검증 (간단한 버전)
    final domainRegex = RegExp(
        r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$');
    if (!domainRegex.hasMatch(address)) {
      return '올바른 서버 주소 형식이 아닙니다';
    }

    return null;
  }

  String? _validatePort(String port) {
    if (port.isEmpty) {
      return '포트를 입력하세요';
    }

    final portNum = int.tryParse(port);
    if (portNum == null) {
      return '포트는 숫자여야 합니다';
    }

    if (portNum < 1 || portNum > 65535) {
      return '포트는 1-65535 범위여야 합니다';
    }

    return null;
  }

  String? _validateDnsServer(String dns) {
    if (dns.isEmpty) {
      return 'DNS 서버를 입력하세요';
    }

    // IP 주소 형식 검증
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(dns)) {
      return '올바른 IP 주소 형식이 아닙니다';
    }

    final parts = dns.split('.');
    for (String part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return '올바른 IP 주소 형식이 아닙니다';
      }
    }

    return null;
  }

  String? _validateTimeout(int timeout) {
    if (timeout < 5) {
      return '타임아웃은 최소 5초 이상이어야 합니다';
    }

    if (timeout > 300) {
      return '타임아웃은 최대 300초 이하여야 합니다';
    }

    return null;
  }
}
