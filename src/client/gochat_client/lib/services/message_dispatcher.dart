import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/conversation.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import '../utils/desktop_notification.dart';

/// 全局消息分发器
/// 负责接收WebSocket消息并分发给相应的处理器
/// 确保整个应用只有一个消息接收入口
class MessageDispatcher {
  static final MessageDispatcher _instance = MessageDispatcher._internal();
  factory MessageDispatcher() => _instance;
  MessageDispatcher._internal();

  // 消息流控制器
  final StreamController<MessageEvent> _messageStreamController = 
      StreamController<MessageEvent>.broadcast();
  
  // 当前活跃的聊天页面ID（用于判断是否需要增加未读数）
  String? _currentActiveChatId;
  
  // Provider引用
  ChatProvider? _chatProvider;
  FriendProvider? _friendProvider;
  NotificationService? _notificationService;
  WebSocketService? _webSocketService;
  
  // 当前用户信息
  int? _currentUserId;
  
  // WebSocket消息监听订阅
  StreamSubscription<Map<String, dynamic>>? _wsMessageSubscription;
  StreamSubscription<ConnectionState>? _wsConnectionSubscription;

  // 消息事件流
  Stream<MessageEvent> get messageStream => _messageStreamController.stream;

  /// 初始化消息分发器
  void initialize({
    required ChatProvider chatProvider,
    required FriendProvider friendProvider,
    required NotificationService notificationService,
    required WebSocketService webSocketService,
    int? currentUserId,
  }) {
    _chatProvider = chatProvider;
    _friendProvider = friendProvider;
    _notificationService = notificationService;
    _webSocketService = webSocketService;
    _currentUserId = currentUserId;
    
    // 设置WebSocket消息监听（确保只有一个监听器）
    _setupWebSocketListeners();
  }

  /// 设置WebSocket监听器
  void _setupWebSocketListeners() {
    // 清除之前的监听器
    _wsMessageSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
    
    if (_webSocketService != null) {
      // 监听WebSocket消息
      _wsMessageSubscription = _webSocketService!.messageStream.listen(
        (message) {
          debugPrint('MessageDispatcher: Received WebSocket message: ${message['type']}');
          handleWebSocketMessage(message);
        },
        onError: (error) {
          debugPrint('MessageDispatcher: WebSocket message error: $error');
        },
      );
      
      // 监听连接状态变化
      _wsConnectionSubscription = _webSocketService!.connectionStateStream.listen(
        (state) {
          debugPrint('MessageDispatcher: Connection state changed: $state');
          _chatProvider?.setConnected(state == ConnectionState.connected);
          
          // 发送连接状态事件
          _messageStreamController.add(MessageEvent(
            type: MessageEventType.connectionStatus,
            connectionState: state,
          ));
        },
      );
    }
  }

  /// 设置当前活跃的聊天页面
  void setActiveChatId(String? chatId) {
    _currentActiveChatId = chatId;
    debugPrint('MessageDispatcher: Active chat set to $chatId');
  }

  /// 处理WebSocket消息
  void handleWebSocketMessage(Map<String, dynamic> data) {
    final messageType = data['type'] as String?;
    debugPrint('MessageDispatcher: Handling message type: $messageType');

    switch (messageType) {
      case 'message':
      case 'private_message':
      case 'group_message':
        _handleChatMessage(data);
        break;
      case 'message_status':
      case 'ack':
        _handleMessageStatus(data);
        break;
      case 'friend_request':
        _handleFriendRequest(data);
        break;
      case 'friend_request_accepted':
        _handleFriendRequestAccepted(data);
        break;
      case 'system':
      case 'notification':
        _handleSystemMessage(data);
        break;
      case 'heartbeat':
        // 心跳消息不需要特殊处理
        break;
      case 'error':
        _handleErrorMessage(data);
        break;
      default:
        debugPrint('MessageDispatcher: Unknown message type: $messageType');
        // 将未知消息类型也发送到事件流，让其他组件处理
        _messageStreamController.add(MessageEvent(
          type: MessageEventType.unknown,
          rawData: data,
        ));
    }
  }

