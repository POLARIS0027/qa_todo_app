import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
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
      id: json['id'],
      title: json['title'],
      isCompleted: json['isCompleted'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class TodoModel extends ChangeNotifier {
  List<Todo> _todos = [];
  bool _isLoading = false;
  String? _editingTodoId;
  String _editingText = '';
  final SettingsModel? _settingsModel;
  final UserModel? _userModel;
  String? _currentUserId;

  List<Todo> get todos => _todos;
  bool get isLoading => _isLoading;
  String? get editingTodoId => _editingTodoId;
  String get editingText => _editingText;

  TodoModel({SettingsModel? settingsModel, UserModel? userModel})
      : _settingsModel = settingsModel,
        _userModel = userModel {
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('username'); // メールアドレスをuserIdとして使用
    if (_currentUserId != null) {
      await loadTodos();
    }
  }

  Future<void> loadTodos() async {
    if (_currentUserId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final baseUrl = _settingsModel?.baseUrl ?? 'http://localhost:3000/api';
      final authToken = _userModel?.authToken;
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

  Future<void> addTodo(String title) async {
    if (_currentUserId == null) return;

    // Bug#3: 空タイトルはチェックするが空白のみは許可、空タイトル時はダミーテキスト追加（易）
    if (title.isEmpty) {
      title = "新しいタスク";
    }

    try {
      final baseUrl = _settingsModel?.baseUrl ?? 'http://localhost:3000/api';
      final authToken = _userModel?.authToken;
      if (authToken == null) return;

      // Bug#18: 同時に迅速に追加するときにサーバーリクエストが重複する可能性があります（難易度：高）
      await Future.delayed(Duration(milliseconds: 50)); // 意図的な遅延

      final result = await AuthService.createTodo(
          baseUrl, _currentUserId!, title, authToken);

      // サーバーから受け取ったデータでTodoオブジェクトを作成
      final newTodo = Todo(
        id: result['todo']['id'].toString(),
        title: result['todo']['title'],
        isCompleted: result['todo']['isCompleted'] ?? false,
        createdAt: DateTime.parse(result['todo']['createdAt']),
      );

      _todos.add(newTodo);

      // 추가 후 정렬하여 새로운 Todo가 맨 위로 가게 함
      _sortTodos();

      notifyListeners();
    } catch (e) {
      debugPrint('Todo 追加エラー: $e');
      // Bug#15: ネットワーク失敗時にエラーメッセージを表示しない（中級）
    }
  }

  Future<void> toggleTodo(String id) async {
    final todoIndex = _todos.indexWhere((todo) => todo.id == id);
    if (todoIndex == -1) return;

    final todo = _todos[todoIndex];
    final newCompletedState = !todo.isCompleted;

    // 즉시 UI 업데이트 (낙관적 업데이트)
    _todos[todoIndex].isCompleted = newCompletedState;

    // 완료 상태 변경 후 정렬
    _sortTodos();

    notifyListeners();

    try {
      final baseUrl = _settingsModel?.baseUrl ?? 'http://localhost:3000/api';
      final authToken = _userModel?.authToken;
      if (authToken == null) return;

      // 완료状態サーバー保存失敗時にロールバックしない（削除済みバグ）
      await AuthService.updateTodo(baseUrl, id, authToken,
          isCompleted: newCompletedState);
    } catch (e) {
      debugPrint('Todo 状態変更エラー: $e');
      // サーバー保存失敗でもUIは既に変更されたまま（バグ）
    }
  }

  Future<void> deleteTodo(String id) async {
    // Bug#4: 削除確認なしで即削除（易）

    // 即時UIから削除（楽観的更新）
    _todos.removeWhere((todo) => todo.id == id);
    notifyListeners();

    try {
      final baseUrl = _settingsModel?.baseUrl ?? 'http://localhost:3000/api';
      final authToken = _userModel?.authToken;
      if (authToken == null) return;

      await AuthService.deleteTodo(baseUrl, id, authToken);
    } catch (e) {
      debugPrint('Todo 削除エラー: $e');
      // Bug#15: サーバー削除失敗時にUIから既に削除されたまま（中級）
      // 実際はロールバックすべき
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
          final baseUrl =
              _settingsModel?.baseUrl ?? 'http://localhost:3000/api';
          final authToken = _userModel?.authToken;
          if (authToken == null) return;

          await AuthService.updateTodo(baseUrl, _editingTodoId!, authToken,
              title: _editingText);
        } catch (e) {
          debugPrint('Todo 編集エラー: $e');
          // Bug#16: サーバー編集失敗時に前のタイトルへロールバックしない（中級）
          // _todos[todoIndex].title = oldTitle; // この行が必要
        }
      }
    }
    _editingTodoId = null;
    _editingText = '';
    notifyListeners();
  }

  void cancelEdit() {
    // Bug#13: 編集キャンセル時に誤ったテキストが保存される（中級）
    if (_editingTodoId != null) {
      final todoIndex = _todos.indexWhere((todo) => todo.id == _editingTodoId);
      if (todoIndex != -1) {
        _todos[todoIndex].title = _editingText; // 誤ったロジック: キャンセルなのに保存
        notifyListeners();
      }
    }
    _editingTodoId = null;
    _editingText = '';
    notifyListeners();
  }

  // Bug#19: メモリリーク - disposeで解放しない（難易度：高）
  void simulateMemoryLeak() {
    // 100個以上の時にパフォーマンス問題を起こすコード
    if (_todos.length > 20) {
      for (int i = 0; i < 1000; i++) {
        List<int> heavyList = List.generate(10000, (index) => index);
        heavyList.sort();
      }
    }
  }
}
