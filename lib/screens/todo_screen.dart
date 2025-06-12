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

  // SnackBar 중복 표시 방지를 위한 플래그들
  bool _todoSnackBarShown = false;
  bool _editSnackBarShown = false;

  @override
  void initState() {
    super.initState();
    // 실시간 UI 업데이트를 위한 리스너 추가
    _todoController.addListener(() => setState(() {}));
    _editController.addListener(() => setState(() {}));
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

  // SnackBar 표시 함수들
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
    final todoModel = Provider.of<TodoModel>(context, listen: false);
    final title = _todoController.text;

    // Bug#18: 連続クリック防止なし - 高速連打で重複作成（難易度：高）
    await todoModel.addTodo(title);
    _todoController.clear();
  }

  void _showEditDialog(BuildContext context, Todo todo) {
    _editController.text = todo.title;

    // Bug#13: 編集開始時にstartEditingを呼び出す
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
            counterText: '', // 카운터 숨기기
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
          // Bug#7: 画面回転時にUIレイアウトが崩れる（易）
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: MediaQuery.of(context).orientation == Orientation.landscape
                ? // 横向き時のみ固定幅で問題発生
                Row(
                    children: [
                      Container(
                        width: 400, // 横向きで画面を超える幅
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
                              borderSide:
                                  BorderSide(color: _getTodoBorderColor()),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: _getTodoBorderColor(), width: 2),
                            ),
                            counterText: '', // 카운터 숨기기
                          ),
                          onSubmitted: (_) => _addTodo(),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        width: 80,
                        child: ElevatedButton(
                          onPressed: _addTodo,
                          child: Text('追加'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        width: 80,
                        child: ElevatedButton(
                          onPressed: () {},
                          child: Text('設定'),
                        ),
                      ),
                    ],
                  )
                : // 縦向き時は正常なレスポンシブレイアウト
                Row(
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
                              borderSide:
                                  BorderSide(color: _getTodoBorderColor()),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: _getTodoBorderColor(), width: 2),
                            ),
                            counterText: '', // 카운터 숨기기
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
                // Bug#19: パフォーマンス問題シミュレーション呼び出し（難易度：高）
                todoModel.simulateMemoryLeak();

                if (todoModel.isLoading) {
                  return Center(child: CircularProgressIndicator());
                }

                if (todoModel.todos.isEmpty) {
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

                return ListView.builder(
                  itemCount: todoModel.todos.length,
                  itemBuilder: (context, index) {
                    final todo = todoModel.todos[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Checkbox(
                          value: todo.isCompleted,
                          onChanged: (value) {
                            todoModel.toggleTodo(todo.id);
                          },
                        ),
                        title: Text(
                          todo.title,
                          // Bug#14: 17文字以上のタイトルでUIオーバーフロー（中級）
                          // overflow: TextOverflow.ellipsis, を意図的に削除しテキストが溢れる
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            // Bug#5: 完了項目が取り消し線ではなく太字で表示（易）
                            fontWeight: todo.isCompleted
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color:
                                todo.isCompleted ? Colors.grey : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          '作成日: ${_formatDate(todo.createdAt)}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                              onPressed: () {
                                // Bug#4: 削除確認ダイアログなしで即削除（易）
                                todoModel.deleteTodo(todo.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // Bug#6: FloatingActionButtonと下部追加ボタンが重複して存在（易）
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 同じ機能のボタンが2つ（上の追加ボタンと同じ）
          _addTodo();
        },
        child: Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
