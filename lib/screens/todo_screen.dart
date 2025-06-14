import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/todo_model.dart';
import '../models/user_model.dart';

class TodoScreen extends StatefulWidget {
  @override
  _TodoScreenState createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final _todoController = TextEditingController();
  final _editController = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  late List<Todo> _displayedTodos;
  bool _isInitialLoad = true;
  bool _isToggling = false; // 연속 토글 방지 플래그

  // SnackBar 중복 표시 방지를 위한 플래그들
  bool _todoSnackBarShown = false;
  bool _editSnackBarShown = false;

  @override
  void initState() {
    super.initState();
    _todoController.addListener(() => setState(() {}));
    _editController.addListener(() => setState(() {}));
    _displayedTodos = [];
  }

  @override
  void dispose() {
    _todoController.dispose();
    _editController.dispose();
    super.dispose();
  }

  // Todo 입력창 색상 결정 함수 (100글자 기준)
  Color _getTodoBorderColor() {
    final length = _todoController.text.length;
    if (length >= 100) return Colors.red;
    return Colors.grey;
  }

  // Todo 편집창 색상 결정 함수 (100글자 기준)
  Color _getEditBorderColor() {
    final length = _editController.text.length;
    if (length >= 100) return Colors.red;
    return Colors.grey;
  }

  void _showTodoLimitSnackBar() {
    if (!_todoSnackBarShown) {
      _todoSnackBarShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('タスク入力はは100文字までです'),
          duration: Duration(seconds: 2),
        ),
      );
      Future.delayed(Duration(seconds: 2), () {
        _todoSnackBarShown = false;
      });
    }
  }

  void _showEditLimitSnackBar() {
    if (!_editSnackBarShown) {
      _editSnackBarShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('タスク編集入力は100文字までです'),
          duration: Duration(seconds: 2),
        ),
      );
      Future.delayed(Duration(seconds: 2), () {
        _editSnackBarShown = false;
      });
    }
  }

  Future<void> _addTodo() async {
    // Bug#3: 空タイトル処理
    // if (_todoController.text.isEmpty) return;
    final todoModel = Provider.of<TodoModel>(context, listen: false);
    final newTodo = await todoModel.addTodo(_todoController.text);

    if (newTodo != null) {
      _displayedTodos.insert(0, newTodo);
      _listKey.currentState
          ?.insertItem(0, duration: Duration(milliseconds: 500));
    }
    _todoController.clear();
  }

  void _deleteTodo(Todo todo, int index) {
    final todoModel = Provider.of<TodoModel>(context, listen: false);
    todoModel.deleteTodo(todo.id);

    _displayedTodos.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildRemovedItem(todo, animation, 'delete'),
      duration: Duration(milliseconds: 300),
    );
  }

  Future<void> _toggleTodo(Todo todo, int index) async {
    if (_isToggling) return; // 이미 토글 애니메이션이 진행 중이면 무시

    try {
      _isToggling = true;

      final todoModel = Provider.of<TodoModel>(context, listen: false);

      // 1. 왼쪽으로 슬라이드하며 사라지는 애니메이션 실행
      _displayedTodos.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildRemovedItem(todo, animation, 'toggle'),
        duration: Duration(milliseconds: 400),
      );

      // 2. 애니메이션이 겹치지 않도록 잠시 대기
      await Future.delayed(Duration(milliseconds: 200));

      // 3. 데이터 모델 업데이트
      await todoModel.toggleTodo(todo.id);

      // 4. 정렬된 새 위치 찾기
      final newIndex = todoModel.todos.indexWhere((t) => t.id == todo.id);

      // 5. 새 위치에 왼쪽에서 나타나는 애니메이션으로 삽입
      if (newIndex != -1) {
        _displayedTodos.insert(newIndex, todo);
        _listKey.currentState
            ?.insertItem(newIndex, duration: Duration(milliseconds: 400));
      }
    } finally {
      _isToggling = false; // 애니메이션이 끝나면 플래그 해제
    }
  }

  void _showEditDialog(BuildContext context, Todo todo) {
    _editController.text = todo.title;

    final todoModel = Provider.of<TodoModel>(context, listen: false);
    todoModel.startEditing(todo.id, todo.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('タスク編集'),
        content: TextField(
          controller: _editController,
          maxLength: 100,
          decoration: InputDecoration(
            labelText: 'タスク',
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _getEditBorderColor()),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _getEditBorderColor(), width: 2),
            ),
            counterText: '',
          ),
          onChanged: (value) {
            if (value.length >= 100) {
              _showEditLimitSnackBar();
            }
            Provider.of<TodoModel>(context, listen: false)
                .updateEditingText(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Provider.of<TodoModel>(context, listen: false).cancelEdit();
              Navigator.of(context).pop();
            },
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final todoModel = Provider.of<TodoModel>(context, listen: false);
              todoModel.saveEdit();
              Navigator.of(context).pop();
            },
            child: Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(
      BuildContext context, Todo todo, int index, Animation<double> animation) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.5, 0), // 왼쪽에서 나타남
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Checkbox(
              value: todo.isCompleted,
              onChanged: (value) => _toggleTodo(todo, index),
            ),
            title: Text(
              todo.title,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                decoration: todo.isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: todo.isCompleted ? Colors.grey : Colors.black,
              ),
            ),
            subtitle: Text(
              '作成日: ${_formatDate(todo.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _showEditDialog(context, todo),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteTodo(todo, index),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRemovedItem(
      Todo todo, Animation<double> animation, String action) {
    // action: 'delete' (오른쪽), 'toggle' (왼쪽)
    final offset =
        action == 'delete' ? const Offset(0.5, 0) : const Offset(-0.5, 0);

    return FadeTransition(
      opacity: CurvedAnimation(
          parent: ReverseAnimation(animation), curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset.zero, end: const Offset(0.5, 0))
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: Card(
          // 애니메이션 중에도 동일한 모양을 유지
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Checkbox(value: todo.isCompleted, onChanged: null),
            title: Text(
              todo.title,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                decoration: todo.isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: todo.isCompleted ? Colors.grey : Colors.black,
              ),
            ),
            subtitle: Text('作成日: ${_formatDate(todo.createdAt)}'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('タスク一覧'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                Provider.of<UserModel>(context, listen: false).logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Text('ログアウト'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _todoController,
                    maxLength: 100,
                    onChanged: (value) {
                      if (value.length >= 100) {
                        _showTodoLimitSnackBar();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: '新しいタスクを入力してください',
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _getTodoBorderColor()),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: _getTodoBorderColor(), width: 2),
                      ),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTodo,
                  child: Text('追加'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<TodoModel>(
              builder: (context, todoModel, child) {
                if (todoModel.isLoading) {
                  return Center(child: CircularProgressIndicator());
                }

                if (_isInitialLoad) {
                  _displayedTodos = List.from(todoModel.todos);
                  _isInitialLoad = false;
                }

                if (_displayedTodos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'まだタスクがありません。\n上で新しいタスクを追加してみましょう！',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return AnimatedList(
                  key: _listKey,
                  initialItemCount: _displayedTodos.length,
                  itemBuilder: (context, index, animation) {
                    final todo = _displayedTodos[index];
                    return _buildTodoItem(context, todo, index, animation);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTodo,
        child: Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
