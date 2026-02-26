import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/env.dart';
import '../../../core/network/session_dio.dart';
import '../../../core/storage/app_session.dart';


class ReceiptFileService {
  static Future<Map<String, dynamic>> _sessionParams() async {
    final company = (await AppSession.company()) ?? "";
    final bu = (await AppSession.bu()) ?? "";
    final user = (await AppSession.userId()) ?? "";

    return {
      "gvCompany": company,
      "gvBu": bu,
      "gvUser": user,
      "GV_COMPANY_CD": company,
      "GV_BU_CD": bu,
      "GV_USER_ID": user,
      "USER_ID": user,
    };
  }

  // 파일 업로드
  static Future<Map<String, dynamic>> upload({
    required List<XFile> images,
    required Map<String, dynamic> params,
  }) async {
    try {
      final sp = await _sessionParams();

      final yearMonthRaw = (params['YEARMONTH'] ?? '').toString();
      final yearMonth = yearMonthRaw.replaceAll(RegExp(r'[^0-9]'), '');

      final formData = FormData.fromMap({
        ...sp,
        "PROJECT_CD": params['PROJECT_CD'],
        "DTL_REC_SEQ": params['DTL_REC_SEQ'],
        "YEARMONTH": yearMonth,
        "EXP_CD": params['EXP_CD'],
        "USER_ID": sp["GV_USER_ID"],
      });

      for (final image in images) {
        formData.files.add(
          MapEntry(
            "file",
            await MultipartFile.fromFile(
              image.path,
              filename: image.name,
            ),
          ),
        );
      }

      final res = await SessionDio.dio.post(
        "${Env.mobilePath}file/receiptUpload",
        data: formData,
      );

      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      debugPrint("영수증 업로드 에러: $e");
      rethrow;
    }
  }

  // 파일 조회
  static Future<List<Map<String, dynamic>>> fetchList({
    required String projectCd,
    required String dtlRecSeq,
    required String yearMonth,
    required String userId,
  }) async {
    final sp = await _sessionParams();

    final payload = {
      ...sp,
      "tranData": [
        {
          "_siq": "project.receipt",
          "outDs": "rtnList",

          "PROJECT_CD": projectCd,
          "DTL_REC_SEQ": dtlRecSeq,
          "YEARMONTH": yearMonth,
          "USER_ID": userId,
        }
      ]
    };

    final res = await SessionDio.dio.post(
      "${Env.mobilePath}search",
      data: payload,
    );

    final data = Map<String, dynamic>.from(res.data as Map);
    final list = (data["rtnList"] as List<dynamic>? ?? []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // 파일 다운로드
  static final Map<String, Uint8List> _imageCache = {};

  static Future<Uint8List> downloadBytes({
    required String projectCd,
    required String dtlRecSeq,
    required String fileSeq,
  }) async {
    final cacheKey = "$projectCd|$dtlRecSeq|$fileSeq";

    final cached = _imageCache[cacheKey];
    if (cached != null) return cached;

    final sp = await _sessionParams();
    final formData = FormData.fromMap({
      ...sp,
      "PROJECT_CD": projectCd,
      "DTL_REC_SEQ": dtlRecSeq,
      "FILE_SEQ": [fileSeq],
    });

    final res = await SessionDio.dio.post(
      "${Env.mobilePath}file/receiptDownload",
      data: formData,
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = Uint8List.fromList(res.data as List<int>);
    _imageCache[cacheKey] = bytes;
    return bytes;
  }

  // 파일 삭제
  static Future<Map<String, dynamic>> delete({
    required String projectCd,
    required String dtlRecSeq,
    required String fileSeq,
  }) async {
    final sp = await _sessionParams();

    final payload = {
      ...sp,
      "PROJECT_CD": projectCd,
      "DTL_REC_SEQ": dtlRecSeq,
      "FILE_SEQ": fileSeq,
    };

    final res = await SessionDio.dio.post(
      "${Env.mobilePath}file/receiptDelete",
      data: payload,
    );

    _imageCache.removeWhere((k, v) => k.contains("|$dtlRecSeq|$fileSeq"));

    return Map<String, dynamic>.from(res.data as Map);
  }

  // 모든 캐시 전체 삭제
  static void clearCache() {
    _imageCache.clear();
  }
}