import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/conversation.dart';

import '../services/websocket_service.dart' as ws;
import '../services/notification_service.dart';
import '../widgets/in_app_notification.dart';
import '../utils/desktop_notification.dart';
import 'chat_list_page.dart';
import 'friend_list_page.dart';
import 'group_list_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final _notificationService = NotificationService();
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _setupWebSocketConnection();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    _notificationService.notificationStream.listen((notification) {
      if (mounted) {
        _showInAppNotification(notification);
      }
    });
  }

  void _setupWebSocketConnection() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (userProvider.currentUser != null && userProvider.token != null) {
      // 加载本地会话数据
      chatProvider.loadConversationsFromStorage();
      
      // 确保WebSocket连接
      if (userProvider.wsService == null) {
        final wsService = ws.WebSocketService();
        userProvider.setWebSocketService(wsService);
        wsService.connect(
          userProvider.currentUser!.id.toString(),
          userProvider.token!,
        );
      }
      
      // 直接监听WebSocket消息流，简化架构
      _wsSubscription = userProvider.wsService!.messageStream.listen((data) {
        _handleWebSocketMessage(data);
      });
      
      // 监听连接状态
      userProvider.wsService!.connectionStateStream.listen((state) {
        chatProvider.setConnected(state == ws.ConnectionState.connected);
      });
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    final messageType = data['type'] as String?;
    debugPrint('HomePage: Received WebSocket message: $messageType');
    
    switch (messageType) {
      case 'message':
        _handleChatMessage(data);
        break;
      case 'friend_request':
        _handleFriendRequest(data);
        break;
      case 'system':
        _handleSystemMessage(data);
        break;
      default:
        debugPrint('HomePage: Unhandled message type: $messageType');
    }
  }

  void _handleChatMessage(Map<String, dynamic> data) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    try {
      final messageData = data['data'] as Map<String, dynamic>?;
      if (messageData == null) return;

      final message = Message.fromJson(messageData);
      
      // 检查是否为免打扰消息
      final isDoNotDisturb = data['doNotDisturb'] as bool? ?? false;
      
      // 确定会话ID
      String conversationId;
      if (message.isGroup) {
        conversationId = 'group_${message.groupId}';
      } else {
        // 对于私聊，使用发送者ID作为会话ID（接收到的消息）
        conversationId = 'private_${message.fromUserId}';
      }

      debugPrint('HomePage: Processing message for conversation $conversationId, doNotDisturb: $isDoNotDisturb');
      
      // 添加消息到ChatProvider（标记为非当前聊天，会增加未读数）
      chatProvider.addMessage(conversationId, message, isCurrentChat: false);

      // 创建或更新会话
      _createOrUpdateConversation(message, conversationId, chatProvider);

      // 只有在非免打扰状态下才显示通知
      if (!isDoNotDisturb) {
        // 显示通知
        final fromUserName = '用户${message.fromUserId}';
        final messagePreview = _getMessagePreview(message);
        
        _notificationService.showMessageNotification(
          fromUserName: fromUserName,
          content: messagePreview,
          conversationId: conversationId,
          data: {'message': message.toJson()},
        );

        // 更新桌面通知
        final totalUnread = chatProvider.conversations
            .fold<int>(0, (sum, conv) => sum + conv.unreadCount);
        DesktopNotification.updateUnreadStatus(
          unreadCount: totalUnread,
          title: fromUserName,
          message: messagePreview,
        );
      } else {
        debugPrint('HomePage: Message notification suppressed due to do not disturb');
      }

    } catch (e) {
      debugPrint('HomePage: Error handling chat message: $e');
    }
  }

  void _createOrUpdateConversation(Message message, String conversationId, ChatProvider chatProvider) {
    if (message.isGroup) {
      // 群聊会话
      final group = Group(
        id: message.groupId!,
        groupId: 'group_${message.groupId}',
        groupName: '群聊${message.groupId}',
        ownerId: 0,
        createUserId: 0,
        createTime: DateTime.now(),
        members: [],
      );
      final conversation = chatProvider.getOrCreateGroupConversation(group);
      chatProvider.updateConversation(
        conversation.id,
        lastMessage: message,
        lastTime: message.createTime,
      );
    } else {
      // 私聊会话
      final user = User(
        id: message.fromUserId,
        username: 'user${message.fromUserId}',
        nickname: '用户${message.fromUserId}',
        sex: 0,
      );
      final conversation = chatProvider.getOrCreatePrivateConversation(user);
      chatProvider.updateConversation(
        conversation.id,
        lastMessage: message,
        lastTime: message.createTime,
      );
    }
  }

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

  void _handleFriendRequest(Map<String, dynamic> data) {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    friendProvider.handleFriendRequestNotification(data);
    
    final requestData = data['data'] as Map<String, dynamic>?;
    if (requestData != null) {
      _notificationService.showFriendRequestNotification(
        fromUserName: requestData['fromUserNickname'] as String? ?? '未知用户',
        requestId: requestData['id'] as int? ?? 0,
        data: requestData,
      );
    }
  }

  void _handleSystemMessage(Map<String, dynamic> data) {
    final message = data['message'] as String?;
    if (message != null) {
      _notificationService.showSystemNotification(
        title: '系统通知',
        content: message,
      );
    }
  }









  void _showInAppNotification(NotificationData notification) {
    Widget? avatar;
    
    // 根据通知类型设置头像
    switch (notification.type) {
      case NotificationType.message:
        avatar = CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF07C160),
          child: Text(
            notification.title.isNotEmpty ? notification.title[0] : '?',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        );
        break;
      case NotificationType.friendRequest:
        avatar = const CircleAvatar(
          radius: 20,
          backgroundColor: Colors.orange,
          child: Icon(Icons.person_add, color: Colors.white, size: 20),
        );
        break;
      case NotificationType.system:
        avatar = const CircleAvatar(
          radius: 20,
          backgroundColor: Colors.blue,
          child: Icon(Icons.info, color: Colors.white, size: 20),
        );
        break;
    }

    InAppNotification.show(
      context,
      title: notification.title,
      content: notification.content,
      avatar: avatar,
      onTap: () {
        // 根据通知类型处理点击事件
        switch (notification.type) {
          case NotificationType.message:
            // 跳转到对应的聊天页面
            final conversationId = notification.data?['conversationId'] as String?;
            if (conversationId != null) {
              // 这里可以实现跳转到聊天页面的逻辑
              setState(() => _currentIndex = 0); // 切换到聊天列表
            }
            break;
          case NotificationType.friendRequest:
            // 跳转到好友请求页面
            setState(() => _currentIndex = 1); // 切换到好友页面
            break;
          case NotificationType.system:
            // 系统通知不需要特殊处理
            break;
        }
      },
    );
  }



  @override
  void dispose() {
    _wsSubscription?.cancel();
    _notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ChatListPage(),
      const FriendListPage(),
      const GroupListPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: Consumer2<ChatProvider, FriendProvider>(
        builder: (context, chatProvider, friendProvider, child) {
          // 计算未读消息总数
          final totalUnreadMessages = chatProvider.conversations
              .fold<int>(0, (sum, conv) => sum + conv.unreadCount);
          
          // 计算待处理好友请求数
          final pendingFriendRequests = friendProvider.pendingRequestCount;

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF07C160),
            unselectedItemColor: Colors.grey,
            items: [
              BottomNavigationBarItem(
                icon: _buildBadgeIcon(
                  Icons.chat,
                  totalUnreadMessages,
                ),
                label: '聊天',
              ),
              BottomNavigationBarItem(
                icon: _buildBadgeIcon(
                  Icons.people,
                  pendingFriendRequests,
                ),
                label: '好友',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.group),
                label: '群组',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: '我的',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBadgeIcon(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