  /// 处理聊天消息
  void _handleChatMessage(Map<String, dynamic> data) {
    try {
      final messageData = data['data'] as Map<String, dynamic>?;
      if (messageData == null) {
        debugPrint('MessageDispatcher: No message data found');
        return;
      }

      final message = Message.fromJson(messageData);
      
      // 确定会话ID - 修复逻辑
      String conversationId;
      if (message.isGroup) {
        conversationId = 'group_${message.groupId}';
      } else {
        // 对于私聊，需要根据当前用户来确定会话ID
        // 如果是接收到的消息，使用发送者ID；如果是发送的消息，使用接收者ID
        final currentUserId = _getCurrentUserId();
        if (currentUserId != null) {
          if (message.fromUserId == currentUserId) {
            // 自己发送的消息，使用接收者ID
            conversationId = 'private_${message.toUserId}';
          } else {
            // 接收到的消息，使用发送者ID
            conversationId = 'private_${message.fromUserId}';
          }
        } else {
          // 兜底逻辑
          conversationId = 'private_${message.fromUserId}';
        }
      }

      // 判断是否为当前活跃聊天
      final isCurrentChat = _currentActiveChatId == conversationId;
      
      debugPrint('MessageDispatcher: Processing message for conversation $conversationId, isCurrentChat: $isCurrentChat, fromUser: ${message.fromUserId}, toUser: ${message.toUserId}');
      
      // 添加消息到ChatProvider
      _chatProvider?.addMessage(conversationId, message, isCurrentChat: isCurrentChat);

      // 创建或更新会话
      _createOrUpdateConversation(message, conversationId);

      // 发送消息事件
      _messageStreamController.add(MessageEvent(
        type: MessageEventType.newMessage,
        message: message,
        conversationId: conversationId,
        isCurrentChat: isCurrentChat,
      ));

      // 显示通知和更新桌面状态
      _showMessageNotification(message, conversationId, isCurrentChat);
      _updateDesktopNotification();

    } catch (e) {
      debugPrint('MessageDispatcher: Error handling chat message: $e');
    }
  }

  /// 获取当前用户ID
  int? _getCurrentUserId() {
    return _currentUserId;
  }

  /// 设置当前用户ID
  void setCurrentUserId(int? userId) {
    _currentUserId = userId;
  }

  /// 处理消息状态更新
  void _handleMessageStatus(Map<String, dynamic> data) {
    final msgId = data['msgId'] as String?;
    final status = data['status'] as String?;
    
    if (msgId != null && status != null) {
      _messageStreamController.add(MessageEvent(
        type: MessageEventType.messageStatus,
        messageId: msgId,
        status: status,
      ));
    }
  }

  /// 处理好友请求
  void _handleFriendRequest(Map<String, dynamic> data) {
    _friendProvider?.handleFriendRequestNotification(data);
    
    final requestData = data['data'] as Map<String, dynamic>?;
    if (requestData != null) {
      _notificationService?.showFriendRequestNotification(
        fromUserName: requestData['fromUserNickname'] as String? ?? '未知用户',
        requestId: requestData['id'] as int? ?? 0,
        data: requestData,
      );
    }
  }

  /// 处理好友请求被接受
  void _handleFriendRequestAccepted(Map<String, dynamic> data) {
    _friendProvider?.handleFriendRequestAcceptedNotification(data);
    
    _notificationService?.showSystemNotification(
      title: '好友请求',
      content: data['message'] as String? ?? '好友请求已被接受',
    );
  }

  /// 处理系统消息
  void _handleSystemMessage(Map<String, dynamic> data) {
    final message = data['message'] as String?;
    final action = data['action'] as String?;
    
    if (message != null) {
      _notificationService?.showSystemNotification(
        title: '系统通知',
        content: message,
      );
    }
    
    // 处理特殊系统消息
    if (action == 'fetch_offline_messages') {
      // 通知需要获取离线消息
      _messageStreamController.add(MessageEvent(
        type: MessageEventType.fetchOfflineMessages,
        rawData: data,
      ));
    }
    
    // 发送系统消息事件
    _messageStreamController.add(MessageEvent(
      type: MessageEventType.systemMessage,
      rawData: data,
    ));
  }

  /// 处理错误消息
  void _handleErrorMessage(Map<String, dynamic> data) {
    final errorMsg = data['message'] as String?;
    debugPrint('MessageDispatcher: Server error: $errorMsg');
    
    if (errorMsg != null) {
      _notificationService?.showSystemNotification(
        title: '错误',
        content: errorMsg,
      );
    }
    
    // 发送错误事件
    _messageStreamController.add(MessageEvent(
      type: MessageEventType.error,
      rawData: data,
    ));
  }

