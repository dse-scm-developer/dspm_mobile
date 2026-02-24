import 'package:dio/dio.dart';
import '../../../core/config/env.dart';
import '../../../core/network/session_dio.dart';
import 'tran_data.dart';
import 'package:dspm_mobile/core/storage/app_session.dart';

class BizService {

  /// ✅ 모든 API payload에 공통으로 넣을 세션 파라미터
  static Future<Map<String, dynamic>> _sessionParams() async {
    final company = (await AppSession.company()) ?? "";
    final bu = (await AppSession.bu()) ?? "";
    final user = (await AppSession.userId()) ?? "";

    return {
      "gvCompany": company,
      "gvBu": bu,
      "gvUser": user,

      // 서버/기존 코드에서 쓰는 alias들
      "GV_COMPANY_CD": company,
      "GV_BU_CD": bu,
      "GV_USER_ID": user,
      "USER_ID": user,
    };
  }

  static Future<List<Map<String, dynamic>>> search({
    required String siq,
    required String outDs,
    Map<String, dynamic>? params,
  }) async {
    final sp = await _sessionParams();

    final payload = {
      ...sp,
      "tranData": [
        {
          "_siq": siq,
          "outDs": outDs,
          ...?params,
        }
      ]
    };

    final Response res =
        await SessionDio.dio.post(Env.mobilePath + "search", data: payload);

    final data = Map<String, dynamic>.from(res.data as Map);
    final list = (data[outDs] as List<dynamic>? ?? []);

    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, List<Map<String, dynamic>>>> searchList({
    required List<TranData> tranList,
  }) async {
    final sp = await _sessionParams();

    final payload = {
      ...sp,
      "tranData": tranList.map((e) => e.toJson()).toList(),
    };

    final Response res =
        await SessionDio.dio.post(Env.mobilePath + "search", data: payload);

    final data = Map<String, dynamic>.from(res.data as Map);

    final Map<String, List<Map<String, dynamic>>> result = {};

    for (final tran in tranList) {
      final list = (data[tran.outDs] as List<dynamic>? ?? []);
      result[tran.outDs] =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return result;
  }

  static Future<int> save({
    required String siq,
    required String outDs,
    required List<Map<String, dynamic>> rows,
    Map<String, dynamic>? extraParams,
  }) async {
    final sp = await _sessionParams();

    final payload = {
      ...sp,
      ...?extraParams,
      "tranData": [
        {
          "_siq": siq,
          "outDs": outDs,
          "grdData": rows,
        }
      ]
    };

    final Response res =
        await SessionDio.dio.post(Env.mobilePath + "save", data: payload);

    final data = Map<String, dynamic>.from(res.data as Map);
    return int.tryParse((data[outDs] ?? "0").toString()) ?? 0;
  }

  static Future<int> saveUpdate({
    required String siq,
    required String outDs,
    required List<Map<String, dynamic>> rows,
    Map<String, dynamic>? extraParams,
  }) async {
    final sp = await _sessionParams();

    final payload = {
      ...sp,
      ...?extraParams,
      "tranData": [
        {
          "_siq": siq,
          "outDs": outDs,
          "grdData": rows,
        }
      ]
    };

    final Response res =
        await SessionDio.dio.post(Env.mobilePath + "saveUpdate", data: payload);

    final data = Map<String, dynamic>.from(res.data as Map);
    return int.tryParse((data[outDs] ?? "0").toString()) ?? 0;
  }

  /// ✅ gvCompany/gvBu/gvUser 파라미터 제거 (AppSession에서 자동 주입)
  static Future<Map<String, dynamic>> saveVacation({
    required String siq,
    required String outDs,
    required List<Map<String, dynamic>> rows,
    Map<String, dynamic>? extraParams,
  }) async {
    final sp = await _sessionParams();

    final payload = {
      ...sp,
      ...?extraParams,
      "tranData": [
        {
          "_siq": siq,
          "outDs": outDs,
          "grdData": rows,
          "custDupChkYn": {"insert": "Y"},
        }
      ]
    };

    final Response res =
        await SessionDio.dio.post(Env.mobilePath + "vacation/save", data: payload);

    return Map<String, dynamic>.from(res.data as Map);
  }
}