import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../models/conversation.dart';

import '../widgets/optimized_conversation_list.dart';
import '../utils/performance_monitor.dart';
import '../utils/desktop_notification.dart';
import 'chat_page.dart';
import 'user_search_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> with AutomaticKeepAliveClientMixin {
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  @override
  bool get wantKeepAlive => true;


  Future<void> _handleRefresh() async {
    _performanceMonitor.startTimer('conversation_list_refresh');
    try {
      final chatProvider = context.read<ChatProvider>();
      final apiService = ApiService();
      
      // 刷新会话列表（会从API获取最新的会话和未读数）
      final response = await apiService.getConversationList();
      
      if (response.data['code'] == 0 && mounted) {
        final conversationsData = response.data['data'] as List?;
        if (conversationsData != null) {
          final conversations = conversationsData
              .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
              .toList();
          chatProvider.setConversations(conversations);
        }
        
        // 为每个会话获取准确的未读数
        for (final conversation in chatProvider.conversations) {
          try {
            final friendId = conversation.type == ConversationType.private
                ? conversation.user?.id
                : null;
            final groupId = conversation.type == ConversationType.group
                ? conversation.group?.id
                : null;
            
            final unreadResponse = await apiService.getUnreadMessageCount(
              friendId: friendId,
              groupId: groupId,
            );
            
            if (unreadResponse.data['code'] == 0) {
              final unreadCount = unreadResponse.data['data'] as int? ?? 0;
              // 更新会话的未读数
              final index = chatProvider.conversations.indexWhere((c) => c.id == conversation.id);
              if (index != -1) {
                final updatedConv = Conversation(
                  id: conversation.id,
                  type: conversation.type,
                  user: conversation.user,
                  group: conversation.group,
                  lastMessage: conversation.lastMessage,
                  unreadCount: unreadCount,
                  lastTime: conversation.lastTime,
                );
                chatProvider.conversations[index] = updatedConv;
              }
            }
          } catch (e) {
            debugPrint('Error getting unread count for conversation ${conversation.id}: $e');
          }
        }
        
        chatProvider.setConversations(chatProvider.conversations);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('刷新成功'),
              duration: Duration(seconds: 1),
              backgroundColor: Color(0xFF07C160),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刷新失败: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _performanceMonitor.endTimer('conversation_list_refresh');
    }
  }

  void _showSearchUserDialog() {
    // 直接跳转到用户搜索页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserSearchPage(),
      ),
    );
  }

  void _showCreateGroupDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('创建群聊功能开发中...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showScanQRDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('扫一扫功能开发中...'),
        duration: Duration(seconds: 2),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final user = userProvider.currentUser;
            return Text(
              user?.nickname ?? 'GoChat',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),
        backgroundColor: const Color(0xFF07C160),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'search_user':
                  _showSearchUserDialog();
                  break;
                case 'create_group':
                  _showCreateGroupDialog();
                  break;
                case 'scan_qr':
                  _showScanQRDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'search_user',
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('搜索用户'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'create_group',
                child: Row(
                  children: [
                    Icon(Icons.group_add, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('创建群聊'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'scan_qr',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('扫一扫'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0xFF07C160),
        child: OptimizedConversationList(
          onConversationTap: (conversation) {
            // 清除未读数量
            final chatProvider = context.read<ChatProvider>();
            chatProvider.clearUnreadCount(conversation.id);
            
            // 更新桌面通知状态
            final totalUnread = chatProvider.conversations
                .fold<int>(0, (sum, conv) => sum + conv.unreadCount);
            DesktopNotification.updateUnreadStatus(unreadCount: totalUnread);
            
            // 导航到聊天页面
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(conversation: conversation),
              ),
            );
          },
          onConversationLongPress: (conversation) {
            // TODO: 显示会话操作菜单（删除、置顶等）
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('长按功能开发中...')),
            );
          },
        ),
      ),
    );
  }
}

