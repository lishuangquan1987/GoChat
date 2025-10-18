import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../providers/group_provider.dart';
import '../providers/user_provider.dart';
import '../providers/friend_provider.dart';
import '../services/api_service.dart';

class GroupDetailPage extends StatefulWidget {
  final Group group;

  const GroupDetailPage({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<User> _members = [];

  @override
  void initState() {
    super.initState();
    _loadGroupMembers();
  }

  Future<void> _loadGroupMembers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getGroupMembers(widget.group.id);
      if (response.data['code'] == 0) {
        final members = (response.data['data'] as List)
            .map((json) => User.fromJson(json))
            .toList();
        
        setState(() {
          _members = members;
        });
        
        if (mounted) {
          context.read<GroupProvider>().setGroupMembers(widget.group.id, members);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载群成员失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isOwner = widget.group.ownerId == userProvider.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('群组详情'),
        backgroundColor: const Color(0xFF07C160),
      ),
      body: Column(
        children: [
          _buildGroupInfo(),
          const Divider(height: 1),
          _buildMemberSection(isOwner),
          if (isOwner) const Divider(height: 1),
          if (isOwner) _buildManagementSection(),
        ],
      ),
    );
  }

  Widget _buildGroupInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFF07C160),
            child: Text(
              widget.group.groupName.isNotEmpty
                  ? widget.group.groupName[0].toUpperCase()
                  : 'G',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.group.groupName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '群组ID: ${widget.group.groupId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '创建时间: ${_formatDate(widget.group.createTime)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSection(bool isOwner) {
    return Expanded(
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '群成员 (${_members.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isOwner)
                    TextButton.icon(
                      onPressed: _addMembers,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('添加'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF07C160),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMemberList(isOwner),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberList(bool isOwner) {
    if (_members.isEmpty) {
      return Center(
        child: Text(
          '暂无成员',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final isMemberOwner = member.id == widget.group.ownerId;
        final isCurrentUser = member.id == context.read<UserProvider>().currentUser?.id;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF07C160),
            child: Text(
              member.nickname.isNotEmpty
                  ? member.nickname[0].toUpperCase()
                  : 'U',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Row(
            children: [
              Text(member.nickname),
              if (isMemberOwner) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '群主',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(member.username),
          trailing: isOwner && !isMemberOwner && !isCurrentUser
              ? IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _confirmRemoveMember(member),
                )
              : null,
        );
      },
    );
  }

  Widget _buildManagementSection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFF07C160)),
            title: const Text('修改群名称'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _editGroupName,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('解散群组', style: TextStyle(color: Colors.red)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _confirmDismissGroup,
          ),
        ],
      ),
    );
  }

  void _addMembers() async {
    final friendProvider = context.read<FriendProvider>();
    final availableFriends = friendProvider.friends
        .where((friend) => !widget.group.members.contains(friend.id))
        .toList();

    if (availableFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可添加的好友')),
      );
      return;
    }

    final selectedFriends = await showDialog<List<User>>(
      context: context,
      builder: (context) => _AddMembersDialog(
        availableFriends: availableFriends,
      ),
    );

    if (selectedFriends != null && selectedFriends.isNotEmpty) {
      _addMembersToGroup(selectedFriends.map((f) => f.id).toList());
    }
  }

  Future<void> _addMembersToGroup(List<int> userIds) async {
    try {
      final response = await _apiService.addGroupMembers(
        widget.group.id,
        userIds,
      );

      if (response.data['code'] == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
          _loadGroupMembers();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败: ${response.data['message']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  void _confirmRemoveMember(User member) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('移除成员'),
          content: Text('确定要将"${member.nickname}"移出群组吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeMember(member.id);
              },
              child: const Text('确定', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeMember(int userId) async {
    try {
      final response = await _apiService.removeGroupMember(
        widget.group.id,
        userId,
      );

      if (response.data['code'] == 0) {
        if (mounted) {
          context.read<GroupProvider>().removeGroupMember(widget.group.id, userId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已移除成员')),
          );
          _loadGroupMembers();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('移除失败: ${response.data['message']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移除失败: $e')),
        );
      }
    }
  }

  void _editGroupName() {
    final controller = TextEditingController(text: widget.group.groupName);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('修改群名称'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '输入新的群名称',
            ),
            maxLength: 20,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: 实现修改群名称的API调用
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('修改群名称功能待实现')),
                );
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDismissGroup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('解散群组'),
          content: Text('确定要解散群组"${widget.group.groupName}"吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _dismissGroup();
              },
              child: const Text('确定', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _dismissGroup() async {
    // TODO: 实现解散群组的API调用
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('解散群组功能待实现')),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _AddMembersDialog extends StatefulWidget {
  final List<User> availableFriends;

  const _AddMembersDialog({
    required this.availableFriends,
  });

  @override
  State<_AddMembersDialog> createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends State<_AddMembersDialog> {
  final Set<int> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加群成员'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.availableFriends.length,
          itemBuilder: (context, index) {
            final friend = widget.availableFriends[index];
            final isSelected = _selectedIds.contains(friend.id);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIds.add(friend.id);
                  } else {
                    _selectedIds.remove(friend.id);
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () {
                  final selectedFriends = widget.availableFriends
                      .where((f) => _selectedIds.contains(f.id))
                      .toList();
                  Navigator.pop(context, selectedFriends);
                },
          child: Text('确定 (${_selectedIds.length})'),
        ),
      ],
    );
  }
}
