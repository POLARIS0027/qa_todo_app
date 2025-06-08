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
        ChangeNotifierProxyProvider<SettingsModel, UserModel>(
          create: (_) => UserModel(),
          update: (_, settings, userModel) =>
              UserModel(settingsModel: settings),
        ),
        ChangeNotifierProxyProvider2<SettingsModel, UserModel, TodoModel>(
          create: (_) => TodoModel(),
          update: (_, settings, user, todoModel) =>
              TodoModel(settingsModel: settings, userModel: user),
        ),
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
            return userModel.isLoggedIn ? TodoScreen() : LoginScreen();
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
