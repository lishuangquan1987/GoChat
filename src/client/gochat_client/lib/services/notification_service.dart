import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 通知类型
enum NotificationType {
  message,
  friendRequest,
  system,
}

/// 通知数据
class NotificationData {
  final String id;
  final NotificationType type;
  final String title;
  final String content;
  final DateTime time;
  final Map<String, dynamic>? data;

  NotificationData({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.time,
    this.data,
  });
}

/// 通知服务
/// 负责管理应用内通知、声音提示、震动等
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final StreamController<NotificationData> _notificationController = 
      StreamController<NotificationData>.broadcast();
  
  Stream<NotificationData> get notificationStream => _notificationController.stream;
  
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showInAppNotification = true;

  // 设置
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get showInAppNotification => _showInAppNotification;

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
  }

  void setShowInAppNotification(bool enabled) {
    _showInAppNotification = enabled;
  }

  /// 显示消息通知
  void showMessageNotification({
    required String fromUserName,
    required String content,
    required String conversationId,
    Map<String, dynamic>? data,
  }) {
    final notification = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.message,
      title: fromUserName,
      content: content,
      time: DateTime.now(),
      data: {
        'conversationId': conversationId,
        ...?data,
      },
    );

    _showNotification(notification);
  }

  /// 显示好友请求通知
  void showFriendRequestNotification({
    required String fromUserName,
    required int requestId,
    Map<String, dynamic>? data,
  }) {
    final notification = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.friendRequest,
      title: '好友请求',
      content: '$fromUserName 请求添加您为好友',
      time: DateTime.now(),
      data: {
        'requestId': requestId,
        'fromUserName': fromUserName,
        ...?data,
      },
    );

    _showNotification(notification);
  }

  /// 显示系统通知
  void showSystemNotification({
    required String title,
    required String content,
    Map<String, dynamic>? data,
  }) {
    final notification = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.system,
      title: title,
      content: content,
      time: DateTime.now(),
      data: data,
    );

    _showNotification(notification);
  }

  /// 内部通知处理
  void _showNotification(NotificationData notification) {
    // 播放声音
    if (_soundEnabled) {
      _playNotificationSound();
    }

    // 震动
    if (_vibrationEnabled) {
      _vibrate();
    }

    // 发送到流中供UI处理
    if (_showInAppNotification) {
      _notificationController.add(notification);
    }
  }

  /// 播放通知声音
  void _playNotificationSound() {
    try {
      // 使用 HapticFeedback 代替 SystemSound，因为 SystemSound.click 不存在
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Failed to play notification sound: $e');
    }
  }

  /// 震动
  void _vibrate() {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to vibrate: $e');
    }
  }

  /// 清除所有通知
  void clearAllNotifications() {
    // 这里可以实现清除逻辑
  }

  /// 释放资源
  void dispose() {
    _notificationController.close();
  }
}