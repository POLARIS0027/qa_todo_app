import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../services/network_service.dart';
import '../services/app_services.dart';

class AuthService {
  // 패스워드 해시화 함수
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Staticメソッド追加（UserModelで使用）
  static Future<Map<String, dynamic>> login(
      String baseUrl, String email, String password) async {
    final networkService = getIt<NetworkService>();
    try {
      // Bug#18: パスワードを平文で送信（難易度：高・セキュリティ）
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: networkService.defaultHeaders,
            body: jsonEncode({
              'email': email,
              'password': hashPassword(password),
            }),
          )
          .timeout(Duration(seconds: networkService.timeout));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'ログイン成功',
          'token': responseData['token']
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          // 서버에서 보낸 "error:" 뒤의 메시지만 추출
          String errorMessage = errorData['error'] ?? 'ログイン失敗';
          if (errorMessage.contains('error:')) {
            errorMessage = errorMessage.split('error:').last.trim();
          }
          return {'success': false, 'message': errorMessage};
        } catch (e) {
          return {'success': false, 'message': 'ログイン失敗'};
        }
      }
    } catch (e) {
      // この部分でBug#10発生: exceptionを投げるとUserModelでcatchされ無限ローディング
      throw Exception('ネットワークエラー: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> signup(String baseUrl, String email,
      String password, String confirmPassword) async {
    final networkService = getIt<NetworkService>();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: networkService.defaultHeaders,
            body: jsonEncode({
              'email': email,
              'password': hashPassword(password),
            }),
          )
          .timeout(Duration(seconds: networkService.timeout));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': '会員登録成功'};
      } else {
        debugPrint('会員登録失敗 - ステータスコード: ${response.statusCode}');
        debugPrint('会員登録失敗 - 応答: ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          // 서버에서 보낸 "error:" 뒤의 메시지만 추출
          String errorMessage = errorData['error'] ?? '회員登録에 실패했습니다';
          if (errorMessage.contains('error:')) {
            errorMessage = errorMessage.split('error:').last.trim();
          }
          return {'success': false, 'message': errorMessage};
        } catch (e) {
          return {'success': false, 'message': '회員登록에 실패했습니다'};
        }
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
    final networkService = getIt<NetworkService>();
    try {
      // 現在はトークンベース認証を使用（以前のURLパラメータ方式から改善）
      final response = await http
          .get(
            Uri.parse('$baseUrl/todos?userId=$userId'),
            headers: networkService.authHeaders(authToken),
          )
          .timeout(Duration(seconds: networkService.timeout));

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
    final networkService = getIt<NetworkService>();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/todos'),
        headers: networkService.authHeaders(authToken),
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
    final networkService = getIt<NetworkService>();
    try {
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (isCompleted != null) body['isCompleted'] = isCompleted;

      final response = await http
          .put(
            Uri.parse('$baseUrl/todos/$todoId'),
            headers: networkService.authHeaders(authToken),
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: networkService.timeout));

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
    final networkService = getIt<NetworkService>();
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/todos/$todoId'),
            headers: networkService.authHeaders(authToken),
          )
          .timeout(Duration(seconds: networkService.timeout));

      if (response.statusCode != 200) {
        throw Exception('Todo削除失敗');
      }
    } catch (e) {
      throw Exception('ネットワークエラー: ${e.toString()}');
    }
  }
}
