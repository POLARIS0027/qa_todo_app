import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  // Static 메서드들 추가 (UserModel에서 사용)
  static Future<Map<String, dynamic>> login(
      String baseUrl, String email, String password) async {
    try {
      // Bug#18: 비밀번호를 평문으로 전송 (어려운 버그 - 보안)
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password, // 실제로는 해시되어야 함
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': '로그인 성공',
          'token': responseData['token']
        };
      } else {
        // Bug#19: 서버 에러 메시지를 그대로 노출 (어려운 버그 - 보안)
        try {
          final errorData = jsonDecode(response.body);
          return {'success': false, 'message': errorData['error'] ?? '로그인 실패'};
        } catch (e) {
          return {'success': false, 'message': '서버 응답 파싱 실패: ${response.body}'};
        }
      }
    } catch (e) {
      // 이 부분에서 Bug#10이 발생: exception을 던지면 UserModel에서 catch하여 무한 로딩
      throw Exception('네트워크 오류: ${e.toString()}');
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
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': '회원가입 성공'};
      } else {
        debugPrint('회원가입 실패 - 상태코드: ${response.statusCode}');
        debugPrint('회원가입 실패 - 응답: ${response.body}');
        return {'success': false, 'message': '회원가입 실패: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('회원가입 네트워크 오류: $e');
      throw Exception('네트워크 오류: ${e.toString()}');
    }
  }

  // Instance 메서드들 (기존)
  Future<Map<String, dynamic>> loginInstance(
      String email, String password) async {
    try {
      // Bug#18: 비밀번호를 평문으로 전송 (어려운 버그 - 보안)
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password, // 실제로는 해시되어야 함
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // Bug#19: 서버 에러 메시지를 그대로 노출 (어려운 버그 - 보안)
        final errorBody = jsonDecode(response.body);
        throw Exception('로그인 실패: ${errorBody['message']}');
      }
    } catch (e) {
      throw Exception('네트워크 오류: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
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
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('회원가입 실패: ${errorBody['message']}');
      }
    } catch (e) {
      throw Exception('네트워크 오류: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> getTodos(
      String baseUrl, String userId, String authToken) async {
    try {
      // 현재는 토큰 기반 인증 사용 (이전 URL 파라미터 방식에서 개선됨)
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
        throw Exception('Todo 목록 가져오기 실패');
      }
    } catch (e) {
      throw Exception('네트워크 오류: ${e.toString()}');
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
        throw Exception('Todo 생성 실패');
      }
    } catch (e) {
      throw Exception('네트워크 오류: ${e.toString()}');
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
        throw Exception('Todo 수정 실패');
      }
    } catch (e) {
      throw Exception('네트워크 오류: ${e.toString()}');
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
        throw Exception('Todo 삭제 실패');
      }
    } catch (e) {
      throw Exception('네트워크 오류: ${e.toString()}');
    }
  }
}
