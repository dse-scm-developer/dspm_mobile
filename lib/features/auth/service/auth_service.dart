import 'package:dio/dio.dart';
import '../../../core/config/env.dart';
import '../../../core/network/session_dio.dart';

class AuthService {
  /// 웹 로그인 form이 보내는 파라미터 이름에 맞춰서 수정
  /// (웹에서 userId/userPw 쓰는지, username/password 쓰는지 실제 요청 확인 필요)
  static const String keyUserId = "username";
  static const String keyUserPw = "password";

  static Future<Response> login({
    required String userId,
    required String userPw,
  }) async {

    return await SessionDio.dio.post(
      Env.loginPath,
      data: {
        keyUserId: userId,
        keyUserPw: userPw,
      },
      options: Options(
        contentType: Headers.jsonContentType,
      ),
    );
  }
}
