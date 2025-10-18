import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/message.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';
import '../providers/user_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/message_bubble.dart';
import '../services/api_service.dart';
import 'group_detail_page.dart';

class ChatPage extends StatefulWidget {
  final Conversation conversation;

  const ChatPage({
    Key? key,
    required this.conversation,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _setupMessageListener();
    _setupScrollListener();
    if (widget.conversation.type == ConversationType.group) {
      _loadGroupMembers();
    }
  }
  
  void _setupScrollListener() {
    _scrollController.addListener(() {
      // 当滚动到顶部时加载更多历史消息
      if (_scrollController.position.pixels <= 100) {
        _loadMoreHistory();
      }
    });
  }

  Future<void> _loadGroupMembers() async {
    if (widget.conversation.group == null) return;
    
    try {
      final response = await _apiService.getGroupMembers(widget.conversation.group!.id);
      if (response.data['code'] == 0) {
        final members = (response.data['data'] as List)
            .map((json) => User.fromJson(json))
            .toList();
        
        if (mounted) {
          final groupProvider = context.read<GroupProvider>();
          groupProvider.setGroupMembers(widget.conversation.group!.id, members);
        }
      }
    } catch (e) {
      // 静默失败，不影响聊天功能
      debugPrint('加载群成员失败: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupMessageListener() {
    final userProvider = context.read<UserProvider>();
    final chatProvider = context.read<ChatProvider>();
    
    if (userProvider.wsService != null) {
      userProvider.wsService!.messageStream.listen((data) {
        if (data['type'] == 'message') {
          final messageData = data['data'];
          final message = Message.fromJson(messageData);
          
          // 检查消息是否属于当前会话
          bool isCurrentConversation = false;
          if (widget.conversation.type == ConversationType.private) {
            isCurrentConversation = 
                (message.fromUserId == widget.conversation.user?.id && 
                 message.toUserId == userProvider.currentUser?.id) ||
                (message.fromUserId == userProvider.currentUser?.id && 
                 message.toUserId == widget.conversation.user?.id);
          } else if (widget.conversation.type == ConversationType.group) {
            isCurrentConversation = 
                message.isGroup && 
                message.groupId == widget.conversation.group?.id;
          }
          
          if (isCurrentConversation) {
            chatProvider.addMessage(widget.conversation.id, message);
            _scrollToBottom();
            
            // 显示通知（如果消息不是自己发送的）
            if (message.fromUserId != userProvider.currentUser?.id) {
              _showMessageNotification(message);
            }
          }
        }
      });
    }
  }

  void _showMessageNotification(Message message) {
    // 简单的应用内通知
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('收到新消息: ${message.content}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoading = true);
    try {
      final chatProvider = context.read<ChatProvider>();
      final page = chatProvider.getCurrentPage(widget.conversation.id);
      
      final response = await _apiService.getChatHistory(
        friendId: widget.conversation.type == ConversationType.private
            ? widget.conversation.user?.id
            : null,
        groupId: widget.conversation.type == ConversationType.group
            ? widget.conversation.group?.id
            : null,
        page: page,
        pageSize: 20,
      );

      if (response.data['code'] == 0) {
        final messages = (response.data['data']['messages'] as List)
            .map((json) => Message.fromJson(json))
            .toList();
        
        if (mounted) {
          chatProvider.setMessages(widget.conversation.id, messages);
          
          // 检查是否还有更多消息
          final total = response.data['data']['total'] as int? ?? 0;
          chatProvider.setHasMoreMessages(
            widget.conversation.id,
            messages.length < total,
          );
          
          // 加载完成后滚动到底部
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载聊天记录失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadMoreHistory() async {
    final chatProvider = context.read<ChatProvider>();
    
    // 如果正在加载或没有更多消息，则返回
    if (chatProvider.isLoadingMore(widget.conversation.id) ||
        !chatProvider.hasMoreMessages(widget.conversation.id)) {
      return;
    }
    
    chatProvider.setLoadingMore(widget.conversation.id, true);
    
    try {
      chatProvider.incrementPage(widget.conversation.id);
      final page = chatProvider.getCurrentPage(widget.conversation.id);
      
      final response = await _apiService.getChatHistory(
        friendId: widget.conversation.type == ConversationType.private
            ? widget.conversation.user?.id
            : null,
        groupId: widget.conversation.type == ConversationType.group
            ? widget.conversation.group?.id
            : null,
        page: page,
        pageSize: 20,
      );

      if (response.data['code'] == 0) {
        final messages = (response.data['data']['messages'] as List)
            .map((json) => Message.fromJson(json))
            .toList();
        
        if (mounted) {
          // 保存当前滚动位置
          final currentScrollPosition = _scrollController.position.pixels;
          
          // 追加历史消息到列表开头
          chatProvider.setMessages(widget.conversation.id, messages, append: true);
          
          // 恢复滚动位置（加上新消息的高度）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent - 
                (_scrollController.position.maxScrollExtent - currentScrollPosition),
              );
            }
          });
          
          // 检查是否还有更多消息
          if (messages.isEmpty) {
            chatProvider.setHasMoreMessages(widget.conversation.id, false);
          }
        }
      }
    } catch (e) {
      debugPrint('加载更多消息失败: $e');
    } finally {
      if (mounted) {
        chatProvider.setLoadingMore(widget.conversation.id, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversation.title),
        backgroundColor: const Color(0xFF07C160),
        actions: [
          if (widget.conversation.type == ConversationType.group)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showGroupInfo,
            ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              // TODO: 显示更多选项
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer2<ChatProvider, UserProvider>(
      builder: (context, chatProvider, userProvider, child) {
        final messages = chatProvider.getMessages(widget.conversation.id) ?? [];
        final isLoadingMore = chatProvider.isLoadingMore(widget.conversation.id);
        final hasMore = chatProvider.hasMoreMessages(widget.conversation.id);
        
        if (_isLoading && messages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (messages.isEmpty) {
          return Center(
            child: Text(
              '暂无消息',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messages.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // 显示加载更多指示器
            if (index == 0 && hasMore) {
              return Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: isLoadingMore
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        '下拉加载更多',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
              );
            }
            
            final messageIndex = hasMore ? index - 1 : index;
            final message = messages[messageIndex];
            final isMine = message.fromUserId == userProvider.currentUser?.id;
            final isGroupChat = widget.conversation.type == ConversationType.group;
            
            // 获取发送者昵称（用于群聊）
            String? senderNickname;
            if (isGroupChat && !isMine) {
              senderNickname = _getSenderNickname(message.fromUserId);
            }
            
            return MessageBubble(
              message: message,
              isMine: isMine,
              isGroupChat: isGroupChat,
              senderNickname: senderNickname,
              onRetry: message.status == MessageStatus.failed && isMine
                  ? () => _retryMessage(message)
                  : null,
            );
          },
        );
      },
    );
  }

  String? _getSenderNickname(int userId) {
    // 从群成员中查找发送者昵称
    if (widget.conversation.group != null) {
      final groupProvider = context.read<GroupProvider>();
      final members = groupProvider.getGroupMembers(widget.conversation.group!.id);
      
      if (members != null) {
        try {
          final sender = members.firstWhere((m) => m.id == userId);
          return sender.nickname;
        } catch (e) {
          return '用户$userId';
        }
      }
    }
    return '用户$userId';
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.grey[700],
                onPressed: _showMoreOptions,
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendTextMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.sentiment_satisfied_alt),
                color: Colors.grey[700],
                onPressed: () {
                  // TODO: 显示表情选择器
                },
              ),
              IconButton(
                icon: const Icon(Icons.send),
                color: const Color(0xFF07C160),
                onPressed: _sendTextMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            children: [
              _buildOptionItem(Icons.photo, '相册', () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              }),
              _buildOptionItem(Icons.camera_alt, '拍照', () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              }),
              _buildOptionItem(Icons.videocam, '视频', () {
                Navigator.pop(context);
                _pickVideo();
              }),
              _buildOptionItem(Icons.insert_drive_file, '文件', () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('文件功能暂未实现')),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();

    final userProvider = context.read<UserProvider>();
    final chatProvider = context.read<ChatProvider>();
    
    if (userProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户未登录')),
      );
      return;
    }

    // 创建临时消息
    final tempMessage = Message(
      msgId: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: userProvider.currentUser!.id,
      toUserId: widget.conversation.type == ConversationType.private
          ? widget.conversation.user!.id
          : 0,
      msgType: MessageType.text,
      content: text,
      isGroup: widget.conversation.type == ConversationType.group,
      groupId: widget.conversation.type == ConversationType.group
          ? widget.conversation.group?.id
          : null,
      createTime: DateTime.now(),
      status: MessageStatus.sending,
    );

    // 添加到消息列表
    chatProvider.addMessage(widget.conversation.id, tempMessage);
    
    // 滚动到底部
    _scrollToBottom();

    try {
      // 发送消息到服务器
      final response = await _apiService.sendMessage(
        tempMessage.toUserId,
        tempMessage.msgType.value,
        tempMessage.content,
        groupId: tempMessage.groupId,
      );

      if (response.data['code'] == 0) {
        // 更新消息状态为已发送
        tempMessage.status = MessageStatus.sent;
        chatProvider.addMessage(widget.conversation.id, tempMessage);
      } else {
        // 发送失败
        tempMessage.status = MessageStatus.failed;
        chatProvider.addMessage(widget.conversation.id, tempMessage);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发送失败: ${response.data['message']}')),
          );
        }
      }
    } catch (e) {
      // 发送失败
      tempMessage.status = MessageStatus.failed;
      chatProvider.addMessage(widget.conversation.id, tempMessage);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _retryMessage(Message message) async {
    final chatProvider = context.read<ChatProvider>();
    
    // 更新消息状态为发送中
    message.status = MessageStatus.sending;
    chatProvider.addMessage(widget.conversation.id, message);

    try {
      final response = await _apiService.sendMessage(
        message.toUserId,
        message.msgType.value,
        message.content,
        groupId: message.groupId,
      );

      if (response.data['code'] == 0) {
        message.status = MessageStatus.sent;
        chatProvider.addMessage(widget.conversation.id, message);
      } else {
        message.status = MessageStatus.failed;
        chatProvider.addMessage(widget.conversation.id, message);
      }
    } catch (e) {
      message.status = MessageStatus.failed;
      chatProvider.addMessage(widget.conversation.id, message);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        await _sendMediaMessage(image.path, MessageType.image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        // 检查文件大小
        final file = File(video.path);
        final fileSize = await file.length();
        if (fileSize > 100 * 1024 * 1024) { // 100MB
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('视频文件不能超过100MB')),
            );
          }
          return;
        }
        
        await _sendMediaMessage(video.path, MessageType.video);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择视频失败: $e')),
        );
      }
    }
  }

  Future<void> _sendMediaMessage(String filePath, MessageType messageType) async {
    final userProvider = context.read<UserProvider>();
    final chatProvider = context.read<ChatProvider>();
    
    if (userProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户未登录')),
      );
      return;
    }

    // 显示上传进度
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在上传...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 上传文件
      final uploadResponse = await _apiService.uploadFile(
        filePath,
        messageType == MessageType.image ? 'image' : 'video',
      );

      if (mounted) {
        Navigator.pop(context); // 关闭进度对话框
      }

      if (uploadResponse.data['code'] == 0) {
        final fileUrl = uploadResponse.data['data']['url'] as String;

        // 创建消息
        final message = Message(
          msgId: DateTime.now().millisecondsSinceEpoch.toString(),
          fromUserId: userProvider.currentUser!.id,
          toUserId: widget.conversation.type == ConversationType.private
              ? widget.conversation.user!.id
              : 0,
          msgType: messageType,
          content: fileUrl,
          isGroup: widget.conversation.type == ConversationType.group,
          groupId: widget.conversation.type == ConversationType.group
              ? widget.conversation.group?.id
              : null,
          createTime: DateTime.now(),
          status: MessageStatus.sending,
        );

        // 添加到消息列表
        chatProvider.addMessage(widget.conversation.id, message);
        _scrollToBottom();

        // 发送消息
        final response = await _apiService.sendMessage(
          message.toUserId,
          message.msgType.value,
          message.content,
          groupId: message.groupId,
        );

        if (response.data['code'] == 0) {
          message.status = MessageStatus.sent;
          chatProvider.addMessage(widget.conversation.id, message);
        } else {
          message.status = MessageStatus.failed;
          chatProvider.addMessage(widget.conversation.id, message);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上传失败: ${uploadResponse.data['message']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    }
  }

  void _showGroupInfo() {
    if (widget.conversation.group == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailPage(group: widget.conversation.group!),
      ),
    );
  }
}
