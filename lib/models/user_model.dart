import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../models/settings_model.dart';

class UserModel extends ChangeNotifier {
  String? _username;
  String? _authToken;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;
  final SettingsModel? _settingsModel;

  String? get username => _username;
  String? get authToken => _authToken;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Bug#10: 토큰 만료 체크 없음
  // 앱 재시작 시 토큰 만료 여부를 확인하지 않고 자동 로그인 처리
  UserModel({SettingsModel? settingsModel}) : _settingsModel = settingsModel {
    _checkLoginStatus();
  }

  // Bug#11: 네트워크 실패 시 무한 로딩
  // 네트워크 연결 실패 시 에러 처리 없이 로딩 상태만 계속 유지
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final baseUrl = _settingsModel?.baseUrl ?? 'http://localhost:3000/api';
      final result = await AuthService.login(baseUrl, email, password);
      if (result['success']) {
        _username = email;
        _authToken = result['token']; // 토큰 저장
        _isLoggedIn = true;
        await _saveLoginInfo(email, _authToken);
        _setLoading(false);
        return true;
      } else {
        _setError(result['message'] ?? '로그인 실패');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      // Bug#11: 네트워크 에러 시 로딩 상태를 끄지 않음
      // _setLoading(false); // 이 라인을 제거하여 무한 로딩 버그 구현
      _setError('네트워크 오류: ${e.toString()}');
      debugPrint('Login error: $e');
      return false;
    }
  }

  // Bug#8: 중복 이메일 허용
  // Bug#9: 비밀번호 확인 검증 없음
  Future<bool> signup(
      String email, String password, String confirmPassword) async {
    _setLoading(true);
    _clearError();

    // Bug#9: 비밀번호 확인이 일치하는지 검증하지 않음
    // if (password != confirmPassword) return false;

    try {
      // Bug#8: 이미 존재하는 이메일인지 확인하지 않음
      final baseUrl = _settingsModel?.baseUrl ?? 'http://localhost:3000/api';
      debugPrint('Signup baseUrl: $baseUrl');
      debugPrint('SettingsModel is null: ${_settingsModel == null}');
      final result =
          await AuthService.signup(baseUrl, email, password, confirmPassword);
      if (result['success']) {
        _setLoading(false);
        return true;
      } else {
        _setError(result['message'] ?? '회원가입 실패');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('네트워크 오류: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    _username = null;
    _authToken = null;
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('auth_token');
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    final savedToken = prefs.getString('auth_token');
    if (savedUsername != null && savedToken != null) {
      _username = savedUsername;
      _authToken = savedToken;
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  Future<void> _saveLoginInfo(String email, String? token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', email);
    if (token != null) {
      await prefs.setString('auth_token', token);
    }
  }
}
