import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_provider.dart';
import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/friend_request.dart';
import 'friend_requests_page.dart';
import 'chat_page.dart';

class FriendListPage extends StatefulWidget {
  const FriendListPage({super.key});

  @override
  State<FriendListPage> createState() => _FriendListPageState();
}

class _FriendListPageState extends State<FriendListPage> {
  final _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadFriendRequests();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getFriendList();
      if (response.data['code'] == 0) {
        final friendsData = response.data['data'] as List?;
        if (friendsData != null) {
          final friends = friendsData.map((json) => User.fromJson(json)).toList();
          if (mounted) {
            Provider.of<FriendProvider>(context, listen: false).setFriends(friends);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载好友列表失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFriendRequests() async {
    try {
      final response = await _apiService.getFriendRequests();
      print('好友请求响应: ${response.data}'); // 调试信息
      if (response.data['code'] == 0 && mounted) {
        final requestsData = response.data['data'] as List?;
        if (requestsData != null) {
          final requests = requestsData
              .map((json) => FriendRequest.fromJson(json as Map<String, dynamic>))
              .toList();
          
          print('解析的好友请求数量: ${requests.length}'); // 调试信息
          Provider.of<FriendProvider>(context, listen: false).setFriendRequests(requests);
        } else {
          print('好友请求数据为空'); // 调试信息
        }
      } else {
        print('好友请求API返回错误: ${response.data}'); // 调试信息
      }
    } catch (e) {
      print('加载好友请求失败: $e'); // 调试信息
    }
  }

  void _showAddFriendDialog() {
    final friendIdController = TextEditingController();
    final remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加好友'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: friendIdController,
              decoration: const InputDecoration(
                labelText: '好友ID',
                hintText: '请输入好友ID',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: remarkController,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '请输入备注信息（可选）',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final friendId = int.tryParse(friendIdController.text);
              if (friendId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的好友ID')),
                );
                return;
              }

              try {
                final response = await _apiService.sendFriendRequest(
                  friendId,
                  remarkController.text,
                );
                
                if (mounted) {
                  Navigator.pop(context);
                  
                  if (response.data['code'] == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('好友请求已发送')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(response.data['message'] ?? '发送失败')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('发送失败: $e')),
                  );
                }
              }
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }

  void _showFriendOptions(User friend) {
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
                _startChatWithFriend(friend);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除好友', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteFriend(friend);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFriend(User friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('确定要删除好友 ${friend.nickname} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteFriend(friend.id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _startChatWithFriend(User friend) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // Create or get existing conversation
    final conversation = chatProvider.getOrCreatePrivateConversation(friend);
    
    // Navigate to chat page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          conversation: conversation,
        ),
      ),
    );
  }

  Future<void> _deleteFriend(int friendId) async {
    try {
      final response = await _apiService.deleteFriend(friendId);
      if (response.data['code'] == 0) {
        if (mounted) {
          Provider.of<FriendProvider>(context, listen: false).removeFriend(friendId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除好友成功')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['message'] ?? '删除失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF07C160),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: _showAddFriendDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadFriends();
          await _loadFriendRequests();
        },
        child: Consumer<FriendProvider>(
          builder: (context, friendProvider, child) {
            if (_isLoading && friendProvider.friends.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              children: [
                // 好友请求入口 - 始终显示，有请求时高亮
                Container(
                  color: friendProvider.pendingRequestCount > 0 
                      ? Colors.orange[50] 
                      : Colors.white,
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: friendProvider.pendingRequestCount > 0 
                              ? const Color(0xFFFF9500) 
                              : Colors.grey[400],
                          child: const Icon(Icons.person_add, color: Colors.white),
                        ),
                        if (friendProvider.pendingRequestCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  '${friendProvider.pendingRequestCount}',
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
                      ),
                      title: Text(
                        friendProvider.pendingRequestCount > 0 
                            ? '新的好友 (${friendProvider.pendingRequestCount})' 
                            : '新的好友',
                        style: TextStyle(
                          fontWeight: friendProvider.pendingRequestCount > 0 
                              ? FontWeight.w600 
                              : FontWeight.normal,
                          color: friendProvider.pendingRequestCount > 0 
                              ? const Color(0xFFFF9500) 
                              : null,
                        ),
                      ),
                      subtitle: friendProvider.pendingRequestCount > 0 
                          ? const Text('有新的好友请求', style: TextStyle(color: Color(0xFFFF9500))) 
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FriendRequestsPage(),
                          ),
                        ).then((_) => _loadFriendRequests());
                      },
                    ),
                  ),
                const Divider(height: 8, thickness: 8),
                
                // 好友列表
                if (friendProvider.friends.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('暂无好友', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    color: Colors.white,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: friendProvider.friends.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        final friend = friendProvider.friends[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF07C160),
                            child: Text(
                              friend.nickname.isNotEmpty 
                                ? friend.nickname[0].toUpperCase()
                                : 'U',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(friend.nickname),
                          subtitle: Text('ID: ${friend.id}'),
                          onTap: () => _showFriendOptions(friend),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
