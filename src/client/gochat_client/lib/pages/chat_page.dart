import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/message.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';
import '../providers/user_provider.dart';
import '../providers/group_provider.dart';

import '../widgets/optimized_message_list.dart';
import '../widgets/emoji_picker.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'login_page.dart';
import '../utils/performance_monitor.dart';
import '../utils/image_cache_manager.dart';
import '../utils/desktop_notification.dart';
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

class _ChatPageState extends State<ChatPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _textController = TextEditingController();
  final GlobalKey<OptimizedMessageListState> _messageListKey = GlobalKey();
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final ImagePreloader _imagePreloader = ImagePreloader();
  bool _isLoading = false;
  bool _showEmojiPicker = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _performanceMonitor.startTimer('chat_page_init');
    _loadChatHistory();
    _setupMessageListener();
    if (widget.conversation.type == ConversationType.group) {
      _loadGroupMembers();
    }

    // 清除未读消息计数
    _clearUnreadCount();

    _performanceMonitor.endTimer('chat_page_init');
  }

  Future<void> _loadGroupMembers() async {
    if (widget.conversation.group == null) return;

    try {
      final response =
          await _apiService.getGroupMembers(widget.conversation.group!.id);
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
    _imagePreloader.clearPreloadingState();
    super.dispose();
  }

  void _setupMessageListener() {
    final userProvider = context.read<UserProvider>();
    final chatProvider = context.read<ChatProvider>();

    // 直接监听WebSocket消息流
    if (userProvider.wsService != null) {
      userProvider.wsService!.messageStream.listen((data) {
        final messageType = data['type'] as String?;

        if (messageType == 'message') {
          final messageData = data['data'] as Map<String, dynamic>?;
          if (messageData != null) {
            try {
              final message = Message.fromJson(messageData);

              // 检查消息是否属于当前会话
              bool isCurrentConversation = false;
              if (widget.conversation.type == ConversationType.private) {
                // 私聊：检查是否是与当前聊天对象的消息
                isCurrentConversation =
                    (message.fromUserId == widget.conversation.user?.id &&
                            message.toUserId == userProvider.currentUser?.id) ||
                        (message.fromUserId == userProvider.currentUser?.id &&
                            message.toUserId == widget.conversation.user?.id);
              } else if (widget.conversation.type == ConversationType.group) {
                // 群聊：检查群ID
                isCurrentConversation = message.isGroup &&
                    message.groupId == widget.conversation.group?.id;
              }

              if (isCurrentConversation) {
                debugPrint(
                    'ChatPage: Received message for current conversation');

                // 添加消息到ChatProvider（标记为当前聊天，不增加未读数）
                chatProvider.addMessage(widget.conversation.id, message,
                    isCurrentChat: true);

                // 自动滚动到底部
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _messageListKey.currentState?.scrollToBottom();
                  }
                });

                // 预加载图片消息
                if (message.msgType == MessageType.image) {
                  _imagePreloader.preloadImagesForMessages([message.content]);
                }

                // 发送消息送达确认和已读确认（如果是接收到的消息）
                if (message.fromUserId != userProvider.currentUser?.id) {
                  _markMessageAsDelivered(message);
                  _markMessageAsRead(message);
                }
              }
            } catch (e) {
              debugPrint('ChatPage: Error parsing message: $e');
            }
          }
        } else if (messageType == 'message_status') {
          // 处理消息状态更新
          final msgId = data['msgId'] as String?;
          final status = data['status'] as String?;

          debugPrint(
              'ChatPage: Received message_status update: msgId=$msgId, status=$status');

          if (msgId != null && status != null) {
            _updateMessageStatus(msgId, status);
          } else {
            debugPrint('ChatPage: Invalid message_status format: $data');
          }
        } else if (messageType == 'message_recalled') {
          // 处理消息撤回通知
          final msgId = data['msgId'] as String?;
          if (msgId != null) {
            _handleMessageRecalled(msgId);
          }
        }
      });
    }
  }

  Future<void> _loadChatHistory() async {
    _performanceMonitor.startTimer('load_chat_history');
    setState(() => _isLoading = true);

    // 调试：检查token状态
    final token = await StorageService.getToken();
    print('DEBUG CHAT: Current token: $token');
    if (token == null || token.isEmpty) {
      print('DEBUG CHAT: No token found, user may need to re-login');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('认证已过期，请重新登录'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        // 延迟后跳转到登录页面
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }
        });
      }
      setState(() => _isLoading = false);
      return;
    }

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

          // 预加载图片消息
          final imageUrls = messages
              .where((m) => m.msgType == MessageType.image)
              .map((m) => m.content)
              .toList();
          if (imageUrls.isNotEmpty) {
            _imagePreloader.preloadImagesForMessages(imageUrls);
          }

          // 加载完成后滚动到底部
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _messageListKey.currentState?.scrollToBottom(animated: false);
          });
        }
      }
    } catch (e) {
      print('DEBUG CHAT: Error loading chat history: $e');
      if (mounted) {
        // 检查是否是401错误
        if (e.toString().contains('401')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('认证已过期，请重新登录'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: '重新登录',
                textColor: Colors.white,
                onPressed: () {
                  // 清除用户状态并跳转到登录页面
                  final userProvider = context.read<UserProvider>();
                  userProvider.logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载聊天记录失败: $e')),
          );
        }
      }
    } finally {
      setState(() => _isLoading = false);
      _performanceMonitor.endTimer('load_chat_history');
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
          // 追加历史消息到列表开头
          chatProvider.setMessages(widget.conversation.id, messages,
              append: true);

          // 滚动位置由OptimizedMessageList自动处理

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
    super.build(context);
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
            onPressed: _showChatMoreOptions,
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return OptimizedMessageList(
      key: _messageListKey,
      conversationId: widget.conversation.id,
      isGroupChat: widget.conversation.type == ConversationType.group,
      groupId: widget.conversation.group?.id,
      onLoadMore: _loadMoreHistory,
      onRetryMessage: _retryMessage,
      onRecallMessage: _recallMessage,
      onCopyMessage: _copyMessage,
      onDeleteMessage: _deleteMessage,
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showEmojiPicker)
          EmojiPicker(
            onEmojiSelected: (emoji) {
              _textController.text += emoji;
              setState(() {}); // 触发重新构建，更新发送按钮状态
            },
          ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
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
                    color: isDark ? Colors.white70 : Colors.grey[700],
                    onPressed: _showMoreOptions,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color:
                            isDark ? const Color(0xFF3A3A3A) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: '输入消息...',
                          hintStyle: TextStyle(
                              color:
                                  isDark ? Colors.white60 : Colors.grey[500]),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendTextMessage(),
                        onTap: () {
                          if (_showEmojiPicker) {
                            setState(() {
                              _showEmojiPicker = false;
                            });
                          }
                        },
                        onChanged: (text) {
                          setState(() {}); // 触发重新构建，更新发送按钮状态
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _showEmojiPicker
                          ? Icons.keyboard
                          : Icons.sentiment_satisfied_alt,
                      color: _showEmojiPicker
                          ? const Color(0xFF07C160)
                          : isDark
                              ? Colors.white70
                              : Colors.grey[700],
                    ),
                    onPressed: () {
                      setState(() {
                        _showEmojiPicker = !_showEmojiPicker;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: _textController.text.trim().isEmpty
                        ? (isDark ? Colors.white38 : Colors.grey[400])
                        : const Color(0xFF07C160),
                    onPressed: _textController.text.trim().isEmpty
                        ? null
                        : _sendTextMessage,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
                _pickFile();
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
    chatProvider.addMessage(widget.conversation.id, tempMessage,
        isCurrentChat: true);

    // 延迟滚动到底部，确保ListView已经重建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageListKey.currentState?.scrollToBottom();
    });

    try {
      // 发送消息到服务器
      final response = await _apiService.sendMessage(
        tempMessage.toUserId,
        tempMessage.msgType.value,
        tempMessage.content,
        groupId: tempMessage.groupId,
      );

      if (response.data['code'] == 0) {
        // 获取服务器返回的msgId（如果服务器返回了新的msgId）
        final serverMsgId = response.data['data']?['msgId'] as String?;
        if (serverMsgId != null && serverMsgId != tempMessage.msgId) {
          // 服务器返回了新的msgId，需要更新消息
          // 先删除旧消息
          final messages = chatProvider.getMessages(widget.conversation.id);
          if (messages != null) {
            messages.removeWhere((m) => m.msgId == tempMessage.msgId);
            chatProvider.setMessages(widget.conversation.id, messages);
          }
          // 创建新消息，使用服务器的msgId
          final updatedMessage = Message(
            msgId: serverMsgId,
            fromUserId: tempMessage.fromUserId,
            toUserId: tempMessage.toUserId,
            msgType: tempMessage.msgType,
            content: tempMessage.content,
            isGroup: tempMessage.isGroup,
            groupId: tempMessage.groupId,
            createTime: tempMessage.createTime,
            status: MessageStatus.sent,
            isRevoked: tempMessage.isRevoked,
            revokeTime: tempMessage.revokeTime,
          );
          chatProvider.addMessage(widget.conversation.id, updatedMessage,
              isCurrentChat: true);
        } else {
          // 使用原来的msgId，更新状态为已发送
          tempMessage.status = MessageStatus.sent;
          chatProvider.addMessage(widget.conversation.id, tempMessage,
              isCurrentChat: true);
        }
      } else {
        // 发送失败
        tempMessage.status = MessageStatus.failed;
        chatProvider.addMessage(widget.conversation.id, tempMessage,
            isCurrentChat: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发送失败: ${response.data['message']}')),
          );
        }
      }
    } catch (e) {
      // 发送失败
      tempMessage.status = MessageStatus.failed;
      chatProvider.addMessage(widget.conversation.id, tempMessage,
          isCurrentChat: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }

  void _retryMessage(Message message) async {
    final chatProvider = context.read<ChatProvider>();

    // 更新消息状态为发送中
    message.status = MessageStatus.sending;
    chatProvider.addMessage(widget.conversation.id, message,
        isCurrentChat: true);

    try {
      final response = await _apiService.sendMessage(
        message.toUserId,
        message.msgType.value,
        message.content,
        groupId: message.groupId,
      );

      if (response.data['code'] == 0) {
        message.status = MessageStatus.sent;
        chatProvider.addMessage(widget.conversation.id, message,
            isCurrentChat: true);
      } else {
        message.status = MessageStatus.failed;
        chatProvider.addMessage(widget.conversation.id, message,
            isCurrentChat: true);
      }
    } catch (e) {
      message.status = MessageStatus.failed;
      chatProvider.addMessage(widget.conversation.id, message,
          isCurrentChat: true);
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
        if (fileSize > 100 * 1024 * 1024) {
          // 100MB
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();
        if (fileSize > 100 * 1024 * 1024) {
          // 100MB
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('文件不能超过100MB')),
            );
          }
          return;
        }

        await _sendFileMessage(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  Future<void> _sendFileMessage(File file) async {
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
                Text('正在上传文件...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 上传文件
      final uploadResponse = await _apiService.uploadFile(
        file.path,
        'file',
      );

      if (mounted) {
        Navigator.pop(context); // 关闭进度对话框
      }

      if (uploadResponse.data['code'] == 0) {
        final fileUrl = uploadResponse.data['data']['url'] as String;
        final fileName = path.basename(file.path);

        // 创建消息
        final tempMessage = Message(
          msgId: DateTime.now().millisecondsSinceEpoch.toString(),
          fromUserId: userProvider.currentUser!.id,
          toUserId: widget.conversation.type == ConversationType.private
              ? widget.conversation.user!.id
              : 0,
          msgType: MessageType.file,
          content: '$fileName|$fileUrl', // 格式：文件名|文件URL
          isGroup: widget.conversation.type == ConversationType.group,
          groupId: widget.conversation.type == ConversationType.group
              ? widget.conversation.group?.id
              : null,
          createTime: DateTime.now(),
          status: MessageStatus.sending,
        );

        // 添加到消息列表
        chatProvider.addMessage(widget.conversation.id, tempMessage,
            isCurrentChat: true);
        _messageListKey.currentState?.scrollToBottom();

        // 发送消息
        final response = await _apiService.sendMessage(
          tempMessage.toUserId,
          tempMessage.msgType.value,
          tempMessage.content,
          groupId: tempMessage.groupId,
        );

        if (response.data['code'] == 0) {
          // 获取服务器返回的msgId（如果服务器返回了新的msgId）
          final serverMsgId = response.data['data']?['msgId'] as String?;
          if (serverMsgId != null && serverMsgId != tempMessage.msgId) {
            // 服务器返回了新的msgId，需要更新消息
            final messages = chatProvider.getMessages(widget.conversation.id);
            if (messages != null) {
              messages.removeWhere((m) => m.msgId == tempMessage.msgId);
              chatProvider.setMessages(widget.conversation.id, messages);
            }
            // 创建新消息，使用服务器的msgId
            final updatedMessage = Message(
              msgId: serverMsgId,
              fromUserId: tempMessage.fromUserId,
              toUserId: tempMessage.toUserId,
              msgType: tempMessage.msgType,
              content: tempMessage.content,
              isGroup: tempMessage.isGroup,
              groupId: tempMessage.groupId,
              createTime: tempMessage.createTime,
              status: MessageStatus.sent,
              isRevoked: tempMessage.isRevoked,
              revokeTime: tempMessage.revokeTime,
            );
            chatProvider.addMessage(widget.conversation.id, updatedMessage,
                isCurrentChat: true);
          } else {
            // 使用原来的msgId，更新状态为已发送
            tempMessage.status = MessageStatus.sent;
            chatProvider.addMessage(widget.conversation.id, tempMessage,
                isCurrentChat: true);
          }
        } else {
          tempMessage.status = MessageStatus.failed;
          chatProvider.addMessage(widget.conversation.id, tempMessage,
              isCurrentChat: true);
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

  Future<void> _sendMediaMessage(
      String filePath, MessageType messageType) async {
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
        final tempMessage = Message(
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
        chatProvider.addMessage(widget.conversation.id, tempMessage,
            isCurrentChat: true);
        _messageListKey.currentState?.scrollToBottom();

        // 发送消息
        final response = await _apiService.sendMessage(
          tempMessage.toUserId,
          tempMessage.msgType.value,
          tempMessage.content,
          groupId: tempMessage.groupId,
        );

        if (response.data['code'] == 0) {
          // 获取服务器返回的msgId（如果服务器返回了新的msgId）
          final serverMsgId = response.data['data']?['msgId'] as String?;
          if (serverMsgId != null && serverMsgId != tempMessage.msgId) {
            // 服务器返回了新的msgId，需要更新消息
            final messages = chatProvider.getMessages(widget.conversation.id);
            if (messages != null) {
              messages.removeWhere((m) => m.msgId == tempMessage.msgId);
              chatProvider.setMessages(widget.conversation.id, messages);
            }
            // 创建新消息，使用服务器的msgId
            final updatedMessage = Message(
              msgId: serverMsgId,
              fromUserId: tempMessage.fromUserId,
              toUserId: tempMessage.toUserId,
              msgType: tempMessage.msgType,
              content: tempMessage.content,
              isGroup: tempMessage.isGroup,
              groupId: tempMessage.groupId,
              createTime: tempMessage.createTime,
              status: MessageStatus.sent,
              isRevoked: tempMessage.isRevoked,
              revokeTime: tempMessage.revokeTime,
            );
            chatProvider.addMessage(widget.conversation.id, updatedMessage,
                isCurrentChat: true);
          } else {
            // 使用原来的msgId，更新状态为已发送
            tempMessage.status = MessageStatus.sent;
            chatProvider.addMessage(widget.conversation.id, tempMessage,
                isCurrentChat: true);
          }
        } else {
          tempMessage.status = MessageStatus.failed;
          chatProvider.addMessage(widget.conversation.id, tempMessage,
              isCurrentChat: true);
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
        builder: (context) =>
            GroupDetailPage(group: widget.conversation.group!),
      ),
    );
  }

  void _showChatMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('搜索聊天记录'),
                onTap: () {
                  Navigator.pop(context);
                  _searchChatHistory();
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('消息免打扰'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleDoNotDisturb();
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('屏蔽用户'),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _searchChatHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('搜索聊天记录功能开发中...')),
    );
  }

  void _toggleDoNotDisturb() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('消息免打扰功能开发中...')),
    );
  }

  void _blockUser() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('屏蔽用户功能开发中...')),
    );
  }

  Future<void> _clearUnreadCount() async {
    try {
      final friendId = widget.conversation.type == ConversationType.private
          ? widget.conversation.user?.id
          : null;
      final groupId = widget.conversation.type == ConversationType.group
          ? widget.conversation.group?.id
          : null;

      // 调用API标记所有消息为已读
      await _apiService.markAllMessagesAsRead(
        friendId: friendId,
        groupId: groupId,
      );

      // 清除本地未读计数
      final chatProvider = context.read<ChatProvider>();
      chatProvider.clearUnreadCount(widget.conversation.id);

      // 更新桌面通知状态
      final totalUnread = chatProvider.conversations
          .fold<int>(0, (sum, conv) => sum + conv.unreadCount);
      DesktopNotification.updateUnreadStatus(unreadCount: totalUnread);
    } catch (e) {
      debugPrint('Error clearing unread count: $e');
      // 即使API调用失败，也清除本地未读计数
      final chatProvider = context.read<ChatProvider>();
      chatProvider.clearUnreadCount(widget.conversation.id);
    }
  }

  // 标记消息为已送达
  void _markMessageAsDelivered(Message message) {
    final userProvider = context.read<UserProvider>();
    if (userProvider.wsService != null && userProvider.wsService!.isConnected) {
      try {
        userProvider.wsService!.sendMessage({
          'type': 'delivered',
          'data': {
            'msgId': message.msgId,
          },
        });
      } catch (e) {
        print('Failed to mark message as delivered: $e');
      }
    }
  }

  // 标记消息为已读
  void _markMessageAsRead(Message message) {
    final userProvider = context.read<UserProvider>();
    if (userProvider.wsService != null && userProvider.wsService!.isConnected) {
      try {
        userProvider.wsService!.sendMessage({
          'type': 'read',
          'data': {
            'msgId': message.msgId,
          },
        });
      } catch (e) {
        print('Failed to mark message as read: $e');
      }
    }
  }

  // 更新消息状态
  void _updateMessageStatus(String msgId, String status) {
    debugPrint(
        '_updateMessageStatus: msgId=$msgId, status=$status, conversationId=${widget.conversation.id}');

    final chatProvider = context.read<ChatProvider>();
    MessageStatus newStatus;

    switch (status) {
      case 'delivered':
        newStatus = MessageStatus.delivered;
        break;
      case 'read':
        newStatus = MessageStatus.read;
        break;
      default:
        debugPrint('_updateMessageStatus: Unknown status: $status');
        return;
    }

    // 首先尝试在当前会话中查找消息
    final messages = chatProvider.getMessages(widget.conversation.id);
    if (messages != null) {
      final messageIndex = messages.indexWhere((m) => m.msgId == msgId);
      if (messageIndex != -1) {
        final message = messages[messageIndex];
        // 只有当新状态比当前状态更新时才更新
        // sending < sent < delivered < read
        if (_shouldUpdateMessageStatus(message.status, newStatus)) {
          debugPrint(
              '_updateMessageStatus: Updating message $msgId from ${message.status} to $newStatus');
          message.status = newStatus;
          chatProvider.addMessage(widget.conversation.id, message,
              isCurrentChat: true);
          return;
        } else {
          debugPrint(
              '_updateMessageStatus: Status update skipped (current: ${message.status}, new: $newStatus)');
          return;
        }
      }
    }

    // 如果当前会话中没有找到，尝试在所有会话中查找
    debugPrint(
        '_updateMessageStatus: Message $msgId not found in current conversation, searching all conversations');
    for (final conversation in chatProvider.conversations) {
      final convMessages = chatProvider.getMessages(conversation.id);
      if (convMessages != null) {
        final messageIndex = convMessages.indexWhere((m) => m.msgId == msgId);
        if (messageIndex != -1) {
          final message = convMessages[messageIndex];
          if (_shouldUpdateMessageStatus(message.status, newStatus)) {
            debugPrint(
                '_updateMessageStatus: Found message $msgId in conversation ${conversation.id}, updating status');
            message.status = newStatus;
            chatProvider.addMessage(conversation.id, message,
                isCurrentChat: conversation.id == widget.conversation.id);
            return;
          }
        }
      }
    }

    debugPrint(
        '_updateMessageStatus: Message $msgId not found in any conversation');
  }

  // 判断是否应该更新消息状态（新状态必须比当前状态更新）
  bool _shouldUpdateMessageStatus(
      MessageStatus current, MessageStatus newStatus) {
    // 状态优先级：sending(0) < sent(1) < delivered(2) < read(3)
    // failed(-1) 不应该被其他状态覆盖（除非是重新发送）
    const statusValues = {
      MessageStatus.sending: 0,
      MessageStatus.sent: 1,
      MessageStatus.delivered: 2,
      MessageStatus.read: 3,
      MessageStatus.failed: -1,
    };

    final currentValue = statusValues[current] ?? -1;
    final newValue = statusValues[newStatus] ?? -1;

    // 失败状态不应该被其他状态覆盖
    if (current == MessageStatus.failed) {
      return false;
    }

    // 新状态值必须大于当前状态值
    return newValue > currentValue;
  }

  Future<void> _recallMessage(Message message) async {
    final userProvider = context.read<UserProvider>();
    final chatProvider = context.read<ChatProvider>();

    if (userProvider.currentUser == null ||
        message.fromUserId != userProvider.currentUser!.id) {
      return;
    }

    // 检查是否可以撤回（2分钟内）
    if (!message.canRecall(userProvider.currentUser!.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('消息发送超过2分钟，无法撤回')),
        );
      }
      return;
    }

    try {
      final response = await _apiService.recallMessage(message.msgId);

      if (response.data['code'] == 0) {
        // 更新消息为已撤回状态
        final recalledMessage = message.copyWithRevoked();
        chatProvider.addMessage(widget.conversation.id, recalledMessage,
            isCurrentChat: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('消息已撤回'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['message'] ?? '撤回失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('撤回失败: $e')),
        );
      }
    }
  }

  void _handleMessageRecalled(String msgId) {
    final chatProvider = context.read<ChatProvider>();
    final messages = chatProvider.getMessages(widget.conversation.id);

    if (messages != null) {
      final messageIndex = messages.indexWhere((m) => m.msgId == msgId);
      if (messageIndex != -1) {
        final message = messages[messageIndex];
        final recalledMessage = message.copyWithRevoked();
        chatProvider.addMessage(widget.conversation.id, recalledMessage,
            isCurrentChat: true);
      }
    }
  }

  void _copyMessage(Message message) {
    if (message.msgType == MessageType.text) {
      Clipboard.setData(ClipboardData(text: message.content));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('消息已复制到剪贴板')),
      );
    }
  }

  void _deleteMessage(Message message) {
    final chatProvider = context.read<ChatProvider>();
    // 从本地消息列表中删除（仅前端删除，不调用API）
    final messages = chatProvider.getMessages(widget.conversation.id);
    if (messages != null) {
      final updatedMessages =
          messages.where((m) => m.msgId != message.msgId).toList();
      chatProvider.setMessages(widget.conversation.id, updatedMessages);
    }
  }
}
