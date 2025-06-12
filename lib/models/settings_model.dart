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

    // HTTPS 設定と protocol 同期
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

  // 실시간 업데이트용 (저장하지 않음)
  void setServerAddressTemporary(String address) {
    _serverAddress = address;
    notifyListeners();
  }

  // 서버 주소 저장 (검증 포함)
  Future<void> saveServerAddress() async {
    final validation = _validateServerAddress(_serverAddress);
    if (validation != null) {
      throw Exception(validation);
    }
    await _saveSettings();
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

  // 포트 실시간 업데이트용
  void setServerPortTemporary(String port) {
    _serverPort = port;
    notifyListeners();
  }

  // 포트 저장 (검증 포함)
  Future<void> saveServerPort() async {
    final validation = _validatePort(_serverPort);
    if (validation != null) {
      throw Exception(validation);
    }
    await _saveSettings();
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

  // すべての設定をデフォルト値にリセット
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

  // 実際の接続テスト機能
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

  // 完全な設定の有効性検証
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

  // 個別の検証メソッド
  String? _validateServerAddress(String address) {
    if (address.isEmpty) {
      return 'サーバーアドレスを入力してください';
    }

    // localhost 허용
    if (address.toLowerCase() == 'localhost') {
      return null;
    }

    // IP 주소 형식 검증 (올바른 정규식)
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (ipRegex.hasMatch(address)) {
      final parts = address.split('.');
      for (String part in parts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) {
          return '正しいIPアドレス形式ではありません';
        }
      }
      return null;
    }

    // 도메인명 형식 검증
    final domainRegex = RegExp(
        r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$');
    if (!domainRegex.hasMatch(address)) {
      return '正しいサーバーアドレス形式ではありません';
    }

    return null;
  }

  String? _validatePort(String port) {
    if (port.isEmpty) {
      return 'ポートを入力してください';
    }

    final portNum = int.tryParse(port);
    if (portNum == null) {
      return 'ポートは数字でなければなりません';
    }

    if (portNum < 1 || portNum > 65535) {
      return 'ポートは1～65535の範囲でなければなりません';
    }

    return null;
  }

  String? _validateDnsServer(String dns) {
    if (dns.isEmpty) {
      return 'DNSサーバーを入力してください';
    }

    // IPアドレス形式検証
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(dns)) {
      return '正しいIPアドレス形式ではありません';
    }

    final parts = dns.split('.');
    for (String part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return '正しいIPアドレス形式ではありません';
      }
    }

    return null;
  }

  String? _validateTimeout(int timeout) {
    if (timeout < 5) {
      return 'タイムアウトは最低5秒以上でなければなりません';
    }

    if (timeout > 300) {
      return 'タイムアウトは最大300秒以下でなければなりません';
    }

    return null;
  }
}
