import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/app_services.dart';
import '../models/user_model.dart';
import '../models/settings_model.dart';

class Todo {
  String id;
  String title;
  bool isCompleted;
  DateTime createdAt;

  Todo({
    required this.id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'].toString(),
      title: json['title'],
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class TodoModel extends ChangeNotifier {
  List<Todo> _todos = [];
  bool _isLoading = false;
  String? _editingTodoId;
  String _editingText = '';
  String? _currentUserId;
  DateTime? _lastToggleTime;
  String? _errorMessage;
  static const int _minToggleInterval = 500; // 0.5초

  List<Todo> get todos => _todos;
  bool get isLoading => _isLoading;
  String? get editingTodoId => _editingTodoId;
  String get editingText => _editingText;
  String? get errorMessage => _errorMessage;

  // GetIt 사용으로 생성자 단순화
  TodoModel() {
    _loadCurrentUser();
  }

  // GetIt을 통해 필요한 서비스들에 접근
  String get _baseUrl => getIt<SettingsModel>().baseUrl;
  UserModel get _userModel => getIt<UserModel>();
  String? get _authToken => _userModel.authToken;

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('username'); // メールアドレスを userIdとして使用
    debugPrint('DEBUG _loadCurrentUser: _currentUserId = $_currentUserId');
    if (_currentUserId != null) {
      await loadTodos();
    }
  }

  // 로그인 후 사용자 정보 새로고침
  Future<void> refreshUser() async {
    debugPrint('DEBUG refreshUser: called');
    await _loadCurrentUser();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadTodos() async {
    if (_currentUserId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final baseUrl = _baseUrl;
      final authToken = _authToken;
      if (authToken == null) return;

      final todosData =
          await AuthService.getTodos(baseUrl, _currentUserId!, authToken);

      _todos = todosData
          .map((data) => Todo(
                id: data['id'].toString(),
                title: data['title'],
                isCompleted: data['is_completed'] == 1,
                createdAt: DateTime.parse(data['created_at']),
              ))
          .toList();

      // 로드 후 정렬
      _sortTodos();
    } catch (e) {
      debugPrint('Todo ロードエラー: $e');
      // サーバー失敗時にローカルストレージへフォールバックしない（削除済みバグ）
      _todos = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Todo 정렬 함수
  void _sortTodos() {
    _todos.sort((a, b) {
      // 1. 완료 상태로 우선 정렬 (미완료가 위에)
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }

      // 2. 같은 상태 내에서는 최신순 정렬 (최신이 위에)
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Future<Todo?> addTodo(String title) async {
    if (_currentUserId == null) {
      return null;
    }

    if (title.isEmpty) {
      return null; // 빈 타이틀은 추가하지 않음
    }

    try {
      final baseUrl = _baseUrl;
      final authToken = _authToken;

      if (authToken == null) {
        return null;
      }

      final result = await AuthService.createTodo(
          baseUrl, _currentUserId!, title, authToken);

      final newTodo = Todo.fromJson(result['todo']);

      _todos.insert(0, newTodo);
      _sortTodos();
      return newTodo;
    } catch (e) {
      debugPrint('Todo 追加エラー: $e');
      _setError('タスクの追加に失敗しました。ネットワーク接続を確認してください。');
      return null;
    }
  }

  Future<void> toggleTodo(String id) async {
    final now = DateTime.now();

    if (_lastToggleTime != null &&
        now.difference(_lastToggleTime!).inMilliseconds < _minToggleInterval) {
      return;
    }

    _lastToggleTime = now;

    final todoIndex = _todos.indexWhere((todo) => todo.id == id);
    if (todoIndex == -1) return;

    final todo = _todos[todoIndex];
    final originalState = todo.isCompleted; // 원래 상태 저장

    try {
      final baseUrl = _baseUrl;
      final authToken = _authToken;
      if (authToken == null) return;

      // 서버 업데이트 먼저 시도
      await AuthService.updateTodo(baseUrl, id, authToken,
          isCompleted: !originalState);

      // 서버 성공 시에만 UI 상태 변경
      todo.isCompleted = !originalState;
      _sortTodos();
      notifyListeners();
    } catch (e) {
      debugPrint('Todo 状態変更エラー: $e');
      _setError('タスクの状態変更に失敗しました。ネットワーク接続を確認してください。');
      // 에러 시 원래 상태 유지 (변경하지 않음)
    }
  }

  Future<void> deleteTodo(String id) async {
    final todoIndex = _todos.indexWhere((todo) => todo.id == id);
    if (todoIndex == -1) return;

    _todos.removeAt(todoIndex);

    try {
      final baseUrl = _baseUrl;
      final authToken = _authToken;
      if (authToken == null) return;

      await AuthService.deleteTodo(baseUrl, id, authToken);
    } catch (e) {
      debugPrint('Todo 削除エラー: $e');
      _setError('タスクの削除に失敗しました。ネットワーク接続を確認してください。');
    }
  }

  void startEditing(String id, String currentTitle) {
    _editingTodoId = id;
    _editingText = currentTitle;
    notifyListeners();
  }

  void updateEditingText(String text) {
    _editingText = text;
    notifyListeners();
  }

  Future<void> saveEdit() async {
    if (_editingTodoId != null) {
      final todoIndex = _todos.indexWhere((todo) => todo.id == _editingTodoId);
      if (todoIndex != -1) {
        final oldTitle = _todos[todoIndex].title;

        // 即時UI更新（楽観的更新）
        _todos[todoIndex].title = _editingText;
        notifyListeners();

        try {
          final baseUrl = _baseUrl;
          final authToken = _authToken;
          if (authToken == null) return;

          await AuthService.updateTodo(baseUrl, _editingTodoId!, authToken,
              title: _editingText);
        } catch (e) {
          debugPrint('Todo 編集エラー: $e');
          _setError('タスクの編集に失敗しました。ネットワーク接続を確認してください。');
        }
      }
    }
    _editingTodoId = null;
    _editingText = '';
    notifyListeners();
  }

  void cancelEdit() {
    // 취소 시에는 변경사항을 저장하지 않음
    _editingTodoId = null;
    _editingText = '';
    notifyListeners();
  }
}
