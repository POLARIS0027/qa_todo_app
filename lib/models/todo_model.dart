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
    _currentUserId = prefs.getString('username'); // 이메일을 userId로 사용
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
    } catch (e) {
      debugPrint('Todo 로드 오류: $e');
      // Bug#12: 서버 실패 시 로컬 저장소로 fallback하지 않음
      _todos = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTodo(String title) async {
    if (_currentUserId == null) return;

    // Bug#3: 빈 제목 체크하지만 공백만 있는 경우는 허용하고, 빈 제목일 때 더미 텍스트 추가 (쉬운 버그)
    if (title.isEmpty) {
      title = "새로운 할일";
    }

    try {
      final baseUrl = _settingsModel?.baseUrl ?? 'http://localhost:3000/api';
      final authToken = _userModel?.authToken;
      if (authToken == null) return;

      // Bug#19: 동시에 빠르게 추가할 때 서버 요청이 중복될 수 있음 (어려운 버그)
      await Future.delayed(Duration(milliseconds: 50)); // 의도적 지연

      final result = await AuthService.createTodo(
          baseUrl, _currentUserId!, title, authToken);

      // 서버에서 받은 데이터로 Todo 객체 생성
      final newTodo = Todo(
        id: result['todo']['id'].toString(),
        title: result['todo']['title'],
        isCompleted: result['todo']['isCompleted'] ?? false,
        createdAt: DateTime.parse(result['todo']['createdAt']),
      );

      _todos.add(newTodo);
      notifyListeners();
    } catch (e) {
      debugPrint('Todo 추가 오류: $e');
      // Bug#15: 네트워크 실패 시 에러 메시지 표시 안함 (중간 난이도)
    }
  }

  Future<void> toggleTodo(String id) async {
    final todoIndex = _todos.indexWhere((todo) => todo.id == id);
    if (todoIndex == -1) return;

    final todo = _todos[todoIndex];
    final newCompletedState = !todo.isCompleted;

    // 즉시 UI 업데이트 (낙관적 업데이트)
    _todos[todoIndex].isCompleted = newCompletedState;
    notifyListeners();

    try {
      final baseUrl = _settingsModel?.baseUrl ?? 'http://localhost:3000/api';
      final authToken = _userModel?.authToken;
      if (authToken == null) return;

      // Bug#12: 완료 상태 서버 저장 실패 시 롤백하지 않음 (중간 난이도)
      await AuthService.updateTodo(baseUrl, id, authToken,
          isCompleted: newCompletedState);
    } catch (e) {
      debugPrint('Todo 상태 변경 오류: $e');
      // 서버 저장 실패해도 UI는 이미 변경된 상태로 유지됨 (버그)
    }
  }

  Future<void> deleteTodo(String id) async {
    // Bug#4: 삭제 확인 없이 바로 삭제 (쉬운 버그)

    // 즉시 UI에서 제거 (낙관적 업데이트)
    _todos.removeWhere((todo) => todo.id == id);
    notifyListeners();

    try {
      final baseUrl = _settingsModel?.baseUrl ?? 'http://localhost:3000/api';
      final authToken = _userModel?.authToken;
      if (authToken == null) return;

      await AuthService.deleteTodo(baseUrl, id, authToken);
    } catch (e) {
      debugPrint('Todo 삭제 오류: $e');
      // Bug#16: 서버 삭제 실패 시 UI에서 이미 삭제된 상태로 유지됨 (중간 난이도)
      // 실제로는 롤백해야 함
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

        // 즉시 UI 업데이트 (낙관적 업데이트)
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
          debugPrint('Todo 수정 오류: $e');
          // Bug#17: 서버 수정 실패 시 이전 제목으로 롤백하지 않음 (중간 난이도)
          // _todos[todoIndex].title = oldTitle; // 이 줄이 있어야 함
        }
      }
    }
    _editingTodoId = null;
    _editingText = '';
    notifyListeners();
  }

  void cancelEdit() {
    // Bug#13: 편집 취소 시 잘못된 텍스트가 저장됨 (중간 난이도)
    if (_editingTodoId != null) {
      final todoIndex = _todos.indexWhere((todo) => todo.id == _editingTodoId);
      if (todoIndex != -1) {
        _todos[todoIndex].title = _editingText; // 잘못된 로직: 취소인데 저장함
        notifyListeners();
      }
    }
    _editingTodoId = null;
    _editingText = '';
    notifyListeners();
  }

  // Bug#20: 메모리 누수 - dispose에서 정리하지 않음 (어려운 버그)
  void simulateMemoryLeak() {
    // 100개 이상일 때 성능 문제를 일으키는 코드
    if (_todos.length > 20) {
      for (int i = 0; i < 1000; i++) {
        List<int> heavyList = List.generate(10000, (index) => index);
        heavyList.sort();
      }
    }
  }
}
