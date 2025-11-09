import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/friend_remark.dart';
import '../providers/user_provider.dart';
import '../providers/friend_provider.dart';

class FriendDetailPage extends StatefulWidget {
  final User friend;
  final FriendRemark? remark;

  const FriendDetailPage({
    super.key,
    required this.friend,
    this.remark,
  });

  @override
  State<FriendDetailPage> createState() => _FriendDetailPageState();
}

class _FriendDetailPageState extends State<FriendDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _remarkNameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _apiService = ApiService();
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFriendRemark();
  }

  @override
  void dispose() {
    _remarkNameController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendRemark() async {
    try {
      final response = await _apiService.getFriendWithRemark(widget.friend.id);
      if (response.data['code'] == 0) {
        final data = response.data['data'] as Map<String, dynamic>;
        final friendData = data['friend'] as Map<String, dynamic>;
        final remarkData = data['remark'] as Map<String, dynamic>?;
        
        setState(() {
          _remarkNameController.text = remarkData?['remarkName'] as String? ?? '';
          _categoryController.text = remarkData?['category'] as String? ?? '';
          final tags = remarkData?['tags'] as List?;
          _tagsController.text = tags != null ? tags.join(',') : '';
        });
      }
    } catch (e) {
      debugPrint('Error loading friend remark: $e');
    }
  }

  Future<void> _saveRemark() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final tags = _tagsController.text.trim().isEmpty
          ? <String>[]
          : _tagsController.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      final response = await _apiService.updateFriendRemark(
        widget.friend.id,
        remarkName: _remarkNameController.text.trim().isEmpty
            ? null
            : _remarkNameController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        tags: tags.isEmpty ? null : tags,
      );

      if (response.data['code'] == 0) {
        // 刷新好友列表
        final friendProvider = Provider.of<FriendProvider>(context, listen: false);
        friendProvider.refreshFriends();
        
        setState(() {
          _isEditing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('备注已保存'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['message'] ?? '保存失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _remarkNameController.text.trim().isNotEmpty
        ? _remarkNameController.text.trim()
        : widget.friend.nickname;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        backgroundColor: const Color(0xFF07C160),
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else
            TextButton(
              onPressed: _isSaving ? null : () {
                setState(() {
                  _isEditing = false;
                });
                _loadFriendRemark(); // 重新加载，取消编辑
              },
              child: const Text('取消', style: TextStyle(color: Colors.white)),
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveRemark,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('保存', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 好友头像和信息
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF07C160),
                    backgroundImage: widget.friend.avatar != null && widget.friend.avatar!.isNotEmpty
                        ? NetworkImage(widget.friend.avatar!)
                        : null,
                    child: widget.friend.avatar == null || widget.friend.avatar!.isEmpty
                        ? Text(
                            widget.friend.nickname.isNotEmpty
                                ? widget.friend.nickname[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(fontSize: 32, color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (_remarkNameController.text.trim().isNotEmpty)
                    Text(
                      widget.friend.nickname,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'ID: ${widget.friend.id}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (widget.friend.status != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: widget.friend.isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.friend.statusText,
                          style: TextStyle(
                            color: widget.friend.isOnline ? Colors.green : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (widget.friend.signature != null && widget.friend.signature!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.friend.signature!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            
            // 备注名
            TextFormField(
              controller: _remarkNameController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: '备注名',
                hintText: '请输入备注名',
                prefixIcon: const Icon(Icons.label_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _isEditing
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _remarkNameController.clear();
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            
            // 好友分组
            TextFormField(
              controller: _categoryController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: '好友分组',
                hintText: '请输入分组名称',
                prefixIcon: const Icon(Icons.folder_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _isEditing
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _categoryController.clear();
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            
            // 好友标签
            TextFormField(
              controller: _tagsController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: '好友标签',
                hintText: '多个标签用逗号分隔',
                prefixIcon: const Icon(Icons.tag_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                helperText: '例如：同事,朋友,家人',
                suffixIcon: _isEditing
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _tagsController.clear();
                        },
                      )
                    : null,
              ),
            ),
            
            if (_isEditing) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveRemark,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF07C160),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('保存', style: TextStyle(fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