  /// 创建或更新会话
  void _createOrUpdateConversation(Message message, String conversationId) {
    if (_chatProvider == null) return;

    Conversation? conversation;
    
    if (message.isGroup) {
      // 群聊会话
      final group = Group(
        id: message.groupId!,
        groupId: 'group_${message.groupId}',
        groupName: '群聊${message.groupId}', // 这里可以从消息数据中获取群名
        ownerId: 0,
        createUserId: 0,
        createTime: DateTime.now(),
        members: [],
      );
      conversation = _chatProvider!.getOrCreateGroupConversation(group);
    } else {
      // 私聊会话 - 修复用户ID逻辑
      int otherUserId;
      if (message.fromUserId == _currentUserId) {
        // 自己发送的消息，对方是接收者
        otherUserId = message.toUserId;
      } else {
        // 接收到的消息，对方是发送者
        otherUserId = message.fromUserId;
      }
      
      final user = User(
        id: otherUserId,
        username: 'user$otherUserId',
        nickname: '用户$otherUserId', // 这里可以从消息数据中获取昵称
        sex: 0,
      );
      conversation = _chatProvider!.getOrCreatePrivateConversation(user);
    }

    // 更新会话的最后消息和时间
    _chatProvider!.updateConversation(
      conversation.id,
      lastMessage: message,
      lastTime: message.createTime,
    );
  }

  /// 显示消息通知
  void _showMessageNotification(Message message, String conversationId, bool isCurrentChat) {
    // 只有在不是当前聊天时才显示通知
    if (isCurrentChat) return;
    
    final fromUserName = '用户${message.fromUserId}'; // 这里可以从缓存中获取真实昵称
    final messagePreview = _getMessagePreview(message);
    
    // 显示应用内通知
    _notificationService?.showMessageNotification(
      fromUserName: fromUserName,
      content: messagePreview,
      conversationId: conversationId,
      data: {'message': message.toJson()},
    );
    
    // 显示系统级通知
    _showSystemNotification(fromUserName, messagePreview);
  }

  /// 显示系统级通知
  void _showSystemNotification(String title, String content) {
    DesktopNotification.updateUnreadStatus(
      unreadCount: _getTotalUnreadCount(),
      title: title,
      message: content,
    );
  }

  /// 获取总未读消息数
  int _getTotalUnreadCount() {
    if (_chatProvider == null) return 0;
    return _chatProvider!.conversations
        .fold<int>(0, (sum, conv) => sum + conv.unreadCount);
  }

  /// 更新桌面通知
  void _updateDesktopNotification() {
    if (_chatProvider == null) return;
    
    final totalUnread = _chatProvider!.conversations
        .fold<int>(0, (sum, conv) => sum + conv.unreadCount);
    
    DesktopNotification.updateUnreadStatus(
      unreadCount: totalUnread,
      title: 'GoChat',
      message: totalUnread > 0 ? '您有 $totalUnread 条未读消息' : null,
    );
  }

  /// 获取消息预览文本
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

  /// 重新连接WebSocket
  void reconnectWebSocket() {
    if (_webSocketService != null) {
      _webSocketService!.reconnect();
    }
  }

  /// 发送WebSocket消息
  void sendWebSocketMessage(Map<String, dynamic> message) {
    if (_webSocketService != null && _webSocketService!.isConnected) {
      _webSocketService!.sendMessage(message);
    } else {
      debugPrint('MessageDispatcher: Cannot send message - WebSocket not connected');
    }
  }

  /// 清理资源
  void dispose() {
    _wsMessageSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
    _messageStreamController.close();
    _currentActiveChatId = null;
    _chatProvider = null;
    _friendProvider = null;
    _notificationService = null;
    _webSocketService = null;
  }
}

/// 消息事件类型
enum MessageEventType {
  newMessage,
  messageStatus,
  friendRequest,
  systemMessage,
  connectionStatus,
  fetchOfflineMessages,
  error,
  unknown,
}

/// 消息事件
class MessageEvent {
  final MessageEventType type;
  final Message? message;
  final String? conversationId;
  final String? messageId;
  final String? status;
  final bool isCurrentChat;
  final ConnectionState? connectionState;
  final Map<String, dynamic>? rawData;

  MessageEvent({
    required this.type,
    this.message,
    this.conversationId,
    this.messageId,
    this.status,
    this.isCurrentChat = false,
    this.connectionState,
    this.rawData,
  });
}