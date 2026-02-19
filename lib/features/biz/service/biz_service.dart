import 'package:dio/dio.dart';
import '../../../core/config/env.dart';
import '../../../core/network/session_dio.dart';
 
class BizService {

  static Future<List<Map<String, dynamic>>> searchList({
    required String siq,
    required String outDs,
    Map<String, dynamic>? params,
  }) async {
    final payload = {
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
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<int> save({
    required String siq,
    required String outDs,
    required List<Map<String, dynamic>> rows,
    Map<String, dynamic>? extraParams,
  }) async {
    final payload = {
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
    final payload = {
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
}