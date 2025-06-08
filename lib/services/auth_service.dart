import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  // Static 메서드들 추가 (UserModel에서 사용)
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      // Bug#18: 비밀번호를 평문으로 전송 (어려운 버그 - 보안)
      final response = await http.post(
        Uri.parse('https://api.example.com/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password, // 실제로는 해시되어야 함
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '로그인 성공'};
      } else {
        // Bug#19: 서버 에러 메시지를 그대로 노출 (어려운 버그 - 보안)
        return {'success': false, 'message': '로그인 실패'};
      }
    } catch (e) {
      // Bug#20: 네트워크 에러 시 상세한 시스템 정보 노출 (어려운 버그 - 보안)
      // 이 부분에서 Bug#11이 발생: exception을 던지면 UserModel에서 catch하여 무한 로딩
      throw Exception('네트워크 오류: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> signup(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.example.com/register'),
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
        return {'success': false, 'message': '회원가입 실패'};
      }
    } catch (e) {
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
      // Bug#20: 네트워크 에러 시 상세한 시스템 정보 노출 (어려운 버그 - 보안)
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

  Future<List<Map<String, dynamic>>> getTodos(String userId) async {
    try {
      // Bug#21: 사용자 ID를 URL 파라미터로 노출 (어려운 버그 - 보안 취약점)
      final response = await http.get(
        Uri.parse('$baseUrl/todos?userId=$userId'),
        headers: {
          'Content-Type': 'application/json',
          // Bug#22: 인증 토큰 없이 요청 (어려운 버그 - 보안)
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

  Future<Map<String, dynamic>> createTodo(String userId, String title) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/todos'),
        headers: {
          'Content-Type': 'application/json',
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
}
