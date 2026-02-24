import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../service/auth_service.dart';
import '../../../core/storage/app_session.dart';
import '../../../core/network/session_dio.dart';

class AuthController {
  /// 세션/리다이렉트 기반 로그인 성공 여부를 302 Location으로 판정
  static Future<void> login({
    required String userId,
    required String userPw,
  }) async {
    if (userId.trim().isEmpty) throw Exception("사번을 입력해주세요.");
    if (userPw.isEmpty) throw Exception("비밀번호를 입력해주세요.");

    final res = await AuthService.login(
      userId: userId.trim(),
      userPw: userPw,
    );

    final location = res.headers.value('location') ?? '';
    final bodyText = (res.data ?? '').toString();
    String message = res.data["message"] ?? "로그인 실패";
    message = message.replaceAll("<br>", "\n");

    final isFail =
      location.contains('error=') ||
      bodyText.contains('authentication_failed') ||
      bodyText.contains('세션만료') || 
      bodyText.contains('errCode') ||
      bodyText.contains('success: false');

    if (isFail) {
      throw Exception(message);
    }

    await AppSession.save(
      userId: res.data["userId"].toString(),
      userNm: res.data["userNm"].toString(),
      langCd: res.data["langCd"].toString(),
      companyList: res.data["companyList"] ?? [],
      buList: res.data["buList"] ?? [],
    );

    // ✅ 성공
    return;
  }
}
