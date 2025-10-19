import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// 主题模式
enum ThemeMode {
  system,
  light,
  dark,
}

/// 主题颜色
enum ThemeColor {
  green,    // 微信绿
  blue,     // 蓝色
  purple,   // 紫色
  orange,   // 橙色
  red,      // 红色
}

/// 设置提供者
/// 管理应用的各种设置，包括主题、通知、服务器地址等
class SettingsProvider with ChangeNotifier {
  // 主题设置
  ThemeMode _themeMode = ThemeMode.system;
  ThemeColor _themeColor = ThemeColor.green;
  
  // 通知设置
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showInAppNotification = true;
  bool _showMessagePreview = true;
  
  // 服务器设置
  String _serverAddress = 'localhost:8080';
  bool _useHttps = false;
  
  // 聊天设置
  bool _sendByEnter = false;
  double _fontSize = 16.0;
  
  // 隐私设置
  bool _readReceiptEnabled = true;
  bool _lastSeenEnabled = true;

  // Getters
  ThemeMode get themeMode => _themeMode;
  ThemeColor get themeColor => _themeColor;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get showInAppNotification => _showInAppNotification;
  bool get showMessagePreview => _showMessagePreview;
  String get serverAddress => _serverAddress;
  bool get useHttps => _useHttps;
  bool get sendByEnter => _sendByEnter;
  double get fontSize => _fontSize;
  bool get readReceiptEnabled => _readReceiptEnabled;
  bool get lastSeenEnabled => _lastSeenEnabled;

  /// 获取当前主题颜色值
  Color get primaryColor {
    switch (_themeColor) {
      case ThemeColor.green:
        return const Color(0xFF07C160);
      case ThemeColor.blue:
        return const Color(0xFF1976D2);
      case ThemeColor.purple:
        return const Color(0xFF7B1FA2);
      case ThemeColor.orange:
        return const Color(0xFFFF9800);
      case ThemeColor.red:
        return const Color(0xFFD32F2F);
    }
  }

  /// 获取主题颜色名称
  String get themeColorName {
    switch (_themeColor) {
      case ThemeColor.green:
        return '微信绿';
      case ThemeColor.blue:
        return '蓝色';
      case ThemeColor.purple:
        return '紫色';
      case ThemeColor.orange:
        return '橙色';
      case ThemeColor.red:
        return '红色';
    }
  }

  /// 获取完整的服务器URL
  String get serverUrl {
    final protocol = _useHttps ? 'https' : 'http';
    return '$protocol://$_serverAddress';
  }

  /// 获取WebSocket URL
  String get websocketUrl {
    final protocol = _useHttps ? 'wss' : 'ws';
    return '$protocol://$_serverAddress/ws';
  }

