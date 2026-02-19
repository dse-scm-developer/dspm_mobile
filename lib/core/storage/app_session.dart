import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  static const _keyUserId = "user_id";
  static const _keyUserNm = "user_nm";
  static const _keyLangCd = "lang_cd";
  static const _keyCompanyList = "company_list";
  static const _keyBuList = "bu_list";

  /// 저장
  static Future<void> save({
    required String userId,
    required String userNm,
    required String langCd,
    required List<dynamic> companyList,
    required List<dynamic> buList,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserNm, userNm);
    await prefs.setString(_keyLangCd, langCd);
    await prefs.setString(_keyCompanyList, jsonEncode(companyList));
    await prefs.setString(_keyBuList, jsonEncode(buList));
  }

  static Future<String?> userId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<String?> userNm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserNm);
  }

  static Future<String?> langCd() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLangCd);
  }

  static Future<List<dynamic>> companyList() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyCompanyList);
    if (value == null) return [];
    return jsonDecode(value);
  }

  static Future<List<dynamic>> buList() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyBuList);
    if (value == null) return [];
    return jsonDecode(value);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
