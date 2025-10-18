import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_provider.dart';
import '../services/api_service.dart';
import '../models/friend_request.dart';

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  final _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFriendRequests();
  }

  Future<void> _loadFriendRequests() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getFriendRequests();
      print('好友请求页面响应: ${response.data}'); // 调试信息
      if (response.data['code'] == 0 && mounted) {
        final requestsData = response.data['data'] as List?;
        if (requestsData != null) {
          final requests = requestsData.map((json) => FriendRequest.fromJson(json)).toList();
          print('好友请求页面解析的请求数量: ${requests.length}'); // 调试信息
          Provider.of<FriendProvider>(context, listen: false).setFriendRequests(requests);
        }
      }
    } catch (e) {
      print('好友请求页面加载失败: $e'); // 调试信息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载好友请求失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    try {
      final response = await _apiService.acceptFriendRequest(request.id);
      if (response.data['code'] == 0) {
        if (mounted) {
          Provider.of<FriendProvider>(context, listen: false)
              .updateFriendRequest(request.id, 1);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已接受好友请求')),
          );
          // Reload friend list
          _loadFriendRequests();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['message'] ?? '接受失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('接受失败: $e')),
        );
      }
    }
  }

  Future<void> _rejectRequest(FriendRequest request) async {
    try {
      final response = await _apiService.rejectFriendRequest(request.id);
      if (response.data['code'] == 0) {
        if (mounted) {
          Provider.of<FriendProvider>(context, listen: false)
              .updateFriendRequest(request.id, 2);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已拒绝好友请求')),
          );
          _loadFriendRequests();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['message'] ?? '拒绝失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拒绝失败: $e')),
        );
      }
    }
  }

  String _getStatusText(FriendRequest request) {
    if (request.isPending) return '待处理';
    if (request.isAccepted) return '已接受';
    if (request.isRejected) return '已拒绝';
    return '未知';
  }

  Color _getStatusColor(FriendRequest request) {
    if (request.isPending) return Colors.orange;
    if (request.isAccepted) return Colors.green;
    if (request.isRejected) return Colors.grey;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新的好友', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF07C160),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFriendRequests,
        child: Consumer<FriendProvider>(
          builder: (context, friendProvider, child) {
            if (_isLoading && friendProvider.friendRequests.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (friendProvider.friendRequests.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('暂无好友请求', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              itemCount: friendProvider.friendRequests.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final request = friendProvider.friendRequests[index];
                return Container(
                  color: Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF07C160),
                      child: Text(
                        request.fromUserNickname?.isNotEmpty == true
                            ? request.fromUserNickname![0].toUpperCase()
                            : 'U',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(request.fromUserNickname ?? '用户${request.fromUserId}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (request.remark?.isNotEmpty == true)
                          Text('备注: ${request.remark}'),
                        Text(
                          _formatTime(request.createTime),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: request.isPending
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _rejectRequest(request),
                                child: const Text('拒绝'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _acceptRequest(request),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF07C160),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('接受'),
                              ),
                            ],
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(request).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getStatusText(request),
                              style: TextStyle(
                                color: _getStatusColor(request),
                                fontSize: 12,
                              ),
                            ),
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}
