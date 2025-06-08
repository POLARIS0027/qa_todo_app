import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class UserModel extends ChangeNotifier {
  String? _username;
  bool _isLoggedIn = false;
  bool _isLoading = false;

  String? get username => _username;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  // Bug#10: 토큰 만료 체크 없음
  // 앱 재시작 시 토큰 만료 여부를 확인하지 않고 자동 로그인 처리
  UserModel() {
    _checkLoginStatus();
  }

  // Bug#11: 네트워크 실패 시 무한 로딩
  // 네트워크 연결 실패 시 에러 처리 없이 로딩 상태만 계속 유지
  Future<bool> login(String email, String password) async {
    _setLoading(true);

    try {
      final result = await AuthService.login(email, password);
      if (result['success']) {
        _username = email;
        _isLoggedIn = true;
        await _saveLoginInfo(email);
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        return false;
      }
    } catch (e) {
      // Bug#11: 네트워크 에러 시 로딩 상태를 끄지 않음
      // _setLoading(false); // 이 라인을 제거하여 무한 로딩 버그 구현
      debugPrint('Login error: $e');
      return false;
    }
  }

  // Bug#7: 중복 이메일 허용
  // Bug#8, Bug#9: 비밀번호 확인 검증 없음
  Future<bool> signup(
      String email, String password, String confirmPassword) async {
    _setLoading(true);

    // Bug#8, Bug#9: 비밀번호 확인이 일치하는지 검증하지 않음
    // if (password != confirmPassword) return false;

    try {
      // Bug#7: 이미 존재하는 이메일인지 확인하지 않음
      final result = await AuthService.signup(email, password);
      _setLoading(false);
      return result['success'] ?? false;
    } catch (e) {
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    _username = null;
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    if (savedUsername != null) {
      _username = savedUsername;
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  Future<void> _saveLoginInfo(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', email);
  }
}
