import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import '../models/user.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';

class UserProvider with ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoggedIn = false;
  WebSocketService? _wsService;

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoggedIn => _isLoggedIn;
  WebSocketService? get wsService => _wsService;

  Future<bool> checkLoginStatus() async {
    _token = await StorageService.getToken();
    if (_token != null) {
      final userJson = await StorageService.getUser();
      if (userJson != null) {
        _currentUser = User.fromJson(userJson);
        _isLoggedIn = true;
        
        // 更新窗口标题
        await _updateWindowTitle();
        
        // 自动建立 WebSocket 连接
        _wsService = WebSocketService();
        _wsService!.connect(_currentUser!.id.toString(), _token!);
        
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  Future<void> login(User user, String token) async {
    _currentUser = user;
    _token = token;
    _isLoggedIn = true;
    
    // 设置当前用户ID以支持多用户数据隔离
    await StorageService.setCurrentUser(user.id.toString());
    
    await StorageService.saveToken(token);
    await StorageService.saveUser(user.toJson());
    
    // 更新窗口标题
    await _updateWindowTitle();
    
    // 建立 WebSocket 连接
    _wsService = WebSocketService();
    _wsService!.connect(user.id.toString(), token);
    
    notifyListeners();
  }

  Future<void> logout() async {
    // 断开 WebSocket 连接
    _wsService?.disconnect();
    _wsService = null;
    
    _currentUser = null;
    _token = null;
    _isLoggedIn = false;
    
    // 重置窗口标题
    await _updateWindowTitle();
    
    await StorageService.clearAll();
    
    notifyListeners();
  }

  void updateUser(User user) {
    _currentUser = user;
    StorageService.saveUser(user.toJson());
    
    // 更新窗口标题
    _updateWindowTitle();
    
    notifyListeners();
  }

  // 更新窗口标题
  Future<void> _updateWindowTitle() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        String title = 'GoChat';
        if (_currentUser != null) {
          title = 'GoChat - ${_currentUser!.nickname}';
        }
        await windowManager.setTitle(title);
      } catch (e) {
        print('Failed to update window title: $e');
      }
    }
  }

  // 获取所有已登录过的用户
  Future<List<User>> getAllUsers() async {
    final usersData = await StorageService.getAllUsers();
    return usersData.map((data) => User.fromJson(data)).toList();
  }

  // 切换到指定用户
  Future<bool> switchToUser(String userId) async {
    try {
      final success = await StorageService.switchToUser(userId);
      if (success) {
        // 重新检查登录状态
        await checkLoginStatus();
        return true;
      }
    } catch (e) {
      print('Failed to switch to user $userId: $e');
    }
    return false;
  }
}
