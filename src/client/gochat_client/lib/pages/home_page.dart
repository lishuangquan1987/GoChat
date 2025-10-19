import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../models/group.dart';

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
  final _wsService = ws.WebSocketService();
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    _notificationService.notificationStream.listen((notification) {
      if (mounted) {
        _showInAppNotification(notification);
      }
    });
  }

  void _connectWebSocket() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (userProvider.currentUser != null && userProvider.token != null) {
      // 加载本地会话数据
      chatProvider.loadConversationsFromStorage();
      
      _wsService.connect(
        userProvider.currentUser!.id.toString(),
        userProvider.token!,
      );
      
      _wsService.messageStream.listen((message) {
        _handleWebSocketMessage(message);
        chatProvider.setConnected(true);
      });

      _wsService.connectionStateStream.listen((state) {
        chatProvider.setConnected(state == ws.ConnectionState.connected);
      });
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final messageType = message['type'] as String?;
    
    switch (messageType) {
      case 'friend_request':
        _handleFriendRequestNotification(message);
        break;
      case 'friend_request_accepted':
        _handleFriendRequestAcceptedNotification(message);
        break;
      case 'message':
        _handleMessageNotification(message);
        break;
      case 'private_message':
        _handlePrivateMessageNotification(message);
        break;
      case 'group_message':
        _handleGroupMessageNotification(message);
        break;
      default:
        // Handle other message types
        break;
    }
  }

  void _handleFriendRequestNotification(Map<String, dynamic> message) {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    friendProvider.handleFriendRequestNotification(message);
    
    // 显示好友请求通知
    final data = message['data'] as Map<String, dynamic>?;
    if (data != null) {
      _notificationService.showFriendRequestNotification(
        fromUserName: data['fromUserNickname'] as String? ?? '未知用户',
        requestId: data['id'] as int? ?? 0,
        data: data,
      );
    }
  }

  void _handleFriendRequestAcceptedNotification(Map<String, dynamic> message) {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    friendProvider.handleFriendRequestAcceptedNotification(message);
    
    // 显示系统通知
    _notificationService.showSystemNotification(
      title: '好友请求',
      content: message['message'] as String? ?? '好友请求已被接受',
    );
  }

  void _handleMessageNotification(Map<String, dynamic> message) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // 处理实际的消息数据
    final data = message['data'] as Map<String, dynamic>?;
    if (data != null) {
      try {
        final messageObj = Message.fromJson(data);
        
        // 判断是私聊还是群聊
        if (messageObj.isGroup) {
          // 群聊消息
          final conversationId = 'group_${messageObj.groupId}';
          
          // 添加消息到聊天记录（标记为非当前聊天，会增加未读数）
          chatProvider.addMessage(conversationId, messageObj, isCurrentChat: false);
          
          // 创建或更新会话
          if (messageObj.groupId != null) {
            final group = Group(
              id: messageObj.groupId!,
              groupId: 'group_${messageObj.groupId}',
              groupName: data['groupName'] as String? ?? '群聊${messageObj.groupId}',
              ownerId: 0,
              createUserId: 0,
              createTime: DateTime.now(),
              members: [],
            );
            
            final conversation = chatProvider.getOrCreateGroupConversation(group);
            chatProvider.updateConversation(
              conversation.id,
              lastMessage: messageObj,
              lastTime: messageObj.createTime,
            );
          }
          
          // 显示通知
          final fromUserName = data['fromUserNickname'] as String? ?? '群成员';
          final groupName = data['groupName'] as String? ?? '群聊';
          final messagePreview = _getMessagePreview(messageObj);
          
          _notificationService.showMessageNotification(
            fromUserName: '$fromUserName@$groupName',
            content: messagePreview,
            conversationId: conversationId,
            data: data,
          );
        } else {
          // 私聊消息
          final conversationId = 'private_${messageObj.fromUserId}';
          
          // 添加消息到聊天记录（标记为非当前聊天，会增加未读数）
          chatProvider.addMessage(conversationId, messageObj, isCurrentChat: false);
          
          // 创建或更新会话
          final user = User(
            id: messageObj.fromUserId,
            username: data['fromUserName'] as String? ?? 'user${messageObj.fromUserId}',
            nickname: data['fromUserNickname'] as String? ?? '用户${messageObj.fromUserId}',
            sex: 0,
          );
          
          final conversation = chatProvider.getOrCreatePrivateConversation(user);
          chatProvider.updateConversation(
            conversation.id,
            lastMessage: messageObj,
            lastTime: messageObj.createTime,
          );
          
          // 显示通知
          final fromUserName = data['fromUserNickname'] as String? ?? '未知用户';
          final messagePreview = _getMessagePreview(messageObj);
          
          _notificationService.showMessageNotification(
            fromUserName: fromUserName,
            content: messagePreview,
            conversationId: conversationId,
            data: data,
          );
        }
        
        // 更新桌面通知
        final totalUnread = chatProvider.conversations
            .fold<int>(0, (sum, conv) => sum + conv.unreadCount);
        final fromUserName = data['fromUserNickname'] as String? ?? '未知用户';
        final messagePreview = _getMessagePreview(messageObj);
        
        DesktopNotification.updateUnreadStatus(
          unreadCount: totalUnread,
          title: fromUserName,
          message: messagePreview,
        );
      } catch (e) {
        print('Failed to parse message: $e');
      }
    }
  }

  void _handlePrivateMessageNotification(Map<String, dynamic> message) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // 处理实际的消息数据
    final data = message['data'] as Map<String, dynamic>?;
    if (data != null) {
      final fromUserId = data['fromUserId'] as int?;
      final conversationId = 'private_$fromUserId';
      
      // 创建消息对象
      try {
        final messageObj = Message.fromJson(data);
        
        // 添加消息到聊天记录（标记为非当前聊天，会增加未读数）
        chatProvider.addMessage(conversationId, messageObj, isCurrentChat: false);
        
        // 创建或更新会话
        if (fromUserId != null) {
          // 这里需要获取发送者信息来创建会话
          // 暂时使用基本信息创建会话
          final user = User(
            id: fromUserId,
            username: data['fromUserName'] as String? ?? 'user$fromUserId',
            nickname: data['fromUserNickname'] as String? ?? '用户$fromUserId',
            sex: 0,
          );
          
          final conversation = chatProvider.getOrCreatePrivateConversation(user);
          chatProvider.updateConversation(
            conversation.id,
            lastMessage: messageObj,
            lastTime: messageObj.createTime,
          );
        }
        
        // 显示通知
        final fromUserName = data['fromUserNickname'] as String? ?? '未知用户';
        final messagePreview = _getMessagePreview(messageObj);
        
        _notificationService.showMessageNotification(
          fromUserName: fromUserName,
          content: messagePreview,
          conversationId: conversationId,
          data: data,
        );
        
        // 更新桌面通知
        final totalUnread = chatProvider.conversations
            .fold<int>(0, (sum, conv) => sum + conv.unreadCount);
        DesktopNotification.updateUnreadStatus(
          unreadCount: totalUnread,
          title: fromUserName,
          message: messagePreview,
        );
      } catch (e) {
        print('Failed to parse message: $e');
      }
    }
  }

  void _handleGroupMessageNotification(Map<String, dynamic> message) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // 处理实际的消息数据
    final data = message['data'] as Map<String, dynamic>?;
    if (data != null) {
      final groupId = data['groupId'] as int?;
      final conversationId = 'group_$groupId';
      
      // 创建消息对象
      try {
        final messageObj = Message.fromJson(data);
        
        // 添加消息到聊天记录（标记为非当前聊天，会增加未读数）
        chatProvider.addMessage(conversationId, messageObj, isCurrentChat: false);
        
        // 创建或更新会话
        if (groupId != null) {
          // 这里需要获取群组信息来创建会话
          // 暂时使用基本信息创建会话
          final group = Group(
            id: groupId,
            groupId: 'group_$groupId',
            groupName: data['groupName'] as String? ?? '群聊$groupId',
            ownerId: 0,
            createUserId: 0,
            members: [],
            createTime: DateTime.now(),
          );
          
          final conversation = chatProvider.getOrCreateGroupConversation(group);
          chatProvider.updateConversation(
            conversation.id,
            lastMessage: messageObj,
            lastTime: messageObj.createTime,
          );
        }
        
        // 显示通知
        final fromUserName = '${data['fromUserNickname'] ?? '未知用户'} (${data['groupName'] ?? '群聊'})';
        final messagePreview = _getMessagePreview(messageObj);
        
        _notificationService.showMessageNotification(
          fromUserName: fromUserName,
          content: messagePreview,
          conversationId: conversationId,
          data: data,
        );
        
        // 更新桌面通知
        final totalUnread = chatProvider.conversations
            .fold<int>(0, (sum, conv) => sum + conv.unreadCount);
        DesktopNotification.updateUnreadStatus(
          unreadCount: totalUnread,
          title: fromUserName,
          message: messagePreview,
        );
      } catch (e) {
        print('Failed to parse group message: $e');
      }
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

  // 获取消息预览文本
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

  @override
  void dispose() {
    _wsService.dispose();
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

