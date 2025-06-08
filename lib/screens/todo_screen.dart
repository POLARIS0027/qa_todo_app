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

    // Bug#19: 중복 클릭 방지 없음 - 빠른 연속 클릭 시 중복 생성 (어려운 버그)
    await todoModel.addTodo(title);
    _todoController.clear();
  }

  void _showEditDialog(BuildContext context, Todo todo) {
    _editController.text = todo.title;

    // Bug#13 구현을 위해 편집 시작 시점에 startEditing 호출
    final todoModel = Provider.of<TodoModel>(context, listen: false);
    todoModel.startEditing(todo.id, todo.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('할일 수정'),
        content: TextField(
          controller: _editController,
          decoration: InputDecoration(
            labelText: '할일',
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
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final todoModel = Provider.of<TodoModel>(context, listen: false);
              todoModel.saveEdit();
              Navigator.of(context).pop();
            },
            child: Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('할일 목록'),
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
                child: Text('로그아웃'),
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
                    decoration: InputDecoration(
                      labelText: '새로운 할일을 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTodo,
                  child: Text('추가'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<TodoModel>(
              builder: (context, todoModel, child) {
                // Bug#20: 성능 문제 시뮬레이션 호출 (어려운 버그)
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
                          '아직 할일이 없습니다.\n위에서 새로운 할일을 추가해보세요!',
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
                          // Bug#14: 17글자 이상 제목 시 UI 오버플로우 (중간 난이도)
                          // overflow: TextOverflow.ellipsis, 를 의도적으로 제거하여 텍스트가 넘침
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            // Bug#5: 완료된 항목이 취소선 대신 굵은 글씨로 표시 (쉬운 버그)
                            fontWeight: todo.isCompleted
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color:
                                todo.isCompleted ? Colors.grey : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          '생성일: ${_formatDate(todo.createdAt)}',
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
                                // Bug#4: 삭제 확인 다이얼로그 없이 바로 삭제 (쉬운 버그)
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
      // Bug#6: FloatingActionButton과 하단 추가 버튼이 중복으로 존재 (쉬운 버그)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 같은 기능을 하는 버튼이 두 개 (위의 추가 버튼과 동일)
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
