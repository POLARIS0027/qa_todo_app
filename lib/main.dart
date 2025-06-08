import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/todo_model.dart';
import 'models/user_model.dart';
import 'models/settings_model.dart';
import 'screens/login_screen.dart';
import 'screens/todo_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsModel()),
        ChangeNotifierProvider(create: (_) => UserModel()),
        ChangeNotifierProvider(create: (_) => TodoModel()),
        ProxyProvider<SettingsModel, AuthService>(
          update: (context, settings, _) =>
              AuthService(baseUrl: settings.baseUrl),
        ),
      ],
      child: MaterialApp(
        title: 'QA 교육용 Todo 앱',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Consumer<UserModel>(
          builder: (context, userModel, child) {
            // Bug#11: 로그아웃 후 뒤로 가기로 접근 가능 (중간 난이도)
            // 정상적이라면 로그아웃 시 네비게이션 스택을 완전히 초기화해야 함
            // 현재는 단순히 화면만 바뀌어서 뒤로 가기로 이전 화면 접근 가능
            return userModel.isLoggedIn ? TodoScreen() : LoginScreen();
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
