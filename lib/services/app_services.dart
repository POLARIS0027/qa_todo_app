import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import '../models/todo_model.dart';

final GetIt getIt = GetIt.instance;

class AppServices {
  static Future<void> setupServices() async {
    // SharedPreferences 등록 (싱글톤)
    final prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(prefs);

    // SettingsModel 등록 (싱글톤)
    getIt.registerSingleton<SettingsModel>(SettingsModel());

    // ApiService 등록 (SettingsModel에 의존)
    getIt.registerLazySingleton<ApiService>(
      () => ApiService(getIt<SettingsModel>()),
    );

    // UserModel 등록 (싱글톤)
    getIt.registerSingleton<UserModel>(UserModel());

    // TodoModel 등록 (lazy 싱글톤 - 로그인 후 필요할 때 생성)
    getIt.registerLazySingleton<TodoModel>(() => TodoModel());
  }
}

class ApiService {
  final SettingsModel _settings;

  ApiService(this._settings);

  String get baseUrl => _settings.baseUrl;

  // HTTP 관련 공통 헤더 설정
  Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
      };

  Map<String, String> authHeaders(String token) => {
        ...defaultHeaders,
        'Authorization': 'Bearer $token',
      };
}
