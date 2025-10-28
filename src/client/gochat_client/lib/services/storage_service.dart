import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static SharedPreferences? _prefs;
  static String? _currentUserId;
  static String? _userDataDir;

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _currentUserIdKey = 'current_user_id';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // 初始化用户数据目录
    await _initUserDataDirectory();

    // 获取当前用户ID（如果存在）
    _currentUserId = _prefs?.getString(_currentUserIdKey);
  }

  static Future<void> _initUserDataDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _userDataDir = '${appDir.path}/GoChat';

      // 确保目录存在
      final dir = Directory(_userDataDir!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      print('Failed to initialize user data directory: $e');
      _userDataDir = null;
    }
  }

  static String _getUserSpecificKey(String key) {
    if (_currentUserId != null) {
      return '${_currentUserId}_$key';
    }
    return key;
  }

  static Future<void> setCurrentUser(String userId) async {
    _currentUserId = userId;
    await _prefs?.setString(_currentUserIdKey, userId);
  }

  static String? getCurrentUserId() {
    return _currentUserId;
  }

  static Future<String?> getUserDataPath() async {
    if (_userDataDir == null || _currentUserId == null) {
      return null;
    }

    final userDir = '$_userDataDir/$_currentUserId';
    final dir = Directory(userDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return userDir;
  }

  // Token 管理（使用安全存储，支持多用户）
  static Future<void> saveToken(String token) async {
    final key = _getUserSpecificKey(_tokenKey);
    await _storage.write(key: key, value: token);
  }

  static Future<String?> getToken() async {
    final key = _getUserSpecificKey(_tokenKey);
    // 先读带用户前缀的 key（新版本）
    String? token = await _storage.read(key: key);
    if (token != null && token.isNotEmpty) {
      return token;
    }
    // 兼容旧版本：尝试读取未带用户前缀的历史 key
    try {
      final legacy = await _storage.read(key: _tokenKey);
      return legacy;
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteToken() async {
    final key = _getUserSpecificKey(_tokenKey);
    await _storage.delete(key: key);
  }

  // 用户数据管理（支持多用户）
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final key = _getUserSpecificKey(_userKey);
    await _prefs?.setString(key, jsonEncode(user));

    // 同时保存到用户专用目录
    await _saveUserToFile(user);
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final key = _getUserSpecificKey(_userKey);
    final userStr = _prefs?.getString(key);
    if (userStr != null) {
      return jsonDecode(userStr) as Map<String, dynamic>;
    }

    // 尝试从文件读取
    return await _getUserFromFile();
  }

  static Future<void> deleteUser() async {
    final key = _getUserSpecificKey(_userKey);
    await _prefs?.remove(key);

    // 删除用户文件
    await _deleteUserFile();
  }

  static Future<void> _saveUserToFile(Map<String, dynamic> user) async {
    try {
      final userDataPath = await getUserDataPath();
      if (userDataPath != null) {
        final file = File('$userDataPath/user.json');
        await file.writeAsString(jsonEncode(user));
      }
    } catch (e) {
      print('Failed to save user to file: $e');
    }
  }

  static Future<Map<String, dynamic>?> _getUserFromFile() async {
    try {
      final userDataPath = await getUserDataPath();
      if (userDataPath != null) {
        final file = File('$userDataPath/user.json');
        if (await file.exists()) {
          final content = await file.readAsString();
          return jsonDecode(content) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print('Failed to read user from file: $e');
    }
    return null;
  }

  static Future<void> _deleteUserFile() async {
    try {
      final userDataPath = await getUserDataPath();
      if (userDataPath != null) {
        final file = File('$userDataPath/user.json');
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Failed to delete user file: $e');
    }
  }

  // 清除当前用户数据
  static Future<void> clearAll() async {
    if (_currentUserId != null) {
      // 只清除当前用户的数据
      await deleteToken();
      await deleteUser();

      // 清除当前用户的所有SharedPreferences数据
      final keys = _prefs?.getKeys() ?? <String>{};
      for (final key in keys) {
        if (key.startsWith('${_currentUserId}_')) {
          await _prefs?.remove(key);
        }
      }

      // 清除用户数据目录
      await _clearUserDataDirectory();
    }
  }

  static Future<void> _clearUserDataDirectory() async {
    try {
      final userDataPath = await getUserDataPath();
      if (userDataPath != null) {
        final dir = Directory(userDataPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (e) {
      print('Failed to clear user data directory: $e');
    }
  }

  // 获取所有已登录过的用户列表
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final users = <Map<String, dynamic>>[];

    try {
      if (_userDataDir != null) {
        final mainDir = Directory(_userDataDir!);
        if (await mainDir.exists()) {
          await for (final entity in mainDir.list()) {
            if (entity is Directory) {
              final userFile = File('${entity.path}/user.json');
              if (await userFile.exists()) {
                try {
                  final content = await userFile.readAsString();
                  final userData = jsonDecode(content) as Map<String, dynamic>;
                  users.add(userData);
                } catch (e) {
                  print('Failed to read user data from ${entity.path}: $e');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Failed to get all users: $e');
    }

    return users;
  }

  // 切换到指定用户
  static Future<bool> switchToUser(String userId) async {
    try {
      _currentUserId = userId;
      await _prefs?.setString(_currentUserIdKey, userId);
      return true;
    } catch (e) {
      print('Failed to switch to user $userId: $e');
      return false;
    }
  }

  // 通用键值存储（支持用户隔离）
  static Future<void> setString(String key, String value) async {
    final userKey = _getUserSpecificKey(key);
    await _prefs?.setString(userKey, value);
  }

  static Future<String?> getString(String key) async {
    final userKey = _getUserSpecificKey(key);
    return _prefs?.getString(userKey);
  }

  static Future<void> setBool(String key, bool value) async {
    final userKey = _getUserSpecificKey(key);
    await _prefs?.setBool(userKey, value);
  }

  static Future<bool?> getBool(String key) async {
    final userKey = _getUserSpecificKey(key);
    return _prefs?.getBool(userKey);
  }

  static Future<void> setDouble(String key, double value) async {
    final userKey = _getUserSpecificKey(key);
    await _prefs?.setDouble(userKey, value);
  }

  static Future<double?> getDouble(String key) async {
    final userKey = _getUserSpecificKey(key);
    return _prefs?.getDouble(userKey);
  }

  static Future<void> setInt(String key, int value) async {
    final userKey = _getUserSpecificKey(key);
    await _prefs?.setInt(userKey, value);
  }

  static Future<int?> getInt(String key) async {
    final userKey = _getUserSpecificKey(key);
    return _prefs?.getInt(userKey);
  }

  static Future<void> remove(String key) async {
    final userKey = _getUserSpecificKey(key);
    await _prefs?.remove(userKey);
  }

  // 保存会话数据到文件
  static Future<void> saveConversations(
      List<Map<String, dynamic>> conversations) async {
    try {
      final userDataPath = await getUserDataPath();
      if (userDataPath != null) {
        final file = File('$userDataPath/conversations.json');
        await file.writeAsString(jsonEncode(conversations));
      }
    } catch (e) {
      print('Failed to save conversations: $e');
    }
  }

  // 从文件读取会话数据
  static Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final userDataPath = await getUserDataPath();
      if (userDataPath != null) {
        final file = File('$userDataPath/conversations.json');
        if (await file.exists()) {
          final content = await file.readAsString();
          final List<dynamic> data = jsonDecode(content);
          return data.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      print('Failed to read conversations: $e');
    }
    return [];
  }

  // 保存消息数据到文件
  static Future<void> saveMessages(
      String conversationId, List<Map<String, dynamic>> messages) async {
    try {
      final userDataPath = await getUserDataPath();
      if (userDataPath != null) {
        final messagesDir = Directory('$userDataPath/messages');
        if (!await messagesDir.exists()) {
          await messagesDir.create(recursive: true);
        }

        final file = File('$userDataPath/messages/$conversationId.json');
        await file.writeAsString(jsonEncode(messages));
      }
    } catch (e) {
      print('Failed to save messages for $conversationId: $e');
    }
  }

  // 从文件读取消息数据
  static Future<List<Map<String, dynamic>>> getMessages(
      String conversationId) async {
    try {
      final userDataPath = await getUserDataPath();
      if (userDataPath != null) {
        final file = File('$userDataPath/messages/$conversationId.json');
        if (await file.exists()) {
          final content = await file.readAsString();
          final List<dynamic> data = jsonDecode(content);
          return data.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      print('Failed to read messages for $conversationId: $e');
    }
    return [];
  }
}
