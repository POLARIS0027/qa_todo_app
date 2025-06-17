import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/app_services.dart';
import '../models/todo_model.dart';

class UserModel extends ChangeNotifier {
  String? _username;
  String? _authToken;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;

  String? get username => _username;
  String? get authToken => _authToken;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // GetIt 사용으로 생성자 단순화
  UserModel() {
    _checkLoginStatus();
  }

  // GetIt을 통해 ApiService 접근
  String get _baseUrl => getIt<ApiService>().baseUrl;

  // Bug#8: トークン まれそう チェック ない
  // アプリ 再起動 時 トークン まれそう どうか 確認せず 自動 ログイン 処理
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await AuthService.login(_baseUrl, email, password);
      if (result['success']) {
        _username = email;
        _authToken = result['token']; // トークン 保存
        _isLoggedIn = true;
        await _saveLoginInfo(email, _authToken);

        // 로그인 성공 시 TodoModel 새로고침
        print('DEBUG login: success, refreshing TodoModel');
        try {
          await getIt<TodoModel>().refreshUser();
        } catch (e) {
          print('DEBUG login: TodoModel refresh error: $e');
        }

        _setLoading(false);
        return true;
      } else {
        _setError(result['message'] ?? 'ログイン失敗');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      // Bug#11: ネットワークエラー時にローディング状態を解除しない
      // _setLoading(false); // この行を削除して無限ローディングバグを実装
      _setError('ネットワークエラー: ${e.toString()}');
      debugPrint('Login error: $e');
      return false;
    }
  }

  // Bug#9: 重複メール許可
  // Bug#10: パスワード確認検証なし
  Future<bool> signup(
      String email, String password, String confirmPassword) async {
    _setLoading(true);
    _clearError();

    // Bug#10: パスワード確認が一致するか検証しない
    // if (password != confirmPassword) return false;

    try {
      // Bug#9: 既存メールかどうか確認しない
      debugPrint('Signup baseUrl: $_baseUrl');
      final result =
          await AuthService.signup(_baseUrl, email, password, confirmPassword);
      if (result['success']) {
        _setLoading(false);
        return true;
      } else {
        _setError(result['message'] ?? '会員登録失敗');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('ネットワークエラー: ${e.toString()}');
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

      // 앱 재시작 시 Todo 데이터 로드
      try {
        await getIt<TodoModel>().refreshUser();
      } catch (e) {
        debugPrint('Auto-login: TodoModel refresh error: $e');
        // 여기서 에러를 처리할 수 있습니다. 예를 들어 로그아웃 시키기 등.
      }

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
