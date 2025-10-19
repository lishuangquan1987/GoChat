import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/user_provider.dart';

import '../widgets/optimized_conversation_list.dart';
import '../utils/performance_monitor.dart';
import '../utils/desktop_notification.dart';
import 'chat_page.dart';

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
      // TODO: 从服务器获取最新的会话列表
      // 这里可以调用 API 获取会话列表并更新 ChatProvider
      await Future.delayed(const Duration(seconds: 1)); // 模拟网络请求
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('刷新成功'),
            duration: Duration(seconds: 1),
            backgroundColor: Color(0xFF07C160),
          ),
        );
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
    final searchController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索用户'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: '输入用户ID或用户名',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (searchController.text.isNotEmpty) {
                _searchAndStartChat(searchController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF07C160),
              foregroundColor: Colors.white,
            ),
            child: const Text('搜索'),
          ),
        ],
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

  void _searchAndStartChat(String searchText) {
    // 尝试解析为用户ID
    final userId = int.tryParse(searchText);
    if (userId != null) {
      // TODO: 调用API搜索用户并创建会话
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('搜索用户ID: $userId (功能开发中...)'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // 按用户名搜索
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('搜索用户名: $searchText (功能开发中...)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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

