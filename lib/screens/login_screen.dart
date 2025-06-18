import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../screens/settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  late TabController _tabController;

  // SnackBar 중복 표시 방지를 위한 플래그들
  bool _emailSnackBarShown = false;
  bool _passwordSnackBarShown = false;
  bool _confirmPasswordSnackBarShown = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 실시간 UI 업데이트를 위한 리스너 추가
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Color _getEmailBorderColor() {
    final length = _emailController.text.length;
    if (length >= 50) return Colors.red;
    return Colors.grey;
  }

  Color _getPasswordBorderColor() {
    final length = _passwordController.text.length;
    if (length >= 20) return Colors.red;
    return Colors.grey;
  }

  Color _getConfirmPasswordBorderColor() {
    final length = _confirmPasswordController.text.length;
    if (length >= 20) return Colors.red;
    return Colors.grey;
  }

  // SnackBar 표시 함수들
  void _showEmailLimitSnackBar() {
    if (!_emailSnackBarShown) {
      _emailSnackBarShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メールアドレスは50文字までです'),
          duration: Duration(seconds: 2),
        ),
      );
      // 2초 후 다시 표시 가능하도록 설정
      Future.delayed(const Duration(seconds: 2), () {
        _emailSnackBarShown = false;
      });
    }
  }

  void _showPasswordLimitSnackBar() {
    if (!_passwordSnackBarShown) {
      _passwordSnackBarShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('パスワードは20文字までです'),
          duration: Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        _passwordSnackBarShown = false;
      });
    }
  }

  void _showConfirmPasswordLimitSnackBar() {
    if (!_confirmPasswordSnackBarShown) {
      _confirmPasswordSnackBarShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('パスワード確認は20文字までです'),
          // バグ#12: パスワード確認のエラーメッセージが赤色になっている(易)
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        _confirmPasswordSnackBarShown = false;
      });
    }
  }

  void _handleLogin() async {
    // Bug#11: ネットワーク失敗時の無限ローディング (中級)
    // ネットワーク接続がない時にローディングが続き、エラーメッセージや再試行オプションがない
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final userModel = Provider.of<UserModel>(context, listen: false);
    final success =
        await userModel.login(_emailController.text, _passwordController.text);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.length > 50) {
      _showEmailLimitSnackBar();
      return;
    }

    if (password.length > 20) {
      _showPasswordLimitSnackBar();
      return;
    }

    if (confirmPassword.length > 20) {
      _showConfirmPasswordLimitSnackBar();
      return;
    }

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
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
        title: const Text('QA教育用Todoアプリ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
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
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildLoginTab(),
            _buildRegisterTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    return Consumer<UserModel>(
      builder: (context, userModel, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'メールアドレスを入力してください';
                  }
                  final emailRegex =
                      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$');
                  if (!emailRegex.hasMatch(value)) {
                    return '有効なメールアドレスを入力してください';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (value.length >= 50) {
                    _showEmailLimitSnackBar();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'メールアドレス',
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _getEmailBorderColor()),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: _getEmailBorderColor(), width: 2),
                  ),
                  counterText: '',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                maxLength: 20,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (value.length >= 20) {
                    _showPasswordLimitSnackBar();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _getPasswordBorderColor()),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: _getPasswordBorderColor(), width: 2),
                  ),
                  counterText: '',
                ),
                obscureText: false,
              ),
              const SizedBox(height: 24),
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
                      : const Text('ログイン'),
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'メールアドレスを入力してください';
                  }
                  final emailRegex =
                      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$');
                  if (!emailRegex.hasMatch(value)) {
                    return '有効なメールアドレスを入力してください';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (value.length >= 50) {
                    _showEmailLimitSnackBar();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'メールアドレス',
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _getEmailBorderColor()),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: _getEmailBorderColor(), width: 2),
                  ),
                  counterText: '',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                maxLength: 20,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (value.length >= 20) {
                    _showPasswordLimitSnackBar();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _getPasswordBorderColor()),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: _getPasswordBorderColor(), width: 2),
                  ),
                  counterText: '',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                maxLength: 20,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワード確認を入力してください';
                  }
                  // Bug#10: パスワード確認検証なし - 意図的に一致検証をスキップ
                  return null;
                },
                onChanged: (value) {
                  if (value.length >= 20) {
                    _showConfirmPasswordLimitSnackBar();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'パスワード確認',
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: _getConfirmPasswordBorderColor()),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: _getConfirmPasswordBorderColor(), width: 2),
                  ),
                  counterText: '',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: userModel.isLoading ? null : _handleSignup,
                  child: userModel.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('会員登録'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _tabController.animateTo(0);
                  setState(() {
                    _isLogin = true;
                  });
                },
                child: const Text('すでにアカウントをお持ちですか？ログイン'),
              ),
            ],
          ),
        );
      },
    );
  }
}
