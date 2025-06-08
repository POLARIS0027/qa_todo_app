import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../screens/settings_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    // Bug#11: ネットワーク失敗時の無限ローディング (中級)
    // ネットワーク接続がない時にローディングが続き、エラーメッセージや再試行オプションがない
    final userModel = Provider.of<UserModel>(context, listen: false);
    final success =
        await userModel.login(_emailController.text, _passwordController.text);

    // Consumerによって自動で画面遷移が処理されるため、別途ナビゲーションは不要
    if (!success && mounted && !userModel.isLoading) {
      // 詳細なエラーメッセージ表示
      final errorMessage = userModel.errorMessage ?? 'ログインに失敗しました。';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  void _handleSignup() async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    final success = await userModel.signup(
      _emailController.text,
      _passwordController.text,
      _confirmPasswordController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('会員登録が完了しました。ログインしてください。')),
      );
      _tabController.animateTo(0); // ログインタブに移動
    } else if (mounted) {
      // 詳細なエラーメッセージ表示
      final errorMessage = userModel.errorMessage ?? '会員登録に失敗しました。';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QA教育用Todoアプリ'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'ログイン'),
            // Bug#1: UIのタイポ「会員登録」->「会院登録」(易)
            Tab(text: '会院登録'),
          ],
          onTap: (index) {
            setState(() {
              _isLogin = index == 0;
            });
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLoginTab(),
          _buildRegisterTab(),
        ],
      ),
    );
  }

  Widget _buildLoginTab() {
    return Consumer<UserModel>(
      builder: (context, userModel, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'メールアドレス',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                ),
                obscureText: false,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: userModel.isLoading ? null : _handleLogin,
                  child: userModel.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('ログイン'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegisterTab() {
    return Consumer<UserModel>(
      builder: (context, userModel, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'メールアドレス',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'パスワード確認',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: userModel.isLoading ? null : _handleSignup,
                  child: userModel.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('会員登録'),
                ),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _tabController.animateTo(0);
                  setState(() {
                    _isLogin = true;
                  });
                },
                child: Text('すでにアカウントをお持ちですか？ログイン'),
              ),
            ],
          ),
        );
      },
    );
  }
}
