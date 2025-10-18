import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../models/conversation.dart';
import '../providers/group_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import 'group_detail_page.dart';
import 'create_group_page.dart';
import 'chat_page.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getGroupList();
      if (response.data['code'] == 0) {
        final groups = (response.data['data'] as List)
            .map((json) => Group.fromJson(json))
            .toList();
        
        if (mounted) {
          context.read<GroupProvider>().setGroups(groups);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载群组列表失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群组'),
        backgroundColor: const Color(0xFF07C160),
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: _buildGroupList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        backgroundColor: const Color(0xFF07C160),
        child: const Icon(Icons.group_add),
      ),
    );
  }

  Widget _buildGroupList() {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        if (_isLoading && groupProvider.groups.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (groupProvider.groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '暂无群组',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击右下角按钮创建群组',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: groupProvider.groups.length,
          itemBuilder: (context, index) {
            final group = groupProvider.groups[index];
            return _buildGroupItem(group);
          },
        );
      },
    );
  }

  Widget _buildGroupItem(Group group) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF07C160),
        child: Text(
          group.groupName.isNotEmpty ? group.groupName[0].toUpperCase() : 'G',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        group.groupName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text('${group.memberCount} 人'),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => _openGroupChat(group),
      onLongPress: () => _showGroupOptions(group),
    );
  }

  void _openGroupChat(Group group) {
    final conversation = Conversation(
      id: 'group_${group.id}',
      type: ConversationType.group,
      group: group,
      lastMessage: null,
      unreadCount: 0,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(conversation: conversation),
      ),
    );
  }

  void _showGroupOptions(Group group) {
    final userProvider = context.read<UserProvider>();
    final isOwner = group.ownerId == userProvider.currentUser?.id;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('群组详情'),
                onTap: () {
                  Navigator.pop(context);
                  _viewGroupDetail(group);
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('添加成员'),
                  onTap: () {
                    Navigator.pop(context);
                    _viewGroupDetail(group);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text('退出群组', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmLeaveGroup(group);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewGroupDetail(Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailPage(group: group),
      ),
    );
  }

  void _createGroup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupPage(),
      ),
    );

    if (result == true) {
      _loadGroups();
    }
  }

  void _confirmLeaveGroup(Group group) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('退出群组'),
          content: Text('确定要退出群组"${group.groupName}"吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _leaveGroup(group);
              },
              child: const Text('确定', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _leaveGroup(Group group) async {
    final userProvider = context.read<UserProvider>();
    if (userProvider.currentUser == null) return;

    try {
      final response = await _apiService.removeGroupMember(
        group.id,
        userProvider.currentUser!.id,
      );

      if (response.data['code'] == 0) {
        if (mounted) {
          context.read<GroupProvider>().removeGroup(group.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已退出群组')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('退出失败: ${response.data['message']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出失败: $e')),
        );
      }
    }
  }
}
