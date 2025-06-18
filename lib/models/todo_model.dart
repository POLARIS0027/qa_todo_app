import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/app_services.dart';
import '../models/user_model.dart';
import '../models/settings_model.dart';
import 'dart:convert';

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
  static const int _minToggleInterval = 500; // 0.5초

  List<Todo> get todos => _todos;
  bool get isLoading => _isLoading;
  String? get editingTodoId => _editingTodoId;
  String get editingText => _editingText;

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
    _currentUserId = prefs.getString('username'); // メールアドレス를 userIdとして使用
    print('DEBUG _loadCurrentUser: _currentUserId = $_currentUserId');
    if (_currentUserId != null) {
      await loadTodos();
    }
  }

  // 로그인 후 사용자 정보 새로고침
  Future<void> refreshUser() async {
    print('DEBUG refreshUser: called');
    await _loadCurrentUser();
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
      title = "新しいタスク";
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
    todo.isCompleted = !todo.isCompleted;

    _sortTodos();

    try {
      final baseUrl = _baseUrl;
      final authToken = _authToken;
      if (authToken == null) return;

      await AuthService.updateTodo(baseUrl, id, authToken,
          isCompleted: todo.isCompleted);
    } catch (e) {
      debugPrint('Todo 状態変更エラー: $e');
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
        }
      }
    }
    _editingTodoId = null;
    _editingText = '';
    notifyListeners();
  }

  void cancelEdit() {
    if (_editingTodoId != null) {
      final todoIndex = _todos.indexWhere((todo) => todo.id == _editingTodoId);
      if (todoIndex != -1) {
        _todos[todoIndex].title = _editingText;
        notifyListeners();
      }
    }
    _editingTodoId = null;
    _editingText = '';
    notifyListeners();
  }

  // Bug#19: メモリリーク - disposeで解放しない（難易度：高）
  void simulateMemoryLeak() {
    if (_todos.length > 20) {
      for (int i = 0; i < 1000; i++) {
        List<int> heavyList = List.generate(10000, (index) => index);
        heavyList.sort();
      }
    }
  }
}
