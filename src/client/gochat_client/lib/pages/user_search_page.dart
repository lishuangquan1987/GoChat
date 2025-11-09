import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../providers/user_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_page.dart';
import '../models/conversation.dart';
import 'friend_requests_page.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  List<User> _searchResults = [];
  bool _isSearching = false;
  bool _excludeFriends = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入搜索关键词')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final response = await _apiService.searchUsers(
        keyword,
        excludeFriends: _excludeFriends,
        limit: 20,
      );

      if (response.data['code'] == 0) {
        final usersData = response.data['data'] as List?;
        if (usersData != null) {
          setState(() {
            _searchResults = usersData
                .map((json) => User.fromJson(json as Map<String, dynamic>))
                .toList();
          });
        } else {
          setState(() {
            _searchResults = [];
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['message'] ?? '搜索失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _showUserActions(User user) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    
    if (currentUser == null || currentUser.id == user.id) {
      return; // 不能对自己操作
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('发送消息'),
              onTap: () {
                Navigator.pop(context);
                _startChatWithUser(user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('添加好友'),
              onTap: () {
                Navigator.pop(context);
                _showAddFriendDialog(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startChatWithUser(User user) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // 创建会话
    final conversation = chatProvider.getOrCreatePrivateConversation(user);
    
    // 导航到聊天页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(conversation: conversation),
      ),
    );
  }

  void _showAddFriendDialog(User user) {
    final remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加 ${user.nickname} 为好友'),
        content: TextField(
          controller: remarkController,
          decoration: const InputDecoration(
            labelText: '备注',
            hintText: '请输入备注信息（可选）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendFriendRequest(user.id, remarkController.text);
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest(int friendId, String remark) async {
    try {
      final response = await _apiService.sendFriendRequest(friendId, remark);
      
      if (mounted) {
        if (response.data['code'] == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('好友请求已发送'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['message'] ?? '发送失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }

  Widget _buildUserItem(User user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF07C160),
        backgroundImage: user.avatar != null && user.avatar!.isNotEmpty
            ? NetworkImage(user.avatar!)
            : null,
        child: user.avatar == null || user.avatar!.isEmpty
            ? Text(
                user.nickname.isNotEmpty
                    ? user.nickname[0].toUpperCase()
                    : 'U',
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      title: Text(user.nickname),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${user.id}'),
          if (user.signature != null && user.signature!.isNotEmpty)
            Text(
              user.signature!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          if (user.status != null)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: user.isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  user.statusText,
                  style: TextStyle(
                    color: user.isOnline ? Colors.green : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showUserActions(user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索用户'),
        backgroundColor: const Color(0xFF07C160),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '输入用户ID、用户名或昵称',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _searchUsers(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchUsers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF07C160),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('搜索'),
                ),
              ],
            ),
          ),
          // 选项
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Checkbox(
                  value: _excludeFriends,
                  onChanged: (value) {
                    setState(() {
                      _excludeFriends = value ?? false;
                    });
                  },
                ),
                const Text('排除已添加的好友'),
              ],
            ),
          ),
          const Divider(height: 1),
          // 搜索结果
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? '请输入关键词搜索'
                                  : '未找到相关用户',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return _buildUserItem(_searchResults[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

