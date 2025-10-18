import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_provider.dart';
import '../providers/group_provider.dart';
import '../services/api_service.dart';
import '../models/group.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final ApiService _apiService = ApiService();
  final Set<int> _selectedFriendIds = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建群组'),
        backgroundColor: const Color(0xFF07C160),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createGroup,
            child: Text(
              '创建',
              style: TextStyle(
                color: _isCreating ? Colors.white54 : Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGroupNameInput(),
          const Divider(height: 1),
          _buildSelectedMembers(),
          const Divider(height: 1),
          Expanded(child: _buildFriendList()),
        ],
      ),
    );
  }

  Widget _buildGroupNameInput() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: _groupNameController,
        decoration: const InputDecoration(
          hintText: '输入群组名称',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.group, color: Color(0xFF07C160)),
        ),
        maxLength: 20,
      ),
    );
  }

  Widget _buildSelectedMembers() {
    if (_selectedFriendIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已选择 ${_selectedFriendIds.length} 人',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedFriendIds.map((friendId) {
              final friend = context
                  .read<FriendProvider>()
                  .friends
                  .firstWhere((f) => f.id == friendId);
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: const Color(0xFF07C160),
                  child: Text(
                    friend.nickname.isNotEmpty
                        ? friend.nickname[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                label: Text(friend.nickname),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    _selectedFriendIds.remove(friendId);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendList() {
    return Consumer<FriendProvider>(
      builder: (context, friendProvider, child) {
        if (friendProvider.friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '暂无好友',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: friendProvider.friends.length,
          itemBuilder: (context, index) {
            final friend = friendProvider.friends[index];
            final isSelected = _selectedFriendIds.contains(friend.id);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedFriendIds.add(friend.id);
                  } else {
                    _selectedFriendIds.remove(friend.id);
                  }
                });
              },
              title: Text(friend.nickname),
              subtitle: Text(friend.username),
              secondary: CircleAvatar(
                backgroundColor: const Color(0xFF07C160),
                child: Text(
                  friend.nickname.isNotEmpty
                      ? friend.nickname[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              activeColor: const Color(0xFF07C160),
            );
          },
        );
      },
    );
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入群组名称')),
      );
      return;
    }

    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个好友')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final response = await _apiService.createGroup(
        groupName,
        _selectedFriendIds.toList(),
      );

      if (response.data['code'] == 0) {
        final group = Group.fromJson(response.data['data']);
        
        if (mounted) {
          context.read<GroupProvider>().addGroup(group);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('群组创建成功')),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建失败: ${response.data['message']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}
