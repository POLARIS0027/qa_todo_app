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

  // Bug#8: トークン まれそう チェック ない
  // アプリ 再起動 時 トークン まれそう どうか 確認せず 自動 ログイン 処理
  UserModel({SettingsModel? settingsModel}) : _settingsModel = settingsModel {
    _checkLoginStatus();
  }

  // Bug#11: ネットワーク 失敗 時 無限 ローディング
  // ネットワーク 接続 失敗 時 エラー 処理 なし ローディング 状態 継続 保持
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final baseUrl = _settingsModel?.baseUrl ?? 'http://localhost:3000/api';
      final result = await AuthService.login(baseUrl, email, password);
      if (result['success']) {
        _username = email;
        _authToken = result['token']; // トークン 保存
        _isLoggedIn = true;
        await _saveLoginInfo(email, _authToken);
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
      final baseUrl = _settingsModel?.baseUrl ?? 'http://localhost:3000/api';
      debugPrint('Signup baseUrl: $baseUrl');
      debugPrint('SettingsModel is null: ${_settingsModel == null}');
      final result =
          await AuthService.signup(baseUrl, email, password, confirmPassword);
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
