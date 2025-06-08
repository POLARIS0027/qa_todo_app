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

  @override
  void dispose() {
    _todoController.dispose();
    _editController.dispose();
    super.dispose();
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
          decoration: InputDecoration(
            labelText: 'タスク',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
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
                          decoration: InputDecoration(
                            labelText: '新しいタスクを入力してください',
                            border: OutlineInputBorder(),
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
                          decoration: InputDecoration(
                            labelText: '新しいタスクを入力してください',
                            border: OutlineInputBorder(),
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
