import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/todo_model.dart';
import 'models/user_model.dart';
import 'models/settings_model.dart';
import 'screens/login_screen.dart';
import 'screens/todo_screen.dart';
import 'services/app_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // GetIt 서비스 초기화
  await AppServices.setupServices();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // GetIt에서 관리되는 모델들을 Provider로 노출
        ChangeNotifierProvider.value(value: getIt<SettingsModel>()),
        ChangeNotifierProvider.value(value: getIt<UserModel>()),
        ChangeNotifierProvider.value(value: getIt<TodoModel>()),
      ],
      child: MaterialApp(
        title: 'QA教育用Todoアプリ',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Consumer<UserModel>(
          builder: (context, userModel, child) {
            return userModel.isLoggedIn ? TodoScreen() : LoginScreen();
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