  /// 初始化设置（从本地存储加载）
  Future<void> initialize() async {
    try {
      // 加载主题设置
      final themeModeStr = await StorageService.getString('theme_mode');
      if (themeModeStr != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (e) => e.toString() == themeModeStr,
          orElse: () => ThemeMode.system,
        );
      }

      final themeColorStr = await StorageService.getString('theme_color');
      if (themeColorStr != null) {
        _themeColor = ThemeColor.values.firstWhere(
          (e) => e.toString() == themeColorStr,
          orElse: () => ThemeColor.green,
        );
      }

      // 加载通知设置
      _soundEnabled = await StorageService.getBool('sound_enabled') ?? true;
      _vibrationEnabled = await StorageService.getBool('vibration_enabled') ?? true;
      _showInAppNotification = await StorageService.getBool('show_in_app_notification') ?? true;
      _showMessagePreview = await StorageService.getBool('show_message_preview') ?? true;

      // 加载服务器设置
      _serverAddress = await StorageService.getString('server_address') ?? 'localhost:8080';
      _useHttps = await StorageService.getBool('use_https') ?? false;

      // 加载聊天设置
      _sendByEnter = await StorageService.getBool('send_by_enter') ?? false;
      _fontSize = await StorageService.getDouble('font_size') ?? 16.0;

      // 加载隐私设置
      _readReceiptEnabled = await StorageService.getBool('read_receipt_enabled') ?? true;
      _lastSeenEnabled = await StorageService.getBool('last_seen_enabled') ?? true;

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize settings: $e');
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      await StorageService.setString('theme_mode', mode.toString());
      notifyListeners();
    }
  }

  /// 设置主题颜色
  Future<void> setThemeColor(ThemeColor color) async {
    if (_themeColor != color) {
      _themeColor = color;
      await StorageService.setString('theme_color', color.toString());
      notifyListeners();
    }
  }

  /// 设置声音通知
  Future<void> setSoundEnabled(bool enabled) async {
    if (_soundEnabled != enabled) {
      _soundEnabled = enabled;
      await StorageService.setBool('sound_enabled', enabled);
      notifyListeners();
    }
  }

  /// 设置震动通知
  Future<void> setVibrationEnabled(bool enabled) async {
    if (_vibrationEnabled != enabled) {
      _vibrationEnabled = enabled;
      await StorageService.setBool('vibration_enabled', enabled);
      notifyListeners();
    }
  }

  /// 设置应用内通知
  Future<void> setShowInAppNotification(bool enabled) async {
    if (_showInAppNotification != enabled) {
      _showInAppNotification = enabled;
      await StorageService.setBool('show_in_app_notification', enabled);
      notifyListeners();
    }
  }

  /// 设置消息预览
  Future<void> setShowMessagePreview(bool enabled) async {
    if (_showMessagePreview != enabled) {
      _showMessagePreview = enabled;
      await StorageService.setBool('show_message_preview', enabled);
      notifyListeners();
    }
  }

  /// 设置服务器地址
  Future<void> setServerAddress(String address) async {
    if (_serverAddress != address) {
      _serverAddress = address;
      await StorageService.setString('server_address', address);
      notifyListeners();
    }
  }

  /// 设置是否使用HTTPS
  Future<void> setUseHttps(bool useHttps) async {
    if (_useHttps != useHttps) {
      _useHttps = useHttps;
      await StorageService.setBool('use_https', useHttps);
      notifyListeners();
    }
  }

  /// 设置回车发送
  Future<void> setSendByEnter(bool enabled) async {
    if (_sendByEnter != enabled) {
      _sendByEnter = enabled;
      await StorageService.setBool('send_by_enter', enabled);
      notifyListeners();
    }
  }

  /// 设置字体大小
  Future<void> setFontSize(double size) async {
    if (_fontSize != size) {
      _fontSize = size;
      await StorageService.setDouble('font_size', size);
      notifyListeners();
    }
  }

  /// 设置已读回执
  Future<void> setReadReceiptEnabled(bool enabled) async {
    if (_readReceiptEnabled != enabled) {
      _readReceiptEnabled = enabled;
      await StorageService.setBool('read_receipt_enabled', enabled);
      notifyListeners();
    }
  }

  /// 设置最后在线时间
  Future<void> setLastSeenEnabled(bool enabled) async {
    if (_lastSeenEnabled != enabled) {
      _lastSeenEnabled = enabled;
      await StorageService.setBool('last_seen_enabled', enabled);
      notifyListeners();
    }
  }

  /// 重置所有设置
  Future<void> resetAllSettings() async {
    _themeMode = ThemeMode.system;
    _themeColor = ThemeColor.green;
    _soundEnabled = true;
    _vibrationEnabled = true;
    _showInAppNotification = true;
    _showMessagePreview = true;
    _serverAddress = 'localhost:8080';
    _useHttps = false;
    _sendByEnter = false;
    _fontSize = 16.0;
    _readReceiptEnabled = true;
    _lastSeenEnabled = true;

    // 清除本地存储
    await StorageService.remove('theme_mode');
    await StorageService.remove('theme_color');
    await StorageService.remove('sound_enabled');
    await StorageService.remove('vibration_enabled');
    await StorageService.remove('show_in_app_notification');
    await StorageService.remove('show_message_preview');
    await StorageService.remove('server_address');
    await StorageService.remove('use_https');
    await StorageService.remove('send_by_enter');
    await StorageService.remove('font_size');
    await StorageService.remove('read_receipt_enabled');
    await StorageService.remove('last_seen_enabled');

    notifyListeners();
  }
}