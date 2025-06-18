import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  // Staticメソッド追加（UserModelで使用）
  static Future<Map<String, dynamic>> login(
      String baseUrl, String email, String password) async {
    try {
      // Bug#18: パスワードを平文で送信（難易度：高・セキュリティ）
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password, // 本来はハッシュ化すべき
        }),
      ); // 

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'ログイン成功',
          'token': responseData['token']
        };
      } else {
        // Bug#19: サーバーエラーメッセージをそのまま表示（難易度：高・セキュリティ）
        try {
          final errorData = jsonDecode(response.body);
          return {'success': false, 'message': errorData['error'] ?? 'ログイン失敗'};
        } catch (e) {
          return {'success': false, 'message': 'サーバー応答パース失敗: ${response.body}'};
        }
      }
    } catch (e) {
      // この部分でBug#10発生: exceptionを投げるとUserModelでcatchされ無限ローディング
      throw Exception('ネットワークエラー: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> signup(String baseUrl, String email,
      String password, String confirmPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': '会員登録成功'};
      } else {
        debugPrint('会員登録失敗 - ステータスコード: ${response.statusCode}');
        debugPrint('会員登録失敗 - 応答: ${response.body}');
        return {'success': false, 'message': '${response.statusCode}, ${response.headers}, ${response.body}'};
      }
    } 
    // エラー文言をサーバーからもらったまま返す。
    // on TimeoutException catch (_) {
    //   debugPrint('会員登録Timeoutエラー');
    //   return {'success': false, 'message': 'サーバー接続エラー: Timeoutしました。'};
    // }
     catch (e) {
      debugPrint('会員登録ネットワークエラー: $e');
      throw Exception('ネットワークエラー: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> getTodos(
      String baseUrl, String userId, String authToken) async {
    try {
      // 現在はトークンベース認証を使用（以前のURLパラメータ方式から改善）
      final response = await http.get(
        Uri.parse('$baseUrl/todos?userId=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Todoリスト取得失敗');
      }
    } catch (e) {
      throw Exception('ネットワークエラー: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> createTodo(
      String baseUrl, String userId, String title, String authToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/todos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'userId': userId,
          'title': title,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Todo作成失敗');
      }
    } catch (e) {
      throw Exception('ネットワークエラー: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> updateTodo(
      String baseUrl, String todoId, String authToken,
      {String? title, bool? isCompleted}) async {
    try {
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (isCompleted != null) body['isCompleted'] = isCompleted;

      final response = await http.put(
        Uri.parse('$baseUrl/todos/$todoId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Todo編集失敗');
      }
    } catch (e) {
      throw Exception('ネットワークエラー: ${e.toString()}');
    }
  }

  static Future<void> deleteTodo(
      String baseUrl, String todoId, String authToken) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/todos/$todoId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Todo削除失敗');
      }
    } catch (e) {
      throw Exception('ネットワークエラー: ${e.toString()}');
    }
  }
}
