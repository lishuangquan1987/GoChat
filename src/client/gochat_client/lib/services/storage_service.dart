import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static SharedPreferences? _prefs;

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token 管理（使用安全存储）
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // 用户数据管理
  static Future<void> saveUser(Map<String, dynamic> user) async {
    await _prefs?.setString(_userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final userStr = _prefs?.getString(_userKey);
    if (userStr != null) {
      return jsonDecode(userStr) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> deleteUser() async {
    await _prefs?.remove(_userKey);
  }

  // 清除所有数据
  static Future<void> clearAll() async {
    await _storage.deleteAll();
    await _prefs?.clear();
  }

  // 通用键值存储
  static Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  static Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }
}
