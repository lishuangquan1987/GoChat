import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../services/notification_service.dart';
import '../utils/desktop_notification.dart';

/// 通知管理器
/// 负责集中管理所有类型的通知，包括聊天消息、好友请求、系统通知等
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final NotificationService _notificationService = NotificationService();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showInAppNotification = true;
  bool _showDesktopNotification = true;
  String? _activeConversationId; // 当前活动的会话ID

  // 设置
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get showInAppNotification => _showInAppNotification;
  bool get showDesktopNotification => _showDesktopNotification;
  String? get activeConversationId => _activeConversationId;

  /// 初始化通知管理器
  void initialize() {
    // 可以在这里进行初始化操作
    debugPrint('NotificationManager initialized');
  }

  /// 处理私聊消息通知
  void handlePrivateMessageNotification({
    required Message message,
    required User fromUser,
    required String conversationId,
  }) {
    // 如果是当前活动会话，不显示通知
    if (_activeConversationId == conversationId) {
      return;
    }

    // 构建通知数据
    final notificationData = {
      'type': 'private_message',
      'message': message,
      'fromUser': fromUser,
      'conversationId': conversationId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // 发送到通知流
    _notificationController.add(notificationData);

    // 显示系统通知
    _notificationService.showMessageNotification(
      fromUserName: fromUser.nickname,
      content: _getMessagePreview(message),
      conversationId: conversationId,
    );

    // 更新桌面通知
    if (_showDesktopNotification) {
      DesktopNotification.updateUnreadStatus(
        unreadCount: 1, // 简化处理，实际应该获取总未读数
        title: fromUser.nickname,
        message: _getMessagePreview(message),
      );
    }
  }

  /// 设置当前活动会话ID
  void setActiveConversationId(String conversationId) {
    _activeConversationId = conversationId;
  }

  /// 清除当前活动会话ID
  void clearActiveConversationId() {
    _activeConversationId = null;
  }

  /// 处理群聊消息通知
  void handleGroupMessageNotification({
    required Message message,
    required User fromUser,
    required Group group,
    required String conversationId,
    bool isCurrentChat = false,
  }) {
    // 发送内部通知流
    _notificationController.add({
      'type': 'group_message',
      'message': message,
      'fromUser': fromUser,
      'group': group,
      'conversationId': conversationId,
    });

    // 只有非当前聊天时才显示通知
    if (!isCurrentChat) {
      // 显示应用内通知
      _notificationService.showMessageNotification(
        fromUserName: '${fromUser.nickname}@${group.groupName}',
        content: _getMessagePreview(message),
        conversationId: conversationId,
        data: {
          'groupId': group.id,
          'fromUserId': fromUser.id,
          'messageId': message.msgId,
        },
      );

      // 显示桌面通知
      DesktopNotification.updateUnreadStatus(
        unreadCount: 1, // 这里应该传入真实的未读数，暂时用1代替
        title: '${fromUser.nickname}@${group.groupName}',
        message: _getMessagePreview(message),
      );
    }
  }

  /// 处理好友请求通知
  void handleFriendRequestNotification({
    required int requestId,
    required User fromUser,
    required String remark,
  }) {
    // 发送内部通知流
    _notificationController.add({
      'type': 'friend_request',
      'requestId': requestId,
      'fromUser': fromUser,
      'remark': remark,
    });

    // 显示应用内通知
    _notificationService.showFriendRequestNotification(
      fromUserName: fromUser.nickname,
      requestId: requestId,
      data: {
        'fromUserId': fromUser.id,
        'remark': remark,
      },
    );

    // 显示桌面通知
    DesktopNotification.updateUnreadStatus(
      unreadCount: 1, // 这里应该传入真实的未读数，暂时用1代替
      title: '好友请求',
      message: '${fromUser.nickname} 请求添加您为好友',
    );
  }

  /// 处理好友请求被接受通知
  void handleFriendRequestAcceptedNotification({
    required User user,
  }) {
    // 发送内部通知流
    _notificationController.add({
      'type': 'friend_request_accepted',
      'user': user,
    });

    // 显示系统通知
    _notificationService.showSystemNotification(
      title: '好友请求已接受',
      content: '${user.nickname} 接受了您的好友请求',
    );
  }

  /// 处理系统通知
  void handleSystemNotification({
    required String title,
    required String content,
    Map<String, dynamic>? data,
  }) {
    // 发送内部通知流
    _notificationController.add({
      'type': 'system',
      'title': title,
      'content': content,
      'data': data,
    });

    // 显示系统通知
    _notificationService.showSystemNotification(
      title: title,
      content: content,
      data: data,
    );
  }

  /// 获取消息预览
  String _getMessagePreview(Message message) {
    switch (message.msgType) {
      case MessageType.text:
        return message.content;
      case MessageType.image:
        return '[图片]';
      case MessageType.video:
        return '[视频]';
      default:
        return '[消息]';
    }
  }

  /// 设置通知偏好
  void setNotificationPreferences({
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? showInAppNotification,
  }) {
    if (soundEnabled != null) {
      _notificationService.setSoundEnabled(soundEnabled);
    }
    if (vibrationEnabled != null) {
      _notificationService.setVibrationEnabled(vibrationEnabled);
    }
    if (showInAppNotification != null) {
      _notificationService.setShowInAppNotification(showInAppNotification);
    }
  }

  /// 清除所有通知
  void clearAllNotifications() {
    _notificationService.clearAllNotifications();
  }

  /// 释放资源
  void dispose() {
    _notificationController.close();
    _notificationService.dispose();
  }
}
