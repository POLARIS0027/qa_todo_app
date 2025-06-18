import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import '../models/todo_model.dart';
import '../services/network_service.dart';

final GetIt getIt = GetIt.instance;

class AppServices {
  static Future<void> setupServices() async {
    // SharedPreferences 등록 (싱글톤)
    final prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(prefs);

    // SettingsModel 등록 (싱글톤)
    getIt.registerSingleton<SettingsModel>(SettingsModel());

    // NetworkService 등록 (SettingsModel에 의존)
    getIt.registerLazySingleton<NetworkService>(
      () => NetworkService(getIt<SettingsModel>()),
    );

    // UserModel 등록 (싱글톤)
    getIt.registerSingleton<UserModel>(UserModel());

    // TodoModel 등록 (lazy 싱글톤 - 로그인 후 필요할 때 생성)
    getIt.registerLazySingleton<TodoModel>(() => TodoModel());
  }
}
