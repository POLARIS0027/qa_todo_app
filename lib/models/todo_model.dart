import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  List<Todo> get todos => _todos;
  bool get isLoading => _isLoading;
  String? get editingTodoId => _editingTodoId;
  String get editingText => _editingText;

  TodoModel() {
    loadTodos();
  }

  Future<void> loadTodos() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final todosJson = prefs.getString('todos');

    if (todosJson != null) {
      final List<dynamic> todosList = json.decode(todosJson);
      _todos = todosList.map((json) => Todo.fromJson(json)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = json.encode(_todos.map((todo) => todo.toJson()).toList());
    await prefs.setString('todos', todosJson);
  }

  Future<void> addTodo(String title) async {
    // Bug#3: 빈 제목 체크하지만 공백만 있는 경우는 허용하고, 빈 제목일 때 더미 텍스트 추가 (쉬운 버그)
    if (title.isEmpty) {
      title = "새로운 할일";
    }

    final todo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
    );

    _todos.add(todo);

    // Bug#14: 동시에 빠르게 추가할 때 중복 ID 생성 가능 (어려운 버그)
    await Future.delayed(Duration(milliseconds: 100)); // 의도적 지연

    await saveTodos();
    notifyListeners();
  }

  Future<void> toggleTodo(String id) async {
    final todoIndex = _todos.indexWhere((todo) => todo.id == id);
    if (todoIndex != -1) {
      _todos[todoIndex].isCompleted = !_todos[todoIndex].isCompleted;

      // Bug#12: 완료 상태는 저장하지 않음 (중간 난이도) - 의도적으로 saveTodos() 호출 안함
      notifyListeners();
    }
  }

  Future<void> deleteTodo(String id) async {
    // Bug#4: 삭제 확인 없이 바로 삭제 (쉬운 버그)
    _todos.removeWhere((todo) => todo.id == id);
    await saveTodos();
    notifyListeners();
  }

  void startEditing(String id, String currentTitle) {
    _editingTodoId = id;
    _editingText = currentTitle;
    notifyListeners();
  }

  void updateEditingText(String text) {
    _editingText = text;
    // Bug#16: notifyListeners() 호출 안함 - UI 업데이트 안됨 (어려운 버그)
  }

  Future<void> saveEdit() async {
    if (_editingTodoId != null) {
      final todoIndex = _todos.indexWhere((todo) => todo.id == _editingTodoId);
      if (todoIndex != -1) {
        _todos[todoIndex].title = _editingText;
        await saveTodos();
      }
    }
    _editingTodoId = null;
    _editingText = '';
    notifyListeners();
  }

  void cancelEdit() async {
    // Bug#13: 다른 Todo를 선택했을 때 이전 편집 내용이 적용됨 (중간 난이도)
    if (_editingTodoId != null) {
      final todoIndex = _todos.indexWhere((todo) => todo.id == _editingTodoId);
      if (todoIndex != -1) {
        _todos[todoIndex].title = _editingText; // 잘못된 로직
        await saveTodos();
      }
    }
    _editingTodoId = null;
    _editingText = '';
    notifyListeners();
  }

  // Bug#15: 메모리 누수 - dispose에서 정리하지 않음 (어려운 버그)
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
