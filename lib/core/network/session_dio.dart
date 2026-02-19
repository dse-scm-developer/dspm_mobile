import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

// ✅ Web에서만 필요
import 'package:dio/browser.dart';

// ✅ Mobile에서만 필요
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class SessionDio {
  SessionDio._();

  static final Dio dio = _create();

  static Dio _create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        followRedirects: false,
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    if (kIsWeb) {
      // ✅ Web: 브라우저 쿠키 사용 (JSESSIONID 저장/전송)
      dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
    } else {
      // ✅ Mobile: CookieJar로 쿠키 저장/전송
      final jar = CookieJar();
      dio.interceptors.add(CookieManager(jar));
    }

    return dio;
  }
}
